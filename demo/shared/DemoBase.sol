// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { IERC20 } from "@openzeppelin-contracts/token/ERC20/IERC20.sol";
import { IWETH } from "@1inch/solidity-utils/contracts/interfaces/IWETH.sol";
import { IAqua } from "aqua/src/interfaces/IAqua.sol";
import { IMidnight, Market, CollateralParams } from "midnight/src/interfaces/IMidnight.sol";
import { ISwapVM } from "swap-vm/src/interfaces/ISwapVM.sol";

import { Script } from "forge-std/Script.sol";
import { StdCheats } from "forge-std/StdCheats.sol";
import { TakerTraitsLib } from "swap-vm/src/libs/TakerTraits.sol";

import { IYieldSpaceCurve } from "src/curves/interfaces/IYieldSpaceCurve.sol";
import { IMoongladeCurve } from "src/curves/interfaces/IMoongladeCurve.sol";
import { IMoongladeNote } from "src/note/interfaces/IMoongladeNote.sol";
import { IMoongladeNoteFactory } from "src/note/interfaces/IMoongladeNoteFactory.sol";
import { IMoongladeDeskHook } from "src/hooks/interfaces/IMoongladeDeskHook.sol";
import { IMoongladeSwap } from "src/instructions/interfaces/IMoongladeSwap.sol";

import { YieldSpaceCurveConfig } from "src/curves/YieldSpaceCurveConfig.sol";
import { DemoCurveConfig } from "demo/shared/DemoCurveConfig.sol";
import { DemoOracle } from "demo/shared/DemoOracle.sol";
import { DemoOutput } from "demo/shared/DemoOutput.sol";

