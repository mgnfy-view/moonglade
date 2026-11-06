// SPDX-License-Identifier: MIT AND LicenseRef-Degensoft-SwapVM-1.1
pragma solidity 0.8.30;

import { IERC20 } from "@openzeppelin-contracts/token/ERC20/IERC20.sol";
import { IAqua } from "aqua/src/interfaces/IAqua.sol";
import { IMidnight } from "midnight/src/interfaces/IMidnight.sol";
import { IOracle } from "midnight/src/interfaces/IOracle.sol";
import { ISwapVM } from "swap-vm/src/interfaces/ISwapVM.sol";

import { SafeERC20 } from "@openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol";
import { Math } from "@openzeppelin-contracts/utils/math/Math.sol";
import { Market, CollateralParams } from "midnight/src/interfaces/IMidnight.sol";
import { ReentrancyGuardTransient } from "@openzeppelin-contracts/utils/ReentrancyGuardTransient.sol";
import { TickLib } from "midnight/src/libraries/TickLib.sol";
import { MakerTraits, MakerTraitsLib } from "swap-vm/src/libs/MakerTraits.sol";

import { IMoongladeCurve } from "src/curves/interfaces/IMoongladeCurve.sol";
import { IMoongladeSwap } from "src/instructions/interfaces/IMoongladeSwap.sol";
import { IMoongladeDeskHook } from "src/hooks/interfaces/IMoongladeDeskHook.sol";
import { IMoongladeNote } from "src/note/interfaces/IMoongladeNote.sol";

import { MoongladeSwap } from "src/instructions/MoongladeSwap.sol";
import { MoongladeProgram } from "src/libraries/MoongladeProgram.sol";
import { MoongladeRouter } from "src/routers/MoongladeRouter.sol";
import { MidnightTicks } from "src/libraries/MidnightTicks.sol";

