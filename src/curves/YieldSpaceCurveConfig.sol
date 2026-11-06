// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { IYieldSpaceCurve } from "src/curves/interfaces/IYieldSpaceCurve.sol";

/// @title YieldSpace curve parameter codec.
/// @author Sahil Gujrati (@mgnfy-view).
/// @notice Encode the maker's sensitivity, rate floor, and bid/ask fee independently of generic routing.
/// @dev The eighteen-byte layout packs two uint64 values and a uint16 fee in basis points.
library YieldSpaceCurveConfig {
    /// @notice Packed size of two uint64 parameters followed by a uint16 fee.
    uint8 internal constant ENCODED_LENGTH = 18;
    /// @notice Basis-point denominator; the maker's fee must be strictly below this value.
    uint16 internal constant BPS = 10_000;

    // ===== Internal functions =====

    /// @notice Encode positive sensitivity, an unsigned annual rate floor, and a maker-selected fee below 100%.
    /// @param _parameters Maker's pricing settings; zero and above-100-percent rate floors are valid.
    /// @return Eighteen bytes of packed YieldSpace settings.
    function encode(IYieldSpaceCurve.Parameters memory _parameters) internal pure returns (bytes memory) {
        if (_parameters.sensitivity == 0 || _parameters.feeBps >= BPS) {
            revert IYieldSpaceCurve.YieldSpaceCurve__InvalidParameters();
        }

        return abi.encodePacked(_parameters.sensitivity, _parameters.rateFloor, _parameters.feeBps);
    }

    /// @notice Decode and validate the default model's exact parameter layout.
    /// @param _data Eighteen bytes containing sensitivity, annual rate floor, and fee basis points.
    /// @return Validated default pricing parameters.
    function decode(bytes calldata _data) internal pure returns (IYieldSpaceCurve.Parameters memory) {
        if (_data.length != ENCODED_LENGTH) revert IYieldSpaceCurve.YieldSpaceCurve__InvalidParameters();
        IYieldSpaceCurve.Parameters memory parameters = IYieldSpaceCurve.Parameters(
            uint64(bytes8(_data[0:8])), uint64(bytes8(_data[8:16])), uint16(bytes2(_data[16:ENCODED_LENGTH]))
        );
        if (parameters.sensitivity == 0 || parameters.feeBps >= BPS) {
            revert IYieldSpaceCurve.YieldSpaceCurve__InvalidParameters();
        }

        return parameters;
    }
}
