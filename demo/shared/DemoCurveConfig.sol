// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { IYieldSpaceCurve } from "src/curves/interfaces/IYieldSpaceCurve.sol";

import { YieldSpaceCurveConfig } from "src/curves/YieldSpaceCurveConfig.sol";

/// @title Moonglade demo curve-settings decoder.
/// @author Sahil Gujrati (@mgnfy-view).
/// @notice Decode committed pricing settings for the local demo's fee display.
/// @dev Provides a calldata boundary for the canonical codec without calling an ephemeral script address.
contract DemoCurveConfig {
    /// @notice Decode the selected desk's packed curve parameters.
    /// @param _data Settings copied from the desk's committed configuration.
    /// @return Maker-selected curve parameters.
    function decode(bytes calldata _data) external pure returns (IYieldSpaceCurve.Parameters memory) {
        return YieldSpaceCurveConfig.decode(_data);
    }
}