/// @title Moonglade fork demo base.
/// @author Sahil Gujrati (@mgnfy-view).
/// @notice Fresh, reproducible Base-fork setup shared by the presentation scripts.
/// @dev Local simulation only: actors are impersonated and USDC funding is a fork fixture.
/// Official Aqua, Midnight, and token bytecode are never replaced. Only the demo market's fees are overridden.
/// Fork fixtures use prank cheatcodes rather than broadcast transactions, as required by the demo workflow.
abstract contract DemoBase is Script, StdCheats, DemoOutput {
    /// @notice Public fork inputs shared by the standalone scenes.
    struct Config {
        /// @notice Base block selected by the runner and required by the scene.
        uint256 forkBlock;
        /// @notice Maker-selected pricing spread on both bid and ask, in basis points; zero disables it.
        uint16 feeBps;
    }

    /// @notice USDC pricing components retained by the maker for the actual volume of one swap.
    struct SwapFees {
        /// @notice Fee rate read from the selected desk's committed curve configuration.
        uint16 feeBps;
        /// @notice Difference between fee-bearing and zero-fee curve quotes for the same executed shares.
        uint256 curveFee;
        /// @notice Additional maker-favored price improvement from tick and native amount rounding.
        uint256 roundingSpread;
    }

    // ===== Constants =====

    /// @notice Scale of prices, rates, and payout factors.
    uint256 internal constant WAD = 1e18;
    /// @notice Native precision of USDC and mgNOTE.
    uint256 internal constant UNIT = 1e6;
    /// @notice Initial maker cash and each strategy's virtual cash allocation.
    uint256 internal constant BUDGET = 1_000_000 * UNIT;
    /// @notice Virtual note reserve producing an initial annual rate near eight percent.
    uint256 internal constant VIRTUAL_NOTES = 2_225_540_928_492;
    /// @notice Official Base USDC used for the real token transfers on the fork.
    IERC20 internal constant USDC = IERC20(0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913);
    /// @notice Official Base WETH used to wrap fixture ETH and collateralize positions.
    IWETH internal constant WETH = IWETH(0x4200000000000000000000000000000000000006);
    /// @notice Official Base Aqua registry; its bytecode is preserved.
    IAqua internal constant AQUA = IAqua(0x1111113CCf1426A8E30e2bfF5E005d929bF6a90a);
    /// @notice Official Base Midnight; governance configuration changes remain local to the fork.
    IMidnight internal constant MIDNIGHT = IMidnight(0xAdedD8ab6dE832766Fedf0FaC4992E5C4D3EA18A);

    // ===== State =====

    /// @notice Wallet owning both the Aqua strategies and the maker's Midnight position.
    address internal maker;
    /// @notice Fixture wallet purchasing and redeeming credit shares.
    address internal lender;
    /// @notice Fixture wallet granting bounded mint consent against its own collateral.
    address internal borrower;
    /// @notice Official Midnight instance used by the current scene.
    IMidnight internal midnight;
    /// @notice Market-specific credit share token created by the note factory.
    IMoongladeNote internal note;
    /// @notice First configured maker desk, shared by the ordinary scenes.
    IMoongladeDeskHook internal hook;
    /// @notice Locally deployed custom SwapVM router bound to official Aqua.
    ISwapVM internal router;
    /// @notice Locally deployed YieldSpace pricing implementation.
    address internal curve;
    /// @notice Custom WETH/USDC market configuration created on the fork.
    Market internal market;
    /// @notice Canonical Midnight identifier of the custom market.
    bytes32 internal marketId;
    /// @notice Local calldata adapter used to read the maker's committed curve settings.
    DemoCurveConfig private curveConfigDecoder;

    /// @notice A scene's required token, position, or configuration invariant failed.
    /// @param _reason Description of the failed scene check.
    error DemoBase__CheckFailed(string _reason);

    // ===== Common output =====

    /// @notice Print shared fork settings and fixture disclosures in a dedicated section before the scenes.
    /// @dev The runner invokes this entry point once using a separate local simulation of the same setup.
    /// Scene execution remains independent; no state or deployed contracts carry over from this call.
    function showConfig() external {
        _setup();
        Config memory config = _loadConfig();
        _heading("Common configuration");
        _value("Network", string.concat("Base fork / chain ", vm.toString(block.chainid)));
        _value("Fork block", vm.toString(block.number));
        _value("Official Aqua", vm.toString(address(AQUA)));
        _value("Official Midnight", vm.toString(address(midnight)));
        _value("Custom SwapVM router", vm.toString(address(router)));
        _value("Custom WETH/USDC market", vm.toString(marketId));
        _value("Market configuration", "Fork-only governance impersonation");
        _value("Opening balances", "Fork fixtures; no live funds used");
        _value("Collateral oracle", "Fixed $2,000/WETH demo fixture");
        _value("Maker pricing fee", _rate(uint256(config.feeBps) * WAD / YieldSpaceCurveConfig.BPS));
        _value("Fee accounting", "Embedded in USDC price; rounding spread separate");
    }

    // ===== Internal setup =====

    /// @notice Deploy Moonglade on a Base fork, fund the actors, and register the maker strategy.
    /// @dev Impersonates fork governance and actors; fixture funding and the fixed oracle are not live inputs.
    function _setup() internal {
        _require(block.chainid == 8453, "Run on a Base fork");
        _require(block.number == _loadConfig().forkBlock, "Unexpected fork block");
        maker = makeAddr("Maker");
        lender = makeAddr("Lender");
        borrower = makeAddr("Borrower");

        midnight = MIDNIGHT;
        _enableCollateralParameters();
        CollateralParams[] memory collateral = new CollateralParams[](1);
        collateral[0] = CollateralParams(address(WETH), 0.8e18, 0.3e18, address(new DemoOracle()));
        market = Market(
            block.chainid,
            address(midnight),
            address(USDC),
            collateral,
            block.timestamp + 180 days,
            0,
            address(0),
            address(0)
        );
        IMoongladeNoteFactory factory =
            IMoongladeNoteFactory(deployCode("MoongladeNoteFactory.sol:MoongladeNoteFactory", abi.encode(midnight)));
        note = IMoongladeNote(factory.create(market));
        marketId = note.marketId();
        _configureMarketFees();
        curve = deployCode("YieldSpaceCurve.sol:YieldSpaceCurve");
        router = ISwapVM(deployCode("MoongladeRouter.sol:MoongladeRouter", abi.encode(AQUA, WETH)));
        hook = _newDesk();

        // Fork-only opening balances. Subsequent swaps use the real USDC/WETH transfer implementations.
        deal(address(USDC), maker, BUDGET);
        deal(address(USDC), lender, 100_000 * UNIT);
        _wrapEth(maker, 1_000 ether);
        _register(hook);
        vm.startPrank(lender);
        USDC.approve(address(router), type(uint256).max);
        note.approve(address(router), type(uint256).max);
        vm.stopPrank();
        curveConfigDecoder = new DemoCurveConfig();
    }

    /// @notice Enable the custom collateral policy through the actual configurator on the fork.
    /// @dev Governance impersonation is local; existing enabled parameters remain available.
    function _enableCollateralParameters() private {
        vm.startPrank(midnight.configurator());
        midnight.enableLltv(0.8e18);
        midnight.enableLiquidationCursor(0.3e18);
        vm.stopPrank();
    }

    /// @notice Set the custom market's fees through fork-only governance impersonation.
    /// @dev Restores the original fee setter and leaves global USDC fee defaults unchanged.
    function _configureMarketFees() private {
        address originalFeeSetter = midnight.feeSetter();
        address configurator = midnight.configurator();
        vm.startPrank(configurator);
        midnight.setFeeSetter(configurator);
        midnight.setMarketContinuousFee(marketId, uint256(0.005e18) / 365 days);
        uint256[7] memory fees = [uint256(14e12), 14e12, 98e12, 417e12, 500e12, 500e12, 500e12];
        for (uint256 i; i < fees.length; ++i) {
            midnight.setMarketSettlementFee(marketId, i, fees[i]);
        }
        midnight.setFeeSetter(originalFeeSetter);
        vm.stopPrank();
    }

    /// @notice Deploy a desk bound to the current maker, note, and router.
    /// @dev Artifact loading keeps the Solidity compiler graphs separate; the actual constructor executes.
    /// @return Newly deployed, unconfigured desk hook.
    function _newDesk() internal returns (IMoongladeDeskHook) {
        IMoongladeDeskHook desk =
            IMoongladeDeskHook(deployCode("MoongladeDeskHook.sol:MoongladeDeskHook", abi.encode(maker, note, router)));
        return desk;
    }

    /// @notice Authorize a desk and register its virtual budgets without depositing the maker's assets.
    /// @dev Uses fork impersonation; the maker retains its tokens until the hook or Aqua settles a fill.
    /// @param _desk Hook receiving operator permissions and token allowances.
    function _register(IMoongladeDeskHook _desk) internal {
        uint64 sensitivity = 0.1e18;
        uint64 rateFloor = 0.005e18;
        uint16 feeBps = _loadConfig().feeBps;
        IYieldSpaceCurve.Parameters memory parameters =
            IYieldSpaceCurve.Parameters({ sensitivity: sensitivity, rateFloor: rateFloor, feeBps: feeBps });
        bytes memory pricingData = YieldSpaceCurveConfig.encode(parameters);

        vm.startPrank(maker);
        midnight.setIsAuthorized(address(_desk), true, maker);
        midnight.setIsAuthorized(note.ratifier(), true, maker);
        USDC.approve(address(AQUA), type(uint256).max);
        note.approve(address(AQUA), type(uint256).max);
        USDC.approve(address(_desk), type(uint256).max);
        note.approve(address(_desk), type(uint256).max);
        WETH.approve(address(_desk), type(uint256).max);
        _desk.configure(
            IMoongladeSwap.Config(address(note), curve, pricingData),
            IMoongladeDeskHook.RiskConfig(BUDGET, BUDGET, 100 * UNIT, 0, 0.8e18, 1_000 ether, true)
        );
        uint256[] memory budgets = new uint256[](2);
        budgets[0] = BUDGET;
        budgets[1] = VIRTUAL_NOTES;
        AQUA.ship(address(router), abi.encode(_desk.order()), _desk.tokens(), budgets);
        vm.stopPrank();
    }

    /// @notice Fund and collateralize a borrower, then grant exact gross-unit mint consent.
    /// @dev Wraps fixture ETH through real WETH and approves the hook only for the previewed issuance budget.
    /// @param _shares Note input the borrower will create and sell through one swap.
    /// @return Gross units authorized for the borrower's scoped mint.
    function _prepareBorrower(uint256 _shares) internal returns (uint256) {
        _wrapEth(borrower, 100 ether);
        uint256 units = note.previewMintUnits(_shares);
        vm.startPrank(borrower);
        WETH.approve(address(midnight), 100 ether);
        midnight.supplyCollateral(market, 0, 100 ether, borrower);
        midnight.setIsAuthorized(note.ratifier(), true, borrower);
        note.approveMint(address(hook), uint128(units), uint40(market.maturity));
        note.approve(address(router), type(uint256).max);
        vm.stopPrank();
        return units;
    }

    /// @notice Wrap locally funded ETH through the fork's official WETH implementation.
    /// @param _actor Wallet receiving the ETH fixture and resulting WETH.
    /// @param _amount Native ETH amount to fund and wrap.
    function _wrapEth(address _actor, uint256 _amount) internal {
        vm.deal(_actor, _amount);
        vm.prank(_actor);
        WETH.deposit{ value: _amount }();
    }

    /// @notice Encode exact-input settlement with a one-hour deadline and input-first payment.
    /// @param _actor Authenticated taker whose assets fund the swap.
    /// @param _minOutput Minimum output amount; zero permits an unconstrained quote.
    /// @return Encoded SwapVM taker traits and settlement data.
    function _traits(address _actor, uint256 _minOutput) internal view returns (bytes memory) {
        TakerTraitsLib.Args memory args;
        args.taker = _actor;
        args.isExactIn = true;
        args.isFirstTransferFromTaker = true;
        args.useTransferFromAndAquaPush = true;
        args.threshold = abi.encode(_minOutput);
        args.deadline = uint40(block.timestamp + 1 hours);
        bytes memory traits = TakerTraitsLib.build(args);

        return traits;
    }

    /// @notice Quote and execute a real fork-token swap, verifying output and temporary cash balances.
    /// @dev Borrowing may mint the taker's note input in the pre-transfer hook; output must still match its quote.
    /// Fee accounting snapshots the selected desk's pre-trade reserves, payout, time, and curve settings.
    /// @param _desk Registered desk whose order and pricing configuration apply to this fill.
    /// @param _actor Taker impersonated for quote and swap execution.
    /// @param _lend Whether the swap spends USDC to receive notes, rather than notes to receive USDC.
    /// @param _amount Exact native input amount.
    /// @return Actual native output transferred into the taker's wallet.
    /// @return Embedded curve fee and additional tick spread, both denominated in USDC.
    function _swap(IMoongladeDeskHook _desk, address _actor, bool _lend, uint256 _amount)
        internal
        returns (uint256, SwapFees memory)
    {
        bytes memory takerData = _traits(_actor, 0);
        ISwapVM.Order memory order = _desk.order();
        address tokenIn = _lend ? address(USDC) : address(note);
        address tokenOut = _lend ? address(note) : address(USDC);
        uint256 beforeOutput = IERC20(tokenOut).balanceOf(_actor);
        vm.prank(_actor);
        (, uint256 quotedOut,) = router.quote(order, tokenIn, tokenOut, _amount, takerData);
        takerData = _traits(_actor, quotedOut);
        SwapFees memory fees = _swapFees(_desk, _lend, _amount, quotedOut);
        vm.prank(_actor);
        (, uint256 actualOut,) = router.swap(order, tokenIn, tokenOut, _amount, takerData);
        _require(actualOut == quotedOut, "Quote differs from swap");
        _require(IERC20(tokenOut).balanceOf(_actor) == beforeOutput + actualOut, "Output transfer differs from quote");
        _require(USDC.balanceOf(address(_desk)) == 0 && USDC.balanceOf(address(note)) == 0, "Temporary cash retained");

        return (actualOut, fees);
    }

    /// @notice Isolate the embedded USDC curve fee from the extra improvement due to execution rounding.
    /// @dev Compare quotes for the actual executed share volume at identical pre-trade state. Both quotes retain
    /// the numerical margin; only the fee rate changes. These components are included in the swap price and
    /// represent gross price improvement, excluding Midnight settlement costs and other maker expenses.
    /// The residual includes tick snapping, native amount rounding, and inverse-versus-forward quote rounding.
    /// @param _desk Desk whose committed pricing settings and Aqua allocations are used.
    /// @param _lend Whether USDC is the input rather than the output.
    /// @param _amountIn Exact swap input.
    /// @param _amountOut Quoted output, checked against execution by the caller.
    /// @return Fee rate, embedded curve-fee value, and extra tick spread.
    function _swapFees(IMoongladeDeskHook _desk, bool _lend, uint256 _amountIn, uint256 _amountOut)
        private
        view
        returns (SwapFees memory)
    {
        IMoongladeSwap.Config memory pricing = _desk.curveConfig();
        IYieldSpaceCurve.Parameters memory parameters = curveConfigDecoder.decode(pricing.data);
        (uint256 cashReserve, uint256 noteReserve) =
            AQUA.safeBalances(maker, address(router), _desk.strategyHash(), address(USDC), address(note));
        IMoongladeCurve.MarketState memory beforeMarket = IMoongladeCurve.MarketState({
            note: address(note),
            cashBalance: cashReserve,
            noteBalance: noteReserve,
            timeLeft: market.maturity - block.timestamp,
            payout: note.totalSupply() == 0 ? WAD : note.payoutPerShare()
        });
        uint256 shares = _lend ? _amountOut : _amountIn;
        uint256 cash = _lend ? _amountIn : _amountOut;
        (, uint256 feeQuote) = IMoongladeCurve(pricing.curve).quote(beforeMarket, shares, true, !_lend, pricing.data);
        SwapFees memory fees;
        fees.feeBps = parameters.feeBps;
        parameters.feeBps = 0;
        (, uint256 zeroFeeQuote) = IMoongladeCurve(pricing.curve)
            .quote(beforeMarket, shares, true, !_lend, YieldSpaceCurveConfig.encode(parameters));
        _require(
            _lend ? cash >= feeQuote && feeQuote >= zeroFeeQuote : zeroFeeQuote >= feeQuote && feeQuote >= cash,
            "Fee decomposition inconsistent"
        );
        fees.curveFee = _lend ? feeQuote - zeroFeeQuote : zeroFeeQuote - feeQuote;
        fees.roundingSpread = _lend ? cash - feeQuote : feeQuote - cash;

        return fees;
    }

    /// @notice Print the selected fee rate, its embedded USDC value, and the extra tick spread for one swap.
    /// @param _label Scene-specific description of the fill's maker fee.
    /// @param _fees Pricing components captured before the swap.
    function _showSwapFees(string memory _label, SwapFees memory _fees) internal pure {
        uint256 feeRate = uint256(_fees.feeBps) * WAD / YieldSpaceCurveConfig.BPS;
        _value(_label, string.concat(_amount(_fees.curveFee, 6, "USDC"), " (", _rate(feeRate), ", embedded)"));
        _value("Tick / rounding spread", _amount(_fees.roundingSpread, 6, "USDC"));
    }

    /// @notice Revert the scene if an expected invariant does not hold.
    /// @param _condition Whether the invariant holds.
    /// @param _reason Description included in the custom failure error.
    function _require(bool _condition, string memory _reason) internal pure {
        if (!_condition) revert DemoBase__CheckFailed(_reason);
    }

    // ===== Internal views =====

    /// @notice Load public fork settings from the environment documented in .env.example.
    /// @return Fork block and maker-selected fee, using the runner's default block when unspecified.
    function _loadConfig() internal view returns (Config memory) {
        uint256 defaultFeeBps = 30;
        uint256 loadedFee = vm.envOr("DEMO_TRADE_FEE_BPS", defaultFeeBps);
        _require(loadedFee < YieldSpaceCurveConfig.BPS, "Maker pricing fee must be below 10000 bps");
        Config memory config =
            Config({ forkBlock: vm.envOr("DEMO_FORK_BLOCK", uint256(52_000_000)), feeBps: uint16(loadedFee) });

        return config;
    }

    /// @notice Print the selected curve's annual rate before and after the scene's trade.
    /// @param _before Pre-trade WAD annual rate.
    function _rateChange(uint256 _before) internal view {
        _value("Curve annual rate", string.concat(_rate(_before), " -> ", _rate(hook.currentRate())));
    }
}
