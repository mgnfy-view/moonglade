// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { IERC20Metadata } from "@openzeppelin-contracts/token/ERC20/extensions/IERC20Metadata.sol";

import { Test } from "forge-std/Test.sol";

import { IMoongladeCurve } from "src/curves/interfaces/IMoongladeCurve.sol";
import { IYieldSpaceCurve } from "src/curves/interfaces/IYieldSpaceCurve.sol";

import { YieldSpaceCurve } from "src/curves/YieldSpaceCurve.sol";
import { YieldSpaceCurveConfig } from "src/curves/YieldSpaceCurveConfig.sol";

contract YieldSpaceCurveTest is Test {
    YieldSpaceCurve private curve;
    IMoongladeCurve.MarketState private market;
    bytes private parameters;

    function setUp() public {
        curve = new YieldSpaceCurve();
        address note = address(0xBEEF);
        uint8 noteDecimals = 6;
        uint256 virtualCashReserve = 1_000_000e6;
        uint256 virtualNoteReserve = 2_225_540_928_492;
        uint256 timeUntilMaturity = 180 days;
        uint256 payoutPerShare = 1e18;
        uint64 annualRateSensitivity = 0.1e18;
        vm.etch(note, hex"00");
        vm.mockCall(note, abi.encodeCall(IERC20Metadata.decimals, ()), abi.encode(noteDecimals));
        market = IMoongladeCurve.MarketState({
            note: note,
            cashBalance: virtualCashReserve,
            noteBalance: virtualNoteReserve,
            timeLeft: timeUntilMaturity,
            payout: payoutPerShare
        });
        parameters = YieldSpaceCurveConfig.encode(
            IYieldSpaceCurve.Parameters({ sensitivity: annualRateSensitivity, rateFloor: 0, feeBps: 0 })
        );
    }

    function testQuoteFixedSharesInBothDirections() public view {
        uint256 requestedShares = 1_000e6;
        uint256 expectedAssetsPaid = 961_282_600;
        uint256 expectedAssetsReceived = 961_349_478;
        uint256 nativeAmountTolerance = 2;
        (uint256 boughtShares, uint256 assetsPaid) = curve.quote(market, requestedShares, true, true, parameters);
        (uint256 soldShares, uint256 assetsReceived) = curve.quote(market, requestedShares, true, false, parameters);

        assertEq(boughtShares, requestedShares);
        assertEq(soldShares, requestedShares);
        // Independent decimal evaluation of x^a + y^a, including margin and native rounding.
        assertApproxEqAbs(assetsPaid, expectedAssetsPaid, nativeAmountTolerance);
        assertApproxEqAbs(assetsReceived, expectedAssetsReceived, nativeAmountTolerance);
        assertLt(assetsPaid, assetsReceived);
        curve.validateTrade(market, boughtShares, assetsPaid, true, parameters);
        curve.validateTrade(market, soldShares, assetsReceived, false, parameters);
    }

    function testQuoteFixedAssetsInBothDirections() public view {
        uint256 requestedAssets = 1_000e6;
        uint256 expectedSharesReceived = 1_040_278_271;
        uint256 expectedSharesPaid = 1_040_202_991;
        uint256 nativeAmountTolerance = 2;
        (uint256 sharesReceived, uint256 assetsPaid) = curve.quote(market, requestedAssets, false, true, parameters);
        (uint256 sharesPaid, uint256 assetsReceived) = curve.quote(market, requestedAssets, false, false, parameters);

        assertEq(assetsPaid, requestedAssets);
        assertEq(assetsReceived, requestedAssets);
        assertApproxEqAbs(sharesReceived, expectedSharesReceived, nativeAmountTolerance);
        assertApproxEqAbs(sharesPaid, expectedSharesPaid, nativeAmountTolerance);
        assertGt(sharesReceived, sharesPaid);
        curve.validateTrade(market, sharesReceived, assetsPaid, true, parameters);
        curve.validateTrade(market, sharesPaid, assetsReceived, false, parameters);
    }

    function testPriceConvergesToPayoutAtMaturityWhileReserveRateIsUnchanged() public {
        uint256 expectedAnnualRate = 0.08e18;
        uint256 expectedInitialPrice = 961_316_043_380_947_294;
        uint256 wadValueTolerance = 1e6;
        uint256 requestedShares = 1_000e6;
        uint256 expectedAssetsPaidAtMaturity = 999_999_999;
        uint256 expectedAssetsReceivedAtMaturity = 1_000e6;
        uint256 initialRate = curve.rate(market, parameters);
        assertApproxEqAbs(initialRate, expectedAnnualRate, wadValueTolerance);
        assertApproxEqAbs(curve.marginalPrice(market, parameters), expectedInitialPrice, wadValueTolerance);

        market.timeLeft = 0;
        assertEq(curve.marginalPrice(market, parameters), market.payout);
        assertEq(curve.rate(market, parameters), initialRate);
        (, uint256 assetsPaid) = curve.quote(market, requestedShares, true, true, parameters);
        (, uint256 assetsReceived) = curve.quote(market, requestedShares, true, false, parameters);
        assertEq(assetsPaid, expectedAssetsPaidAtMaturity);
        assertEq(assetsReceived, expectedAssetsReceivedAtMaturity);
    }

    function testValidateTradeEnforcesPostTradeRateFloor() public {
        uint64 annualRateSensitivity = 0.1e18;
        uint64 minimumAnnualRate = 0.079e18;
        uint256 sharesAboveRateFloor = 1_000e6;
        uint256 sharesBreachingRateFloor = 10_000e6;
        bytes memory floorParameters = YieldSpaceCurveConfig.encode(
            IYieldSpaceCurve.Parameters({ sensitivity: annualRateSensitivity, rateFloor: minimumAnnualRate, feeBps: 0 })
        );
        (uint256 smallShares, uint256 smallAssets) =
            curve.quote(market, sharesAboveRateFloor, true, false, floorParameters);
        curve.validateTrade(market, smallShares, smallAssets, false, floorParameters);

        (uint256 largeShares, uint256 largeAssets) =
            curve.quote(market, sharesBreachingRateFloor, true, false, floorParameters);
        vm.expectRevert(IYieldSpaceCurve.YieldSpaceCurve__RateFloor.selector);
        curve.validateTrade(market, largeShares, largeAssets, false, floorParameters);
    }

    function testQuoteRejectsExhaustingNoteReserve() public {
        uint256 sharesExhaustingReserve = market.noteBalance;
        vm.expectRevert(IYieldSpaceCurve.YieldSpaceCurve__InsufficientLiquidity.selector);
        curve.quote(market, sharesExhaustingReserve, true, false, parameters);
    }

    function testQuoteFixedSharesIncludesTradeFeeInBothDirections() public view {
        uint64 annualRateSensitivity = 0.1e18;
        uint16 tradeFeeBps = 50;
        uint256 requestedShares = 1_000e6;
        uint256 expectedAssetsPaid = 956_476_187;
        uint256 expectedAssetsReceived = 966_156_225;
        uint256 nativeAmountTolerance = 2;
        bytes memory feeParameters = YieldSpaceCurveConfig.encode(
            IYieldSpaceCurve.Parameters({ sensitivity: annualRateSensitivity, rateFloor: 0, feeBps: tradeFeeBps })
        );

        (uint256 boughtShares, uint256 assetsPaid) = curve.quote(market, requestedShares, true, true, feeParameters);
        (uint256 soldShares, uint256 assetsReceived) = curve.quote(market, requestedShares, true, false, feeParameters);

        assertEq(boughtShares, requestedShares);
        assertEq(soldShares, requestedShares);
        // Independent invariant evaluation with additive fee and numerical-margin factors.
        assertApproxEqAbs(assetsPaid, expectedAssetsPaid, nativeAmountTolerance);
        assertApproxEqAbs(assetsReceived, expectedAssetsReceived, nativeAmountTolerance);
        curve.validateTrade(market, boughtShares, assetsPaid, true, feeParameters);
        curve.validateTrade(market, soldShares, assetsReceived, false, feeParameters);
    }

    function testQuoteFixedAssetsIncludesTradeFeeInBothDirections() public view {
        uint64 annualRateSensitivity = 0.1e18;
        uint16 tradeFeeBps = 50;
        uint256 requestedAssets = 1_000e6;
        uint256 expectedSharesReceived = 1_045_505_990;
        uint256 expectedSharesPaid = 1_035_028_038;
        uint256 nativeAmountTolerance = 2;
        bytes memory feeParameters = YieldSpaceCurveConfig.encode(
            IYieldSpaceCurve.Parameters({ sensitivity: annualRateSensitivity, rateFloor: 0, feeBps: tradeFeeBps })
        );

        (uint256 sharesReceived, uint256 assetsPaid) = curve.quote(market, requestedAssets, false, true, feeParameters);
        (uint256 sharesPaid, uint256 assetsReceived) = curve.quote(market, requestedAssets, false, false, feeParameters);

        assertEq(assetsPaid, requestedAssets);
        assertEq(assetsReceived, requestedAssets);
        assertApproxEqAbs(sharesReceived, expectedSharesReceived, nativeAmountTolerance);
        assertApproxEqAbs(sharesPaid, expectedSharesPaid, nativeAmountTolerance);
        curve.validateTrade(market, sharesReceived, assetsPaid, true, feeParameters);
        curve.validateTrade(market, sharesPaid, assetsReceived, false, feeParameters);
    }

    function testQuoteRejectsAskFeeExceedingParOrPayout() public {
        uint64 annualRateSensitivity = 0.1e18;
        uint16 tradeFeeBps = 50;
        uint256 requestedShares = 1_000e6;
        uint256 fractionalPayoutPerShare = 0.9e18;
        bytes memory feeParameters = YieldSpaceCurveConfig.encode(
            IYieldSpaceCurve.Parameters({ sensitivity: annualRateSensitivity, rateFloor: 0, feeBps: tradeFeeBps })
        );
        market.timeLeft = 0;

        vm.expectRevert(IYieldSpaceCurve.YieldSpaceCurve__PriceAbovePar.selector);
        curve.quote(market, requestedShares, true, false, feeParameters);

        market.payout = fractionalPayoutPerShare;
        vm.expectRevert(IYieldSpaceCurve.YieldSpaceCurve__PriceAbovePar.selector);
        curve.quote(market, requestedShares, true, false, feeParameters);
    }
}
