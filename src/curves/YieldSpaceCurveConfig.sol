// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { IYieldSpaceCurve } from "src/curves/interfaces/IYieldSpaceCurve.sol";

/// @title YieldSpace curve parameter codec.
/// @author Sahil Gujrati (@mgnfy-view).
/// @notice Encode the default model's sensitivity and rate floor independently of generic routing.
library YieldSpaceCurveConfig {
    /// @notice Packed size of two uint64 parameters.
    uint8 internal constant ENCODED_LENGTH = 16;

    // ===== Internal functions =====

    /// @notice Encode positive sensitivity and the unsigned annual rate floor.
    /// @param _parameters Default pricing parameters; zero and above-100-percent rate floors are valid.
    /// @return Sixteen bytes of packed YieldSpace settings.
    function encode(IYieldSpaceCurve.Parameters memory _parameters) internal pure returns (bytes memory) {
        if (_parameters.sensitivity == 0) revert IYieldSpaceCurve.YieldSpaceCurve__InvalidParameters();

        return abi.encodePacked(_parameters.sensitivity, _parameters.rateFloor);
    }

    /// @notice Decode and validate the default model's exact parameter layout.
    /// @param _data Sixteen bytes containing sensitivity followed by the annual rate floor.
    /// @return Validated default pricing parameters.
    function decode(bytes calldata _data) internal pure returns (IYieldSpaceCurve.Parameters memory) {
        if (_data.length != ENCODED_LENGTH) revert IYieldSpaceCurve.YieldSpaceCurve__InvalidParameters();
        IYieldSpaceCurve.Parameters memory parameters =
            IYieldSpaceCurve.Parameters(uint64(bytes8(_data[0:8])), uint64(bytes8(_data[8:ENCODED_LENGTH])));
        if (parameters.sensitivity == 0) revert IYieldSpaceCurve.YieldSpaceCurve__InvalidParameters();

        return parameters;
    }
}
