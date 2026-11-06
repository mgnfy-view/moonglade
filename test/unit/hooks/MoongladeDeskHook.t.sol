// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { IMidnight, Market, CollateralParams } from "midnight/src/interfaces/IMidnight.sol";
import { IOracle } from "midnight/src/interfaces/IOracle.sol";

import { ERC20 } from "@openzeppelin-contracts/token/ERC20/ERC20.sol";
import { Aqua } from "aqua/src/Aqua.sol";
import { Test } from "forge-std/Test.sol";

import { IYieldSpaceCurve } from "src/curves/interfaces/IYieldSpaceCurve.sol";
import { IMoongladeDeskHook } from "src/hooks/interfaces/IMoongladeDeskHook.sol";
import { IMoongladeSwap } from "src/instructions/interfaces/IMoongladeSwap.sol";
import { IMoongladeNote } from "src/note/interfaces/IMoongladeNote.sol";
import { IMoongladeNoteFactory } from "src/note/interfaces/IMoongladeNoteFactory.sol";

import { YieldSpaceCurve } from "src/curves/YieldSpaceCurve.sol";
import { YieldSpaceCurveConfig } from "src/curves/YieldSpaceCurveConfig.sol";
import { MoongladeDeskHook } from "src/hooks/MoongladeDeskHook.sol";
import { MoongladeRouter } from "src/routers/MoongladeRouter.sol";

