// SPDX-License-Identifier: MIT
pragma solidity 0.8.34;

import { IERC20 } from "@openzeppelin-contracts/token/ERC20/IERC20.sol";
import { IERC20Metadata } from "@openzeppelin-contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { IMidnight } from "midnight/src/interfaces/IMidnight.sol";
import { Market, Offer } from "midnight/src/interfaces/IMidnight.sol";

import { ERC20 } from "@openzeppelin-contracts/token/ERC20/ERC20.sol";
import { SafeERC20 } from "@openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol";
import { Math } from "@openzeppelin-contracts/utils/math/Math.sol";
import { ReentrancyGuardTransient } from "@openzeppelin-contracts/utils/ReentrancyGuardTransient.sol";
import { WAD } from "midnight/src/libraries/ConstantsLib.sol";
import { IdLib } from "midnight/src/libraries/IdLib.sol";
import { TickLib } from "midnight/src/libraries/TickLib.sol";

import { IMoongladeNote } from "src/note/interfaces/IMoongladeNote.sol";

/// @title Moonglade Note.
/// @author Sahil Gujrati (@mgnfy-view).
/// @notice ERC-20 shares of one wrapper's net Midnight credit in one ungated market.
/// @dev No owner, protocol fees, upgrades, or operators on the wrapper's Midnight position.
/// Shares use the loan token's decimals. Net backing is credit minus pending fee, with losses applied by Midnight.
/// Only standard ERC-20 loan tokens are supported; fee-on-transfer and rebasing tokens are unsupported.
/// Settlement preserves prior cash: the note holds no loan tokens between calls unless directly donated or named
/// as a cash receiver. Midnight has permanent cash allowance and is already trusted with the note's credit.
contract MoongladeNote is IMoongladeNote, ERC20, ReentrancyGuardTransient {
    /// @notice Initial shares permanently reserved against first-depositor rounding manipulation.
    uint256 public constant MINIMUM_SHARES = 1000;
    /// @notice Recipient of the initial share reserve.
    address public constant DEAD_SHARES = address(0xdead);

    /// @notice Midnight deployment holding this wrapper's credit.
    IMidnight public immutable midnight;
    /// @notice Loan token used for settlement and repayment.
    IERC20 public immutable loanToken;
    /// @notice Shared ratifier that authorizes only the active internal offer.
    address public immutable ratifier;
    /// @notice Canonical identifier of the fixed market.
    bytes32 public immutable marketId;
    /// @notice Market maturity timestamp.
    uint256 public immutable maturity;
    /// @notice Loan token decimals captured at construction.
    uint8 private immutable shareDecimals;

    /// @notice Fixed Midnight market parameters; never modified after construction.
    Market private marketData;
    /// @notice Monotonic nonce used to isolate internal offer groups.
    uint256 private nonce;
    /// @notice Transient hash authorized only while taking an internal offer.
    bytes32 public transient activeOfferHash;
    /// @notice Wallet-set gross-unit budgets and expirations for each delegated mint spender.
    mapping(address borrower => mapping(address spender => BorrowAllowance)) public borrowAllowances;

    /// @notice Fix the wrapper's market, registry, and ratifier and adopt the loan token's decimals.
    /// @dev Factory deployment and its registry establish ratifier eligibility; token metadata is an external call.
    /// @param _midnight Midnight deployment that manages the credit.
    /// @param _ratifier Shared factory ratifier for wrapper-initiated offers.
    /// @param _market Immutable market configuration.
    constructor(IMidnight _midnight, address _ratifier, Market memory _market) ERC20("Moonglade Note", "mgNOTE") {
        midnight = _midnight;
        ratifier = _ratifier;
        marketData = _market;
        marketId = IdLib.toId(_market);
        maturity = _market.maturity;
        loanToken = IERC20(_market.loanToken);
        shareDecimals = IERC20Metadata(_market.loanToken).decimals();

        SafeERC20.forceApprove(loanToken, address(midnight), type(uint256).max);
    }

    /// @notice Set or revoke the caller's bounded share-mint delegation to a spender.
    /// @dev Only msg.sender's allowance changes. Nonzero budgets require an unexpired deadline; zero revokes immediately.
    /// Scoped delegation permits only share-targeted mints to the borrower, within remaining units and expiry.
    /// Its gross-unit budget covers both existing credit consumed and new debt originated.
    /// It authorizes neither burning nor other Midnight operations; the borrower separately authorizes the ratifier.
    /// @param _spender Delegate permitted to supply native-settlement cash float; must be nonzero.
    /// @param _units Total remaining gross units authorized; zero revokes the delegation.
    /// @param _deadline Latest timestamp at which nonzero delegated minting may execute.
    function approveBorrow(address _spender, uint128 _units, uint40 _deadline) external {
        if (_spender == address(0)) revert MoongladeNote__InvalidBorrowSpender();
        if (_units != 0 && block.timestamp > _deadline) revert MoongladeNote__BorrowExpired();

        borrowAllowances[msg.sender][_spender] = BorrowAllowance(_units, _deadline);

        emit BorrowApproval(msg.sender, _spender, _units, _deadline);
    }

    /// @notice Consume existing credit, then borrow any remainder, to issue at least the requested shares.
    /// @dev Self and Midnight-authorized operators retain their ordinary receiver choice. Other callers must have an
    /// unexpired borrow allowance covering gross units and send every issued share to the borrower. Scoped allowance
    /// is consumed before settlement. The borrower separately authorizes the shared ratifier on Midnight.
    /// Caller supplies a rounded-up cash budget at the selected credit-unit tick, receives principal directly,
    /// and is refunded any unused budget. Its net cash cost is the native settlement fee.
    /// No operator is authorized on this wrapper's position. Gross units round up to issue at least the requested shares.
    /// @param _shares Minimum receiver shares; must be nonzero.
    /// @param _maxUnits Maximum gross units processed, including existing credit consumed and new debt originated.
    /// @param _maxFront Maximum gross loan-token float to transfer from the caller.
    /// @param _borrower Nonzero wallet whose Midnight credit is consumed before any new debt is originated.
    /// @param _receiver Share recipient; scoped delegation requires the borrower.
    /// @param _tick Valid aligned price tick per Midnight credit unit.
    /// @return Gross units processed after upward rounding; new debt may be smaller or zero.
    /// @return Shares actually issued, including any integer-rounding excess.
    function mintForSharesOnBehalf(
        uint256 _shares,
        uint256 _maxUnits,
        uint256 _maxFront,
        address _borrower,
        address _receiver,
        uint256 _tick
    ) external nonReentrant returns (uint256, uint256) {
        if (_borrower == address(0)) revert MoongladeNote__InvalidBorrower();
        uint256 units = previewMintUnits(_shares);
        if (units > _maxUnits) revert MoongladeNote__UnitsExceedLimit();
        if (_borrower != msg.sender && !midnight.isAuthorized(_borrower, msg.sender)) {
            if (_receiver != _borrower) {
                revert MoongladeNote__InvalidBorrowReceiver(_borrower, _receiver);
            }
            BorrowAllowance storage allowance = borrowAllowances[_borrower][msg.sender];
            if (block.timestamp > allowance.deadline) revert MoongladeNote__BorrowExpired();
            if (units > allowance.remainingUnits) revert MoongladeNote__BorrowAllowanceExceeded();
            // previewMintUnits bounds units to uint128 before this checked allowance deduction.
            allowance.remainingUnits -= uint128(units);
        }
        uint256 issuedShares = _mint(units, _maxFront, _borrower, _receiver, _tick);
        if (issuedShares < _shares) revert MoongladeNote__InsufficientIssuedShares();

        return (units, issuedShares);
    }

    /// @notice Burn caller-owned shares to cancel the specified borrower's existing Midnight debt.
    /// @dev Self-callers need no operator authorization and fund the gross cash leg with Midnight allowance.
    /// Other callers must be authorized by the borrower on Midnight and implement IBuyCallback to supply cash.
    /// Gross cash is floor(units*tickPrice/WAD), not units; tick price must cover the current settlement fee.
    /// Users burning outside a desk pass the tick of the credit-unit price they paid; shares convert to gross units.
    /// The borrower separately authorizes the shared ratifier. Cash principal returns to the caller, which pays
    /// the bounded net settlement fee. Scoped borrow allowances never authorize burns. Reduce-only prevents
    /// creating borrower credit, and shares are always taken from msg.sender rather than from the borrower.
    /// @param _shares Caller shares to burn; gross credit units round down.
    /// @param _maxCost Maximum net settlement fee checked after settlement.
    /// @param _borrower Nonzero wallet whose debt is cancelled; self-callers skip operator authorization.
    /// @param _tick Valid aligned price tick per credit unit purchased to cancel debt; shares convert to gross units.
    /// @return Debt units cancelled.
    /// @return Actual loan-token settlement fee.
    function burn(uint256 _shares, uint256 _maxCost, address _borrower, uint256 _tick)
        external
        nonReentrant
        returns (uint256, uint256)
    {
        if (_borrower == address(0)) revert MoongladeNote__InvalidBorrower();
        if (_borrower != msg.sender && !midnight.isAuthorized(_borrower, msg.sender)) {
            revert MoongladeNote__UnauthorizedBorrower(_borrower, msg.sender);
        }

        (uint256 units, uint256 cost) = _burnCredit(_shares, _maxCost, _borrower, _tick);

        return (units, cost);
    }

    /// @notice Buy credit from an external signed sell offer and wrap the net credit actually received.
    /// @dev Caller approves cash float to this wrapper; the external maker uses its own ratifier. Issuance rounds down.
    /// Any unused rounded-up cash budget is refunded to the caller, preserving this note's prior cash balance.
    /// Minting follows settlement to measure actual net credit; the reentrancy guard protects this ordering.
    /// @param _offer External sell offer for this market, with a ratifier distinct from this wrapper's.
    /// @param _ratifierData Authorization data passed to the external offer ratifier.
    /// @param _units Credit units to buy before maturity.
    /// @param _receiver Share recipient; must be nonzero.
    /// @return Shares issued against the actual net-credit increase.
    function wrapFromOffer(Offer calldata _offer, bytes calldata _ratifierData, uint256 _units, address _receiver)
        external
        nonReentrant
        returns (uint256)
    {
        _checkMintUnits(_units);
        _checkExternalOffer(_offer, false);
        (uint128 credit, uint128 pendingFee,) = midnight.updatePosition(marketData, address(this));
        uint256 backing = uint256(credit) - pendingFee;
        uint256 supply = totalSupply();
        if (supply != 0 && backing == 0) revert MoongladeNote__ZeroBacking();
        uint256 front =
            Math.mulDiv(_units, TickLib.tickToPrice(_offer.tick) + _settlementFee(), WAD, Math.Rounding.Ceil);
        uint256 paid = _fundAndTake(_offer, _ratifierData, _units, front);
        uint256 shares = _issue(_receiver, backing, supply);

        emit Wrapped(msg.sender, _receiver, _units, shares, paid);

        return shares;
    }

    /// @notice Burn caller shares and sell their proportional gross credit to an external signed buy offer.
    /// @dev Burns before calling Midnight and the external ratifier; gross credit rounds down and must be nonzero.
    /// @param _shares Caller shares to burn.
    /// @param _offer External buy offer for this market, with a ratifier distinct from this wrapper's.
    /// @param _ratifierData Authorization data passed to the external offer ratifier.
    /// @param _receiver Loan-token recipient; must be nonzero.
    /// @return Loan tokens delivered by Midnight to the receiver.
    function unwrapToOffer(uint256 _shares, Offer calldata _offer, bytes calldata _ratifierData, address _receiver)
        external
        nonReentrant
        returns (uint256)
    {
        if (_receiver == address(0)) revert ERC20InvalidReceiver(_receiver);
        _checkExternalOffer(_offer, true);
        (uint128 credit,,) = midnight.updatePosition(marketData, address(this));
        uint256 units = _unitsForBurn(_shares, credit);
        _burn(msg.sender, _shares);
        (, uint256 assets) = _take(_offer, _ratifierData, units, _receiver);

        emit Unwrapped(msg.sender, _receiver, _shares, units, assets);

        return assets;
    }

    /// @notice Burn caller shares after maturity and withdraw repaid credit to the receiver.
    /// @dev Requires sufficient Midnight liquidity; rounds assets down and skips withdrawal for a zero-asset result.
    /// @param _shares Nonzero shares to redeem; smaller amounts allow partial redemption.
    /// @param _receiver Loan-token recipient; must be nonzero.
    /// @return Loan tokens withdrawn from Midnight.
    function redeem(uint256 _shares, address _receiver) external nonReentrant returns (uint256) {
        if (block.timestamp < maturity) revert MoongladeNote__MarketNotMatured();
        if (_receiver == address(0)) revert ERC20InvalidReceiver(_receiver);
        if (_shares == 0) revert MoongladeNote__ZeroShares();
        (uint128 credit,,) = midnight.updatePosition(marketData, address(this));
        uint256 assets = Math.mulDiv(_shares, credit, totalSupply());
        _burn(msg.sender, _shares);
        if (assets != 0) midnight.withdraw(marketData, assets, address(this), _receiver);

        emit Redeemed(msg.sender, _receiver, _shares, assets);

        return assets;
    }

    /// @dev Burn caller shares and settle a reduce-only buy offer at the selected credit-unit tick.
    function _burnCredit(uint256 _shares, uint256 _maxCost, address _borrower, uint256 _tick)
        private
        returns (uint256, uint256)
    {
        (uint128 credit,,) = midnight.updatePosition(marketData, address(this));
        uint256 units = _unitsForBurn(_shares, credit);
        _burn(msg.sender, _shares);
        Offer memory offer = _buildOffer(true, units, _borrower, _tick);
        if (_borrower != msg.sender) offer.callback = msg.sender;
        (uint256 buyerAssets, uint256 sellerAssets) = _take(offer, "", units, msg.sender);
        uint256 cost = buyerAssets - sellerAssets;
        if (cost > _maxCost) revert MoongladeNote__CostExceedsLimit();

        emit Burned(_borrower, _shares, units, cost);

        return (units, cost);
    }

    /// @dev Normalize native and external offers through one Midnight settlement encoder.
    function _take(Offer memory _offer, bytes memory _ratifierData, uint256 _units, address _sellerReceiver)
        private
        returns (uint256, uint256)
    {
        bool internalOffer = _offer.ratifier == ratifier;
        if (internalOffer) activeOfferHash = keccak256(abi.encode(_offer));
        (uint256 buyerAssets, uint256 sellerAssets) =
            midnight.take(_offer, _ratifierData, _units, address(this), _sellerReceiver, address(0), "");
        if (internalOffer) activeOfferHash = bytes32(0);

        return (buyerAssets, sellerAssets);
    }

    /// @dev Settle a wallet-made sell offer at the chosen credit-unit tick, then issue net-credit-backed shares.
    /// Minting follows settlement to measure actual net credit. The transient hash limits ratification, and callers
    /// guard reentrancy across external token and Midnight calls.
    function _mint(uint256 _units, uint256 _maxFront, address _borrower, address _receiver, uint256 _tick)
        private
        returns (uint256)
    {
        uint256 price = TickLib.tickToPrice(_tick);
        (uint128 credit, uint128 pendingFee,) = midnight.updatePosition(marketData, address(this));
        uint256 backing = uint256(credit) - pendingFee;
        uint256 supply = totalSupply();
        uint256 front = Math.mulDiv(_units, price + _settlementFee(), WAD, Math.Rounding.Ceil);
        if (front > _maxFront) revert MoongladeNote__FrontExceedsLimit();
        _fundAndTake(_buildOffer(false, _units, _borrower, _tick), "", _units, front);
        uint256 shares = _issue(_receiver, backing, supply);

        emit Minted(_borrower, _receiver, _units, shares, front);

        return shares;
    }

    /// @dev Standard ERC-20 funding and refund leave prior cash unchanged; _take activates only internal offers.
    function _fundAndTake(Offer memory _offer, bytes memory _ratifierData, uint256 _units, uint256 _front)
        private
        returns (uint256)
    {
        uint256 balanceBefore = loanToken.balanceOf(address(this));
        SafeERC20.safeTransferFrom(loanToken, msg.sender, address(this), _front);
        (uint256 paid,) = _take(_offer, _ratifierData, _units, address(0));
        if (paid > _front) revert MoongladeNote__QuoteChanged();
        if (paid < _front) SafeERC20.safeTransfer(loanToken, msg.sender, _front - paid);
        if (loanToken.balanceOf(address(this)) != balanceBefore) revert MoongladeNote__InvalidLoanTokenTransfer();

        return paid;
    }

    /// @dev Issue shares only against measured net-credit growth, retaining the initial dead-share reserve.
    function _issue(address _receiver, uint256 _backingBefore, uint256 _supplyBefore) private returns (uint256) {
        uint256 shares = _sharesForMint(totalAssets() - _backingBefore, _backingBefore, _supplyBefore);
        if (_supplyBefore == 0) _mint(DEAD_SHARES, MINIMUM_SHARES);
        _mint(_receiver, shares);

        return shares;
    }

    /// @dev Require an external-ratifier offer of the expected direction in this market.
    function _checkExternalOffer(Offer calldata _offer, bool _buy) private view {
        if (_offer.buy != _buy || _offer.ratifier == ratifier || IdLib.toId(_offer.market) != marketId) {
            revert MoongladeNote__InvalidOffer();
        }
    }

    /// @dev Require nonzero uint128-compatible credit units and a market that has not matured.
    function _checkMintUnits(uint256 _units) private view {
        if (_units == 0 || _units > type(uint128).max) revert MoongladeNote__InvalidUnits();
        if (block.timestamp >= maturity) revert MoongladeNote__MarketMatured();
    }

    /// @dev Convert net-credit value to shares, rounding down and reserving minimum shares on initial issuance.
    /// Callers reject zero backing when supply is nonzero before settlement.
    function _sharesForMint(uint256 _value, uint256 _backing, uint256 _supply) private pure returns (uint256) {
        if (_supply == 0) {
            if (_value <= MINIMUM_SHARES) revert MoongladeNote__ZeroShares();
            return _value - MINIMUM_SHARES;
        }
        uint256 shares = Math.mulDiv(_value, _supply, _backing);
        if (shares == 0) revert MoongladeNote__ZeroShares();

        return shares;
    }

    /// @dev Convert shares to gross credit rounded down; associated pending fees leave the position too.
    function _unitsForBurn(uint256 _shares, uint256 _credit) private view returns (uint256) {
        if (_shares == 0 || totalSupply() == 0) revert MoongladeNote__ZeroShares();
        uint256 units = Math.mulDiv(_shares, _credit, totalSupply());
        if (units == 0) revert MoongladeNote__InvalidUnits();

        return units;
    }

    /// @dev Read the current settlement fee, using zero remaining time after maturity.
    function _settlementFee() private view returns (uint256) {
        uint256 timeLeft = block.timestamp < maturity ? maturity - block.timestamp : 0;

        return midnight.settlementFee(marketId, timeLeft);
    }

    /// @dev Build a borrower-made offer with a fresh nonce; Midnight validates its tick during settlement.
    /// The caller activates the offer hash while taking it.
    /// Sell-offer principal always returns to msg.sender, which supplied the temporary funding.
    function _buildOffer(bool _buy, uint256 _units, address _borrower, uint256 _tick) private returns (Offer memory) {
        Offer memory offer;

        offer.market = marketData;
        offer.buy = _buy;
        offer.maker = _borrower;
        offer.start = block.timestamp;
        offer.expiry = block.timestamp;
        offer.tick = _tick;
        offer.group = keccak256(abi.encode(address(this), ++nonce));
        offer.receiverIfMakerIsSeller = _buy ? address(0) : msg.sender;
        offer.ratifier = ratifier;
        offer.reduceOnly = _buy;
        // Mint inputs and burn outputs are bounded by uint128 Midnight position fields.
        offer.maxUnits = uint128(_units);
        offer.continuousFeeCap = midnight.continuousFee(marketId);

        return offer;
    }

    /// @notice Return the market configuration fixed during construction.
    /// @return Full Midnight market configuration.
    function market() external view returns (Market memory) {
        return marketData;
    }

    /// @notice Return loan-token face value per whole share, scaled by 1e18.
    /// @dev Reads updated Midnight credit, rounds down, and returns zero for empty supply; liquidity is separate.
    /// @return Net face value per share scaled by 1e18.
    function payoutPerShare() external view returns (uint256) {
        uint256 supply = totalSupply();

        return supply == 0 ? 0 : Math.mulDiv(totalAssets(), WAD, supply);
    }

    /// @notice Estimate proportional gross credit released and a conservative net settlement-fee bound.
    /// @dev Reads Midnight credit and rounds units down. Actual gross BUY funding is floor(units*tickPrice/WAD),
    /// calculated separately at the caller's chosen credit-unit tick; shares and debt units are not interchangeable.
    /// @param _shares Shares to burn; must release nonzero units.
    /// @return Gross credit units released.
    /// @return Conservative loan-token fee bound, rounded up; actual tick-based native fee may be lower.
    function previewBurn(uint256 _shares) external view returns (uint256, uint256) {
        (uint128 credit,,) = midnight.updatePositionView(marketData, marketId, address(this));
        uint256 units = _unitsForBurn(_shares, credit);
        uint256 cost = Math.mulDiv(units, _settlementFee(), WAD, Math.Rounding.Ceil);

        return (units, cost);
    }

    /// @notice Return the loan token decimals captured during construction.
    /// @return Number of decimal places used by shares.
    function decimals() public view override(ERC20, IERC20Metadata) returns (uint8) {
        return shareDecimals;
    }

    /// @notice Return net face value after losses and all remaining continuous fees.
    /// @dev Reads Midnight's updated position; direct loan-token donations do not affect backing or issuance.
    /// @return Net loan-token credit backing all shares.
    function totalAssets() public view returns (uint256) {
        (uint128 credit, uint128 pendingFee,) = midnight.updatePositionView(marketData, marketId, address(this));

        return uint256(credit) - pendingFee;
    }

    /// @notice Return the minimum gross credit units issuing at least the requested shares before maturity.
    /// @dev Reads Midnight fees and backing, rounds units up, and includes the initial minimum-share reserve.
    /// Cash funding is computed separately as ceil(units * (tickPrice + settlementFee) / WAD).
    /// @param _shares Minimum receiver shares; must be nonzero.
    /// @return Gross units required after fee rounding, independent of the wallet's existing credit.
    function previewMintUnits(uint256 _shares) public view returns (uint256) {
        if (_shares == 0) revert MoongladeNote__ZeroShares();
        if (block.timestamp >= maturity) revert MoongladeNote__MarketMatured();
        uint256 supply = totalSupply();
        uint256 backing = totalAssets();
        if (supply != 0 && backing == 0) revert MoongladeNote__ZeroBacking();
        uint256 value =
            supply == 0 ? _shares + MINIMUM_SHARES : Math.mulDiv(_shares, backing, supply, Math.Rounding.Ceil);
        // Midnight caps market lifetime at 100 years and annual continuous fees at 1%, keeping fee below WAD.
        uint256 fee = uint256(midnight.continuousFee(marketId)) * (maturity - block.timestamp);
        // units - floor(units * fee / WAD) >= value, including the final integer rounding.
        uint256 units = Math.mulDiv(value - 1, WAD, WAD - fee) + 1;
        // The nonzero share target and backing imply value >= 1 and units >= 1; maturity was checked above.
        if (units > type(uint128).max) revert MoongladeNote__InvalidUnits();

        return units;
    }
}
