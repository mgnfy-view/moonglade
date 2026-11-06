// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { Test } from "forge-std/Test.sol";

import { IYieldSpaceCurve } from "src/curves/interfaces/IYieldSpaceCurve.sol";

import { YieldSpaceCurveConfig } from "src/curves/YieldSpaceCurveConfig.sol";

contract YieldSpaceCurveConfigTest is Test {
    YieldSpaceCurveConfigHarness private configHarness;

    function setUp() public {
        configHarness = new YieldSpaceCurveConfigHarness();
    }

    function testParametersRoundTripWithTradeFee() public view {
        uint64 annualRateSensitivity = 0.1e18;
        uint64 minimumAnnualRate = 0.079e18;
        uint16 maximumValidFeeBps = 9_999;
        uint256 expectedEncodedLength = 18;
        IYieldSpaceCurve.Parameters memory originalParameters = IYieldSpaceCurve.Parameters({
            sensitivity: annualRateSensitivity, rateFloor: minimumAnnualRate, feeBps: maximumValidFeeBps
        });

        bytes memory encodedParameters = configHarness.encode(originalParameters);
        IYieldSpaceCurve.Parameters memory decodedParameters = configHarness.decode(encodedParameters);

        assertEq(encodedParameters.length, expectedEncodedLength);
        assertEq(encodedParameters, abi.encodePacked(annualRateSensitivity, minimumAnnualRate, maximumValidFeeBps));
        assertEq(decodedParameters.sensitivity, annualRateSensitivity);
        assertEq(decodedParameters.rateFloor, minimumAnnualRate);
        assertEq(decodedParameters.feeBps, maximumValidFeeBps);
    }

    function testParametersRejectInvalidFeeAndLegacyPayload() public {
        uint64 annualRateSensitivity = 0.1e18;
        uint64 minimumAnnualRate = 0.079e18;
        uint16 invalidFeeBps = 10_000;
        IYieldSpaceCurve.Parameters memory invalidParameters = IYieldSpaceCurve.Parameters({
            sensitivity: annualRateSensitivity, rateFloor: minimumAnnualRate, feeBps: invalidFeeBps
        });
        bytes memory invalidFeePayload = abi.encodePacked(annualRateSensitivity, minimumAnnualRate, invalidFeeBps);
        bytes memory legacyPayload = abi.encodePacked(annualRateSensitivity, minimumAnnualRate);

        vm.expectRevert(IYieldSpaceCurve.YieldSpaceCurve__InvalidParameters.selector);
        configHarness.encode(invalidParameters);

        vm.expectRevert(IYieldSpaceCurve.YieldSpaceCurve__InvalidParameters.selector);
        configHarness.decode(invalidFeePayload);

        vm.expectRevert(IYieldSpaceCurve.YieldSpaceCurve__InvalidParameters.selector);
        configHarness.decode(legacyPayload);
    }

    function testParametersRejectZeroSensitivity() public {
        uint64 zeroSensitivity = 0;
        uint64 minimumAnnualRate = 0;
        uint16 tradeFeeBps = 30;
        IYieldSpaceCurve.Parameters memory invalidParameters = IYieldSpaceCurve.Parameters({
            sensitivity: zeroSensitivity, rateFloor: minimumAnnualRate, feeBps: tradeFeeBps
        });
        bytes memory invalidPayload = abi.encodePacked(zeroSensitivity, minimumAnnualRate, tradeFeeBps);

        vm.expectRevert(IYieldSpaceCurve.YieldSpaceCurve__InvalidParameters.selector);
        configHarness.encode(invalidParameters);

        vm.expectRevert(IYieldSpaceCurve.YieldSpaceCurve__InvalidParameters.selector);
        configHarness.decode(invalidPayload);
    }
}

contract YieldSpaceCurveConfigHarness {
    function encode(IYieldSpaceCurve.Parameters memory _parameters) external pure returns (bytes memory) {
        return YieldSpaceCurveConfig.encode(_parameters);
    }

    function decode(bytes calldata _data) external pure returns (IYieldSpaceCurve.Parameters memory) {
        return YieldSpaceCurveConfig.decode(_data);
    }
}