contract MoongladeDeskHookTest is Test {
    uint256 private constant UNIT = 1e6;

    address private maker;
    address private borrower;
    IMidnight private midnight;
    Aqua private aqua;
    HookTestToken private loan;
    HookTestToken private collateral;
    IMoongladeNote private note;
    MoongladeRouter private router;
    MoongladeDeskHook private hook;
    Market private market;
    bytes32 private marketId;
    bytes32 private strategyHash;
    IMoongladeSwap.Config private pricing;

    function setUp() public {
        uint256 initialTimestamp = 1_800_000_000;
        uint8 loanDecimals = 6;
        uint8 collateralDecimals = 18;
        uint256 loanToValue = 0.8e18;
        uint256 liquidationCursor = 0.3e18;
        uint256 marketDuration = 180 days;
        uint256 annualContinuousFee = 0.005e18;
        uint256 oneDaySettlementFee = 14e12;
        uint256 sevenDaySettlementFee = 98e12;
        uint256 thirtyDaySettlementFee = 417e12;
        uint256 longTermSettlementFee = 500e12;
        uint256 openingCash = 1_000_000 * UNIT;
        uint256 openingCollateral = 1000 ether;
        uint64 sensitivity = 0.1e18;
        uint64 rateFloor = 0.005e18;
        uint16 feeBps = 30;

        vm.warp(initialTimestamp);
        maker = makeAddr("maker");
        borrower = makeAddr("borrower");
        // Load the real 0.8.34 implementations without importing them into the 0.8.30 SwapVM graph.
        midnight = IMidnight(deployCode("Midnight.sol:Midnight"));
        aqua = new Aqua();
        loan = new HookTestToken("USDC", loanDecimals);
        collateral = new HookTestToken("WETH", collateralDecimals);
        midnight.setFeeSetter(address(this));
        midnight.enableLltv(loanToValue);
        midnight.enableLiquidationCursor(liquidationCursor);
        midnight.setDefaultContinuousFee(address(loan), annualContinuousFee / 365 days);
        uint256[7] memory fees = [
            oneDaySettlementFee,
            oneDaySettlementFee,
            sevenDaySettlementFee,
            thirtyDaySettlementFee,
            longTermSettlementFee,
            longTermSettlementFee,
            longTermSettlementFee
        ];
        for (uint256 i; i < fees.length; ++i) {
            midnight.setDefaultSettlementFee(address(loan), i, fees[i]);
        }

        CollateralParams[] memory params = new CollateralParams[](1);
        params[0] = CollateralParams(address(collateral), loanToValue, liquidationCursor, address(new HookTestOracle()));
        market = Market(
            block.chainid,
            address(midnight),
            address(loan),
            params,
            block.timestamp + marketDuration,
            0,
            address(0),
            address(0)
        );
        IMoongladeNoteFactory factory =
            IMoongladeNoteFactory(deployCode("MoongladeNoteFactory.sol:MoongladeNoteFactory", abi.encode(midnight)));
        note = IMoongladeNote(factory.create(market));
        marketId = note.marketId();
        router = new MoongladeRouter(address(aqua), address(collateral));
        hook = new MoongladeDeskHook(maker, note, router);
        pricing = IMoongladeSwap.Config(
            address(note),
            address(new YieldSpaceCurve()),
            YieldSpaceCurveConfig.encode(
                IYieldSpaceCurve.Parameters({ sensitivity: sensitivity, rateFloor: rateFloor, feeBps: feeBps })
            )
        );
        loan.mint(maker, openingCash);
        collateral.mint(maker, openingCollateral);
        _register(_defaultRisk());
    }

    function testOnlyMakerCanConfigureOrDeactivateAndActiveStrategyCannotBeReplaced() public {
        IMoongladeDeskHook.RiskConfig memory limits = hook.riskConfig();

        vm.expectRevert(IMoongladeDeskHook.MoongladeDeskHook__Unauthorized.selector);
        hook.configure(pricing, limits);
        vm.expectRevert(IMoongladeDeskHook.MoongladeDeskHook__Unauthorized.selector);
        hook.deactivate();

        vm.prank(maker);
        vm.expectRevert(IMoongladeDeskHook.MoongladeDeskHook__StrategyActive.selector);
        hook.configure(pricing, limits);
        assertTrue(hook.active());
        assertTrue(hook.isRegistered());
    }

    function testMakerMintCreatesOnlyInventoryShortfallAndPostsCollateral() public {
        uint256 initialInventory = 2000 * UNIT;
        uint256 initialCash = 1920 * UNIT;
        uint256 requestedShares = 10_000 * UNIT;
        uint256 swapCash = 9600 * UNIT;
        _mintInventory(initialInventory, initialCash);
        uint256 debtBefore = midnight.debt(marketId, maker);
        uint256 missingShares = requestedShares - initialInventory;
        uint256 expectedAdditionalUnits = note.previewMintUnits(missingShares);
        uint256 cashBefore = loan.balanceOf(maker);

        _mintInventory(requestedShares, swapCash);

        uint256 debtAfter = midnight.debt(marketId, maker);
        assertEq(note.balanceOf(maker), requestedShares);
        assertEq(debtAfter - debtBefore, expectedAdditionalUnits);
        assertEq(midnight.collateral(marketId, maker, 0), hook.requiredCollateral(debtAfter));
        assertGt(midnight.collateral(marketId, maker, 0), 0);
        assertLt(loan.balanceOf(maker), cashBefore);
        assertEq(loan.balanceOf(address(hook)), 0);
        assertEq(collateral.balanceOf(address(hook)), 0);
        assertEq(note.balanceOf(address(hook)), 0);
    }

    function testBorrowerMintUsesScopedBudgetWithoutCreatingMakerDebt() public {
        uint256 requestedShares = 10_000 * UNIT;
        uint256 swapCash = 9600 * UNIT;
        uint256 borrowerCollateral = 100 ether;
        uint256 expectedUnits = note.previewMintUnits(requestedShares);
        uint40 deadline = uint40(market.maturity);
        collateral.mint(borrower, borrowerCollateral);
        vm.startPrank(borrower);
        collateral.approve(address(midnight), borrowerCollateral);
        midnight.supplyCollateral(market, 0, borrowerCollateral, borrower);
        midnight.setIsAuthorized(note.ratifier(), true, borrower);
        note.approveMint(address(hook), uint128(expectedUnits), deadline);
        vm.stopPrank();

        vm.prank(address(router));
        hook.preTransferIn(
            maker, borrower, address(note), address(loan), requestedShares, swapCash, strategyHash, "", ""
        );

        (uint128 remaining,) = note.borrowAllowances(borrower, address(hook));
        assertEq(remaining, 0);
        assertEq(note.balanceOf(borrower), requestedShares);
        assertEq(midnight.debt(marketId, borrower), expectedUnits);
        assertEq(midnight.collateral(marketId, borrower, 0), borrowerCollateral);
        assertEq(midnight.debt(marketId, maker), 0);
        assertEq(note.balanceOf(maker), 0);
        assertEq(loan.balanceOf(address(hook)), 0);
    }

    function testIncomingNotesCancelMakerDebtAndReleaseCollateral() public {
        uint256 requestedShares = 10_000 * UNIT;
        uint256 swapCash = 9600 * UNIT;
        _mintInventory(requestedShares, swapCash);
        // Complete the outgoing and incoming note transfers before invoking the post-input callback.
        vm.prank(maker);
        note.transfer(borrower, requestedShares);
        vm.prank(borrower);
        note.transfer(maker, requestedShares);
        uint256 debtBefore = midnight.debt(marketId, maker);
        uint256 collateralBefore = midnight.collateral(marketId, maker, 0);
        uint256 walletCollateralBefore = collateral.balanceOf(maker);
        (uint256 expectedRepaid,) = note.previewBurn(requestedShares);

        vm.prank(address(router));
        hook.postTransferIn(
            maker, borrower, address(note), address(loan), requestedShares, swapCash, strategyHash, "", ""
        );

        uint256 remainingDebt = midnight.debt(marketId, maker);
        uint256 remainingCollateral = midnight.collateral(marketId, maker, 0);
        assertEq(remainingDebt, debtBefore - expectedRepaid);
        assertLt(remainingCollateral, collateralBefore);
        assertEq(remainingCollateral, hook.requiredCollateral(remainingDebt));
        assertEq(collateral.balanceOf(maker) - walletCollateralBefore, collateralBefore - remainingCollateral);
        assertEq(note.balanceOf(maker), 0);
        assertEq(note.totalSupply(), note.MINIMUM_SHARES());
        assertEq(loan.balanceOf(address(hook)), 0);
        assertEq(note.balanceOf(address(hook)), 0);
        assertEq(loan.allowance(address(hook), address(midnight)), 0);
    }

    function testRejectsUntrustedWrongStrategyAndInactiveCallbacks() public {
        uint256 requestedShares = 1000 * UNIT;
        uint256 swapCash = 960 * UNIT;
        bytes32 wrongStrategyHash = keccak256("wrong strategy");

        vm.expectRevert(IMoongladeDeskHook.MoongladeDeskHook__InvalidHook.selector);
        hook.preTransferOut(
            maker, borrower, address(loan), address(note), swapCash, requestedShares, strategyHash, "", ""
        );
        vm.prank(address(router));
        vm.expectRevert(IMoongladeDeskHook.MoongladeDeskHook__InvalidHook.selector);
        hook.preTransferOut(
            maker, borrower, address(loan), address(note), swapCash, requestedShares, wrongStrategyHash, "", ""
        );

        vm.prank(maker);
        hook.deactivate();
        vm.expectRevert(IMoongladeDeskHook.MoongladeDeskHook__InvalidHook.selector);
        _mintInventory(requestedShares, swapCash);
        assertEq(midnight.debt(marketId, maker), 0);
        assertEq(note.totalSupply(), 0);
    }

    function testDebtLimitRevertsWithoutMovingMakerFunds() public {
        uint256 requestedShares = 1000 * UNIT;
        uint256 swapCash = 960 * UNIT;
        IMoongladeDeskHook.RiskConfig memory limits = hook.riskConfig();
        limits.maxDebt = 0;
        _replaceRisk(limits);
        uint256 cashBefore = loan.balanceOf(maker);
        uint256 collateralBefore = collateral.balanceOf(maker);

        vm.expectRevert(IMoongladeDeskHook.MoongladeDeskHook__DebtLimit.selector);
        _mintInventory(requestedShares, swapCash);

        assertEq(loan.balanceOf(maker), cashBefore);
        assertEq(collateral.balanceOf(maker), collateralBefore);
        assertEq(midnight.debt(marketId, maker), 0);
        assertEq(midnight.collateral(marketId, maker, 0), 0);
        assertEq(note.totalSupply(), 0);
    }

    function testMintFloatLimitRollsBackCollateralPosting() public {
        uint256 requestedShares = 1000 * UNIT;
        uint256 swapCash = 960 * UNIT;
        IMoongladeDeskHook.RiskConfig memory limits = hook.riskConfig();
        limits.maxMintFront = 0;
        _replaceRisk(limits);
        uint256 cashBefore = loan.balanceOf(maker);
        uint256 collateralBefore = collateral.balanceOf(maker);

        vm.expectRevert(IMoongladeDeskHook.MoongladeDeskHook__FrontExceedsLimit.selector);
        _mintInventory(requestedShares, swapCash);

        assertEq(loan.balanceOf(maker), cashBefore);
        assertEq(collateral.balanceOf(maker), collateralBefore);
        assertEq(midnight.collateral(marketId, maker, 0), 0);
        assertEq(midnight.debt(marketId, maker), 0);
        assertEq(note.totalSupply(), 0);
    }

    function testMidnightBuyCallbackRequiresAnActiveBurnContext() public {
        uint256 buyerAssets = 960 * UNIT;
        uint256 creditUnits = 1000 * UNIT;

        vm.prank(address(midnight));
        vm.expectRevert(IMoongladeDeskHook.MoongladeDeskHook__InvalidCallback.selector);
        hook.onBuy(marketId, market, buyerAssets, creditUnits, 0, maker, "");
    }

    function _defaultRisk() private pure returns (IMoongladeDeskHook.RiskConfig memory) {
        uint256 maxDebt = 100_000 * UNIT;
        uint256 maxMintFront = 100_000 * UNIT;
        uint256 maxBurnCost = 100 * UNIT;
        uint256 targetUtilization = 0.8e18;
        uint256 maxCollateral = 1000 ether;
        return
            IMoongladeDeskHook.RiskConfig(maxDebt, maxMintFront, maxBurnCost, 0, targetUtilization, maxCollateral, true);
    }

    function _register(IMoongladeDeskHook.RiskConfig memory _limits) private {
        uint256 cashBudget = 1_000_000 * UNIT;
        uint256 noteBudget = 2_225_540_928_492;
        uint256[] memory budgets = new uint256[](2);
        budgets[0] = cashBudget;
        budgets[1] = noteBudget;
        vm.startPrank(maker);
        midnight.setIsAuthorized(address(hook), true, maker);
        midnight.setIsAuthorized(note.ratifier(), true, maker);
        loan.approve(address(hook), type(uint256).max);
        note.approve(address(hook), type(uint256).max);
        loan.approve(address(aqua), type(uint256).max);
        note.approve(address(aqua), type(uint256).max);
        collateral.approve(address(hook), type(uint256).max);
        strategyHash = hook.configure(pricing, _limits);
        aqua.ship(address(router), abi.encode(hook.order()), hook.tokens(), budgets);
        vm.stopPrank();
    }

    function _replaceRisk(IMoongladeDeskHook.RiskConfig memory _limits) private {
        vm.startPrank(maker);
        hook.deactivate();
        aqua.dock(address(router), strategyHash, hook.tokens());
        vm.stopPrank();
        _register(_limits);
    }

    function _mintInventory(uint256 _shares, uint256 _cash) private {
        vm.prank(address(router));
        hook.preTransferOut(maker, borrower, address(loan), address(note), _cash, _shares, strategyHash, "", "");
    }
}

contract HookTestToken is ERC20 {
    uint8 private immutable tokenDecimals;

    constructor(string memory _symbol, uint8 _decimals) ERC20(_symbol, _symbol) {
        tokenDecimals = _decimals;
    }

    function decimals() public view override returns (uint8) {
        return tokenDecimals;
    }

    function mint(address _receiver, uint256 _amount) external {
        _mint(_receiver, _amount);
    }
}

contract HookTestOracle is IOracle {
    function price() external pure returns (uint256) {
        uint256 wethPrice = 2000e24;
        return wethPrice;
    }
}