/// @title Moonglade desk hook.
/// @author Sahil Gujrati (@mgnfy-view).
/// @notice Mints and cancels inventory for a maker whose idle assets stay in their own wallet.
/// @dev The maker owns its Aqua strategy and Midnight position and fronts grid-priced settlement cash for JIT mints.
/// Borrower fills mint only a taker's note shortfall using scoped note delegation and existing collateral.
/// Both payment orders are supported; maker cash must cover mint float when its hook executes, plus any earlier
/// swap payout. Maker-funded principal is refunded; only the native mint fee is spent. Hook balances are preserved.
contract MoongladeDeskHook is IMoongladeDeskHook, ReentrancyGuardTransient {
    // ===== Constants =====

    /// @notice Fixed-point scale used by Midnight borrowing factors and target utilization.
    uint256 private constant WAD = 1e18;
    /// @notice Oracle quote scale used by the pinned Midnight deployment.
    uint256 private constant ORACLE_PRICE_SCALE = 1e36;
    /// @notice Pinned Midnight callback acknowledgement; avoids importing its Solidity 0.8.34-only helper graph.
    bytes32 private constant CALLBACK_SUCCESS = keccak256("morpho.midnight.callbackSuccess");

    // ===== Immutables =====

    /// @notice Only this wallet configures or deactivates the strategy; all unused mint float returns here.
    address public immutable maker;
    /// @notice Market-specific token whose backing remains in its own Midnight credit position.
    IMoongladeNote public immutable note;
    /// @notice Wallet asset used to settle swaps and temporarily fund note operations.
    IERC20 public immutable loanToken;
    /// @notice Midnight deployment holding the maker's collateral and debt.
    IMidnight public immutable midnight;
    /// @notice Registry and settlement contract used directly by the maker.
    IAqua public immutable aqua;
    /// @notice Only this router may invoke strategy callbacks.
    MoongladeRouter public immutable router;
    /// @notice Canonical market identifier fixed at construction.
    bytes32 private immutable marketId;

    // ===== State =====

    /// @notice Whether this hook currently permits callbacks for its configured strategy.
    bool public active;
    /// @notice Canonical order hash registered directly by the maker on Aqua.
    bytes32 public strategyHash;
    /// @notice Salt distinguishing each configured strategy.
    uint64 private salt;
    /// @notice Fixed market parameters used for the maker's position.
    Market private marketData;
    /// @notice Maker-approved borrowing and funding bounds.
    RiskConfig private riskLimits;
    /// @notice Parameters of the current curve.
    IMoongladeSwap.Config private curveParameters;
    /// @notice Encoded traits specifying the wallet maker and explicit hook targets.
    MakerTraits private makerTraits;
    /// @notice Encoded hook targets and strategy program.
    bytes private orderData;
    /// @notice Nonzero only until the exact nested Midnight buy callback consumes this context.
    uint256 private transient burnUnits;
    /// @notice Actual gross buyer cash expected by the single pending debt-cancellation callback.
    uint256 private transient burnAssets;

    // ===== Initialization =====

    /// @notice Bind a hook to one maker, note market, and router without transferring funds or granting authority.
    /// @param _maker Wallet that owns the Aqua order and Midnight position.
    /// @param _note Market-specific note contract.
    /// @param _router SwapVM router with the Moonglade pricing instruction.
    constructor(address _maker, IMoongladeNote _note, MoongladeRouter _router) {
        if (_maker == address(0)) revert MoongladeDeskHook__InvalidMaker();
        if (address(_note) == address(0) || address(_router) == address(0)) {
            revert MoongladeDeskHook__InvalidDependencies();
        }
        maker = _maker;
        note = _note;
        router = _router;
        midnight = _note.midnight();
        loanToken = _note.loanToken();
        aqua = _router.AQUA();
        marketData = _note.market();
        marketId = _note.marketId();
    }

    // ===== Configuration =====

    /// @notice Approve a strategy whose order maker remains the wallet.
    /// @dev The maker must subsequently call Aqua.ship directly with this order and its desired virtual budgets.
    /// The selected implementation validates its own parameters when quoting.
    /// No assets or collateral move here. Dock and deactivate an old strategy before replacing it.
    /// @param _config Fixed note, selected pricing implementation, and its opaque settings.
    /// @param _risk Wallet-approved limits and selected collateral policy.
    /// @return Canonical order hash for Aqua registration.
    function configure(IMoongladeSwap.Config calldata _config, RiskConfig calldata _risk)
        external
        nonReentrant
        returns (bytes32)
    {
        _checkMaker();
        if (active || _isRegistered()) revert MoongladeDeskHook__StrategyActive();
        if (_config.note != address(note)) {
            revert MoongladeDeskHook__InvalidStrategy();
        }
        if (block.timestamp >= marketData.maturity - MoongladeSwap.MATURITY_BUFFER) {
            revert MoongladeDeskHook__MarketClosed();
        }
        if (
            _risk.collateralIndex >= marketData.collateralParams.length || _risk.targetUtilization == 0
                || _risk.targetUtilization >= WAD || _risk.maxDebt > type(uint128).max
                || _risk.maxCollateral > type(uint128).max
        ) revert MoongladeDeskHook__InvalidRiskLimits();

        MakerTraitsLib.Args memory args;
        args.maker = maker;
        args.useAquaInsteadOfSignature = true;
        args.hasPreTransferInHook = true;
        args.hasPreTransferOutHook = true;
        args.hasPostTransferInHook = true;
        args.preTransferInTarget = address(this);
        args.preTransferOutTarget = address(this);
        args.postTransferInTarget = address(this);
        args.program = MoongladeProgram.build(_config, ++salt);
        ISwapVM.Order memory strategy = MakerTraitsLib.build(args);
        makerTraits = strategy.traits;
        orderData = strategy.data;
        curveParameters = _config;
        riskLimits = _risk;
        strategyHash = keccak256(abi.encode(strategy));
        active = true;

        emit StrategyConfigured(strategyHash);

        return strategyHash;
    }

    /// @notice Stop this hook from serving its configured order without transferring tokens.
    /// @dev The maker separately calls Aqua.dock to remove the corresponding registry allocation.
    function deactivate() external nonReentrant {
        _checkMaker();

        active = false;

        emit StrategyDeactivated(strategyHash);
    }

    /// @notice Mint missing outgoing mgNOTE into the maker's wallet before Aqua pulls it.
    /// @dev Only the authenticated registered strategy may spend maker funds. Output-first settlement requires
    /// sufficient maker cash for mint float before incoming swap cash arrives; debt and collateral limits still apply.
    /// @param _maker Wallet claimed as maker by SwapVM.
    /// @param _tokenIn Input asset.
    /// @param _tokenOut Output asset.
    /// @param _amountIn Loan-token input allocated proportionally to any maker mint shortfall.
    /// @param _amountOut Calculated output amount.
    /// @param _hash Canonical strategy hash.
    function preTransferOut(
        address _maker,
        address,
        address _tokenIn,
        address _tokenOut,
        uint256 _amountIn,
        uint256 _amountOut,
        bytes32 _hash,
        bytes calldata,
        bytes calldata
    ) external nonReentrant {
        _checkHook(_maker, _hash, _tokenIn, _tokenOut);
        if (_tokenOut != address(note)) return;

        uint256 held = note.balanceOf(maker);
        if (_amountOut > held) _mintShortfall(_amountOut - held, _amountIn, _amountOut);
    }

    /// @notice Optionally cancel incoming wallet inventory and release surplus selected collateral.
    /// @dev Conservatively reserves the quoted loan-token output during an optional burn in either payment order.
    /// This can skip a burn after output-first payment, while preserving cash needed by a pending input-first payout.
    /// @param _maker Wallet claimed as maker by SwapVM.
    /// @param _tokenIn Input asset.
    /// @param _tokenOut Output asset.
    /// @param _amountIn Notes just purchased; bounds the inventory eligible for this optional burn.
    /// @param _amountOut Outgoing loan-token amount conservatively reserved during an optional burn.
    /// @param _hash Canonical strategy hash.
    function postTransferIn(
        address _maker,
        address,
        address _tokenIn,
        address _tokenOut,
        uint256 _amountIn,
        uint256 _amountOut,
        bytes32 _hash,
        bytes calldata,
        bytes calldata
    ) external nonReentrant {
        _checkHook(_maker, _hash, _tokenIn, _tokenOut);
        if (_tokenIn != address(note)) return;
        if (riskLimits.autoBurn) {
            _burnAvailable(_amountIn, _amountOut, _amountOut, _amountIn);
            _releaseCollateral();
        }
    }

    /// @notice Mint only the taker's note-input shortfall before SwapVM collects its input.
    /// @dev Authenticated settlement uses maker-funded grid-priced float bounded by maxMintFront. After output-first
    /// payment the maker needs enough cash for both the completed payout and this mint's gross float. The note
    /// consumes the taker's scoped gross-unit mint delegation and enforces existing Midnight collateral health. This hook
    /// does not manage taker collateral or apply the maker's debt cap; unused float returns to the maker.
    /// @param _maker Wallet claimed as maker by SwapVM.
    /// @param _taker Borrower or ordinary swap taker whose existing note inventory is counted first.
    /// @param _tokenIn Input asset; only note input may require a mint.
    /// @param _tokenOut Output asset.
    /// @param _amountIn Gross note input the router will collect after this callback.
    /// @param _amountOut Loan-token output allocated proportionally to the borrower's note shortfall.
    /// @param _hash Canonical strategy hash.
    function preTransferIn(
        address _maker,
        address _taker,
        address _tokenIn,
        address _tokenOut,
        uint256 _amountIn,
        uint256 _amountOut,
        bytes32 _hash,
        bytes calldata,
        bytes calldata
    ) external nonReentrant {
        _checkHook(_maker, _hash, _tokenIn, _tokenOut);
        if (_tokenIn != address(note)) return;
        uint256 held = note.balanceOf(_taker);
        if (_amountIn <= held) return;
        uint256 shortfall = _amountIn - held;
        (uint256 units, uint256 tick, uint256 front) = _mintTerms(shortfall, _amountOut, _amountIn);
        _fundMint(_taker, shortfall, units, front, tick);
    }

    /// @notice Reject the unused post-transfer-out phase.
    function postTransferOut(
        address,
        address,
        address,
        address,
        uint256,
        uint256,
        bytes32,
        bytes calldata,
        bytes calldata
    ) external pure {
        revert MoongladeDeskHook__InvalidHook();
    }

    /// @notice Confirm the single expected nested Midnight debt-cancellation callback.
    /// @dev Runs inside the initiating action's reentrancy guard and therefore has no second guard.
    /// It consumes the unit and actual-cash context once; a bounded allowance funds settlement at the native tick.
    /// Midnight binds the market to its ID; the note builds reduce-only offers with empty callback data.
    /// @param _id Market being settled.
    /// @param _buyerAssets Gross cash paid by this hook.
    /// @param _units Debt units being cancelled.
    /// @param _buyer Must be the maker wallet whose debt is reduced.
    /// @return Midnight callback success constant.
    function onBuy(
        bytes32 _id,
        Market memory,
        uint256 _buyerAssets,
        uint256 _units,
        uint256,
        address _buyer,
        bytes memory
    ) external returns (bytes32) {
        uint256 expected = burnUnits;
        if (
            msg.sender != address(midnight) || expected == 0 || _id != marketId || _buyer != maker || _units != expected
                || _buyerAssets != burnAssets
        ) revert MoongladeDeskHook__InvalidCallback();
        burnUnits = 0;
        burnAssets = 0;
        return CALLBACK_SUCCESS;
    }

    // ===== Internal functions =====

    /// @notice Restrict configuration and deactivation to the immutable wallet owner.
    function _checkMaker() private view {
        if (msg.sender != maker) revert MoongladeDeskHook__Unauthorized();
    }

    /// @notice Require a configuration even when the strategy has been deactivated for maintenance.
    function _checkConfigured() private view {
        if (strategyHash == bytes32(0)) revert MoongladeDeskHook__StrategyInactive();
    }

    /// @notice Authenticate the router's exact active maker, order, token pair, and Aqua registration.
    /// @param _maker Wallet claimed by SwapVM.
    /// @param _hash Order hash claimed by SwapVM.
    /// @param _tokenIn Input asset.
    /// @param _tokenOut Output asset.
    function _checkHook(address _maker, bytes32 _hash, address _tokenIn, address _tokenOut) private view {
        if (msg.sender != address(router) || _maker != maker || !active || _hash != strategyHash) {
            revert MoongladeDeskHook__InvalidHook();
        }
        if (!((_tokenIn == address(loanToken) && _tokenOut == address(note))
                    || (_tokenIn == address(note) && _tokenOut == address(loanToken)))) revert MoongladeDeskHook__InvalidHook();
        aqua.safeBalances(maker, address(router), strategyHash, address(loanToken), address(note));
    }

    /// @notice Consume maker credit first, collateralize any new debt, and mint missing outgoing shares.
    /// @dev Preview debt using updated credit and check actual debt after settlement; all callers hold the guard.
    /// @param _shares Minimum new wallet shares needed for the outgoing swap.
    /// @param _cash Loan-token input paid for the full swap output.
    /// @param _fullShares Full note output used to allocate its price to the shortfall.
    function _mintShortfall(uint256 _shares, uint256 _cash, uint256 _fullShares) private {
        (uint256 units, uint256 tick, uint256 front) = _mintTerms(_shares, _cash, _fullShares);
        (uint128 credit,,) = midnight.updatePosition(marketData, maker);
        uint256 debtAfter = midnight.debt(marketId, maker) + units - Math.min(units, credit);
        if (debtAfter > riskLimits.maxDebt) revert MoongladeDeskHook__DebtLimit();
        _adjustCollateral(debtAfter);
        (uint256 processed, uint256 issued) = _fundMint(maker, _shares, units, front, tick);
        if (midnight.debt(marketId, maker) > riskLimits.maxDebt) revert MoongladeDeskHook__DebtLimit();
        emit InventoryMinted(issued, processed);
    }

    /// @notice Allocate the actual fill's share price to previewed native units and snap to the nearest market tick.
    /// @param _shares Shares that require minting rather than existing inventory.
    /// @param _cash Loan-token amount for the full fill.
    /// @param _fullShares Full fill shares used to preserve the original price allocation.
    /// @return Gross credit units required to mint the shortfall.
    /// @return Nearest valid native tick, with price ties rounded down.
    /// @return Conservative gross mint float including the native settlement fee.
    function _mintTerms(uint256 _shares, uint256 _cash, uint256 _fullShares)
        private
        view
        returns (uint256, uint256, uint256)
    {
        uint256 units = note.previewMintUnits(_shares);
        uint256 tick =
            MidnightTicks.nearest(_unitPrice(_cash, _fullShares, _shares, units), midnight.tickSpacing(marketId));
        uint256 price = TickLib.tickToPrice(tick);
        if (price == 0) revert MoongladeDeskHook__InvalidPrice();
        uint256 front = Math.mulDiv(units, price + _settlementFee(), WAD, Math.Rounding.Ceil);
        return (units, tick, front);
    }

    /// @notice Fund a grid-priced mint from maker cash and refund unused principal without retaining hook assets.
    /// @dev Enforces the shared gross float limit; only maker mints use maker debt and collateral policy.
    /// The note enforces authorization and sends every issued share directly to the specified borrower.
    /// @param _borrower Position owner and receiver of all issued shares.
    /// @param _shares Minimum shares required by the pending input or output transfer.
    /// @param _units Exact previewed gross credit units, also used as the maximum mint units.
    /// @param _front Gross settlement float at the actual native tick, bounded by maxMintFront.
    /// @param _tick Valid native tick representing the allocated fill price.
    /// @return Gross credit units processed; existing wallet credit is consumed before new debt is originated.
    /// @return Shares issued directly to the borrower, including any rounding excess.
    function _fundMint(address _borrower, uint256 _shares, uint256 _units, uint256 _front, uint256 _tick)
        private
        returns (uint256, uint256)
    {
        if (_front > riskLimits.maxMintFront) revert MoongladeDeskHook__FrontExceedsLimit();
        uint256 beforeShares = note.balanceOf(address(this));
        uint256 beforeBalance = _pullLoanTokens(_front);
        SafeERC20.forceApprove(loanToken, address(note), _front);
        (uint256 processed, uint256 issued) =
            note.mintForSharesOnBehalf(_shares, _units, _front, _borrower, _borrower, _tick);
        SafeERC20.forceApprove(loanToken, address(note), 0);
        _refundLoanTokens(beforeBalance);
        if (note.balanceOf(address(this)) != beforeShares) revert MoongladeDeskHook__InvalidTransfer();
        return (processed, issued);
    }

    /// @notice Cancel bounded wallet inventory at its allocated fill price when funding and allowances permit.
    /// @dev Optional burns preserve pending output cash and skip unsupported zero/fee-below-price native execution.
    /// Funding and fee limits use the exact rounded buyer and seller cash legs at the selected tick.
    /// @param _limit Maximum wallet shares eligible for this burn; callbacks limit this to their purchased shares.
    /// @param _reserveAssets Loan tokens that must remain available for a pending output transfer.
    /// @param _cash Fill cash for _fullShares.
    /// @param _fullShares Full fill shares used to allocate the burned fraction's honest price.
    /// @return Debt units cancelled, or zero when cancellation is unavailable.
    function _burnAvailable(uint256 _limit, uint256 _reserveAssets, uint256 _cash, uint256 _fullShares)
        private
        returns (uint256)
    {
        if (_cash == 0) return 0;
        uint256 debt = midnight.debt(marketId, maker);
        uint256 held = note.balanceOf(maker);
        if (debt == 0 || held == 0) return 0;
        if (!midnight.isAuthorized(maker, address(this)) || !midnight.isAuthorized(maker, note.ratifier())) return 0;
        (uint128 credit,,) = midnight.updatePositionView(marketData, marketId, address(note));
        if (credit == 0) return 0;
        uint256 supply = note.totalSupply();
        uint256 shares = Math.min(Math.min(held, _limit), Math.mulDiv(debt, supply, credit));
        uint256 units = Math.mulDiv(shares, credit, supply);
        if (units == 0) return 0;
        uint256 unitPrice = _unitPrice(_cash, _fullShares, shares, units);
        if (unitPrice > WAD) return 0;
        uint256 tick = MidnightTicks.nearest(unitPrice, midnight.tickSpacing(marketId));
        uint256 price = TickLib.tickToPrice(tick);
        uint256 fee = _settlementFee();
        if (price == 0 || price < fee) return 0;
        uint256 buyerAssets = Math.mulDiv(units, price, WAD);
        uint256 cost = buyerAssets - Math.mulDiv(units, price - fee, WAD);
        uint256 cash = loanToken.balanceOf(maker);
        if (
            cost > riskLimits.maxBurnCost || cash < buyerAssets || _reserveAssets > cash - cost
                || loanToken.allowance(maker, address(this)) < buyerAssets
                || note.allowance(maker, address(this)) < shares
        ) return 0;

        uint256 beforeBalance = _pullLoanTokens(buyerAssets);
        uint256 beforeShares = note.balanceOf(address(this));
        SafeERC20.safeTransferFrom(IERC20(address(note)), maker, address(this), shares);
        SafeERC20.forceApprove(loanToken, address(midnight), buyerAssets);
        burnUnits = units;
        burnAssets = buyerAssets;
        (uint256 repaid, uint256 actualCost) = note.burn(shares, riskLimits.maxBurnCost, maker, tick);
        if (burnUnits != 0 || note.balanceOf(address(this)) != beforeShares) {
            revert MoongladeDeskHook__InvalidCallback();
        }
        SafeERC20.forceApprove(loanToken, address(midnight), 0);
        _refundLoanTokens(beforeBalance);
        emit InventoryBurned(shares, repaid, actualCost);
        return repaid;
    }

    /// @notice Convert a fill share price into a native-unit price without first rounding proportional cash to zero.
    /// @param _cash Cash paid for _fullShares.
    /// @param _fullShares Full shares represented by the cash value.
    /// @param _shares Minted or burned shares whose native units are being priced.
    /// @param _units Gross credit units processed when minting or released when burning.
    /// @return WAD price per gross credit unit before grid rounding.
    function _unitPrice(uint256 _cash, uint256 _fullShares, uint256 _shares, uint256 _units)
        private
        pure
        returns (uint256)
    {
        uint256 sharePrice = Math.mulDiv(_cash, WAD, _fullShares);
        return Math.mulDiv(sharePrice, _shares, _units);
    }

    /// @notice Read the native settlement fee at the remaining maturity, clamped to zero after maturity.
    /// @return WAD settlement fee applied by Midnight.
    function _settlementFee() private view returns (uint256) {
        uint256 timeLeft = block.timestamp < marketData.maturity ? marketData.maturity - block.timestamp : 0;
        return midnight.settlementFee(marketId, timeLeft);
    }

    /// @notice Build consistent inputs for the selected implementation's rate view.
    /// @param _cashBalance Native virtual loan-token reserve.
    /// @param _noteBalance Native virtual share reserve.
    /// @return Market state with actual payout and time clamped at maturity.
    function _pricingState(uint256 _cashBalance, uint256 _noteBalance)
        private
        view
        returns (IMoongladeCurve.MarketState memory)
    {
        return IMoongladeCurve.MarketState(
            address(note),
            _cashBalance,
            _noteBalance,
            block.timestamp < marketData.maturity ? marketData.maturity - block.timestamp : 0,
            note.totalSupply() == 0 ? WAD : note.payoutPerShare()
        );
    }

    /// @notice Pull exact temporary loan-token funding from the maker.
    /// @param _assets Amount needed by the current guarded action.
    /// @return Hook balance before temporary funding, excluding the maker's transfer.
    function _pullLoanTokens(uint256 _assets) private returns (uint256) {
        uint256 beforeBalance = loanToken.balanceOf(address(this));
        SafeERC20.safeTransferFrom(loanToken, maker, address(this), _assets);
        if (loanToken.balanceOf(address(this)) != beforeBalance + _assets) revert MoongladeDeskHook__InvalidTransfer();
        return beforeBalance;
    }

    /// @notice Refund all unused temporary cash without consuming a pre-existing hook balance.
    /// @param _beforeBalance Hook balance recorded before maker funding.
    function _refundLoanTokens(uint256 _beforeBalance) private {
        uint256 balance = loanToken.balanceOf(address(this));
        if (balance < _beforeBalance) revert MoongladeDeskHook__InvalidTransfer();
        uint256 refund = balance - _beforeBalance;
        if (refund != 0) SafeERC20.safeTransfer(loanToken, maker, refund);
        if (loanToken.balanceOf(address(this)) != _beforeBalance) revert MoongladeDeskHook__InvalidTransfer();
    }

    /// @notice Adjust only the selected collateral to support the supplied debt at target utilization.
    /// @dev Existing other collateral contributes capacity; only the required delta leaves the wallet.
    /// @param _debt Current debt or the exact debt anticipated after a pending mint.
    function _adjustCollateral(uint256 _debt) private {
        uint256 required = _requiredCollateral(_debt);
        uint256 index = riskLimits.collateralIndex;
        uint256 posted = midnight.collateral(marketId, maker, index);
        if (required > riskLimits.maxCollateral) revert MoongladeDeskHook__CollateralLimit();
        if (required > posted) {
            uint256 assets = required - posted;
            IERC20 token = IERC20(marketData.collateralParams[index].token);
            uint256 beforeBalance = token.balanceOf(address(this));
            SafeERC20.safeTransferFrom(token, maker, address(this), assets);
            if (token.balanceOf(address(this)) != beforeBalance + assets) revert MoongladeDeskHook__InvalidTransfer();
            SafeERC20.forceApprove(token, address(midnight), assets);
            midnight.supplyCollateral(marketData, index, assets, maker);
            SafeERC20.forceApprove(token, address(midnight), 0);
            if (token.balanceOf(address(this)) != beforeBalance) revert MoongladeDeskHook__InvalidTransfer();
            emit CollateralAdjusted(true, assets);
        } else if (posted > required) {
            midnight.withdrawCollateral(marketData, index, posted - required, maker, maker);
            emit CollateralAdjusted(false, posted - required);
        }
    }

    /// @notice Best-effort release of surplus selected collateral after a debt-reducing action.
    /// @dev Oracle or withdrawal failures must not undo an otherwise successful optional burn.
    function _releaseCollateral() private {
        uint256 debt = midnight.debt(marketId, maker);
        try this.requiredCollateral(debt) returns (uint256 required) {
            uint256 index = riskLimits.collateralIndex;
            uint256 posted = midnight.collateral(marketId, maker, index);
            if (posted > required) {
                uint256 assets = posted - required;
                try midnight.withdrawCollateral(marketData, index, assets, maker, maker) {
                    emit CollateralAdjusted(false, assets);
                } catch { }
            }
        } catch { }
    }

    /// @notice Invert Midnight's per-collateral nested-floor borrowing-capacity calculation.
    /// @dev Both inverse divisions round up. Zero debt needs no oracle reads; other active collateral is counted.
    /// @param _debt Debt to support at the configured utilization.
    /// @return Total selected collateral required in the maker's Midnight position.
    function _requiredCollateral(uint256 _debt) private view returns (uint256) {
        if (_debt == 0) return 0;
        uint256 requiredCapacity = Math.mulDiv(_debt, WAD, riskLimits.targetUtilization, Math.Rounding.Ceil);
        uint256 otherCapacity;
        uint256 selected = riskLimits.collateralIndex;
        uint128 bitmap = midnight.collateralBitmap(marketId, maker);
        for (uint256 i; i < marketData.collateralParams.length; ++i) {
            if (i == selected || (uint256(bitmap) & (uint256(1) << i)) == 0) continue;
            CollateralParams memory collateral = marketData.collateralParams[i];
            uint256 value = Math.mulDiv(
                midnight.collateral(marketId, maker, i), IOracle(collateral.oracle).price(), ORACLE_PRICE_SCALE
            );
            otherCapacity += Math.mulDiv(value, collateral.lltv, WAD);
        }
        if (otherCapacity >= requiredCapacity) return 0;
        CollateralParams memory selectedCollateral = marketData.collateralParams[selected];
        uint256 price = IOracle(selectedCollateral.oracle).price();
        if (price == 0 || selectedCollateral.lltv == 0) revert MoongladeDeskHook__InvalidOraclePrice();
        uint256 selectedValue =
            Math.mulDiv(requiredCapacity - otherCapacity, WAD, selectedCollateral.lltv, Math.Rounding.Ceil);
        return Math.mulDiv(selectedValue, ORACLE_PRICE_SCALE, price, Math.Rounding.Ceil);
    }

    /// @notice Check Aqua registration independently of this hook's local activation flag.
    /// @return Whether Aqua still recognizes both token allocations for the last configured order.
    function _isRegistered() private view returns (bool) {
        if (strategyHash == bytes32(0)) return false;
        try aqua.safeBalances(maker, address(router), strategyHash, address(loanToken), address(note)) returns (
            uint256, uint256
        ) {
            return true;
        } catch {
            return false;
        }
    }

    // ===== External views =====

    /// @notice Return the wallet-maker order with this contract as its explicit hook target.
    /// @return Canonical order to register directly on Aqua and provide to swap takers.
    function order() external view returns (ISwapVM.Order memory) {
        return ISwapVM.Order(maker, makerTraits, orderData);
    }

    /// @notice Return the last maker-approved curve parameters.
    /// @return Curve configuration used by the order.
    function curveConfig() external view returns (IMoongladeSwap.Config memory) {
        return curveParameters;
    }

    /// @notice Return maker-approved limits and collateral policy.
    /// @return Risk configuration used by guarded inventory actions.
    function riskConfig() external view returns (RiskConfig memory) {
        return riskLimits;
    }

    /// @notice Return the exact token order used for Aqua registration and docking.
    /// @return Loan token followed by mgNOTE.
    function tokens() external view returns (address[] memory) {
        address[] memory result = new address[](2);
        result[0] = address(loanToken);
        result[1] = address(note);
        return result;
    }

    /// @notice Check whether the maker has registered the configured order on Aqua.
    /// @return Whether Aqua recognizes its token allocations, even if this hook was deactivated.
    function isRegistered() external view returns (bool) {
        return _isRegistered();
    }

    /// @notice Quote total selected collateral needed for a prospective maker debt.
    /// @dev Reads active collateral oracles and uses upward rounding; an unconfigured hook reverts.
    /// @param _debt Current or proposed market debt.
    /// @return Selected collateral required at the configured utilization.
    function requiredCollateral(uint256 _debt) external view returns (uint256) {
        _checkConfigured();
        return _requiredCollateral(_debt);
    }

    /// @notice Return the selected pricing implementation's annual rate for the current Aqua reserves.
    /// @dev Requires a locally active, registered strategy. Empty note supply uses par payout; otherwise updated
    /// net credit determines payout. The selected implementation determines the rate convention.
    /// @return Annual discount rate scaled by 1e18.
    function currentRate() external view returns (uint256) {
        if (!active) revert MoongladeDeskHook__StrategyInactive();
        (uint256 usdcBalance, uint256 noteBalance) =
            aqua.safeBalances(maker, address(router), strategyHash, address(loanToken), address(note));
        uint256 rate =
            IMoongladeCurve(curveParameters.curve).rate(_pricingState(usdcBalance, noteBalance), curveParameters.data);
        return rate;
    }
}
