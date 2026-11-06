// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { IMoongladeCurve } from "src/curves/interfaces/IMoongladeCurve.sol";

/// @title YieldSpace curve interface.
/// @author Sahil Gujrati (@mgnfy-view).
/// @notice Parameters and validation failures for the YieldSpace pricing curve.
/// @dev Extends the shared pricing interface with model-specific settings and errors.
interface IYieldSpaceCurve is IMoongladeCurve {
    /// @notice Default curve parameters, encoded independently of the generic market configuration.
    struct Parameters {
        /// @notice Positive annualized sensitivity of rate to reserve imbalance, scaled by WAD.
        uint64 sensitivity;
        /// @notice Minimum post-trade annual rate, scaled by WAD; zero and rates above 100% are valid.
        uint64 rateFloor;
    }

    /// @notice Parameters are not exactly sixteen bytes or sensitivity is zero.
    error YieldSpaceCurve__InvalidParameters();
    /// @notice The input or resulting trade has a zero quantity.
    error YieldSpaceCurve__ZeroAmount();
    /// @notice The note's face-value payout factor is zero.
    error YieldSpaceCurve__InvalidPayout();
    /// @notice Cash reserves are empty or note face value is less than cash.
    error YieldSpaceCurve__InvalidReserves();
    /// @notice Annualized sensitivity leaves a zero or negative invariant exponent.
    error YieldSpaceCurve__InvalidExponent();
    /// @notice The trade would exhaust or exceed available reserves.
    error YieldSpaceCurve__InsufficientLiquidity();
    /// @notice A nonlinear solver leg is too small relative to reserves and its inverse-exponent amplification.
    error YieldSpaceCurve__InsufficientPrecision();
    /// @notice The trade would breach the configured minimum annual discount rate.
    error YieldSpaceCurve__RateFloor();
    /// @notice The required native cash exceeds share par or its current face value.
    error YieldSpaceCurve__PriceAbovePar();
}
