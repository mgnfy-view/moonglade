// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

/// @title Moonglade swap instruction interface.
/// @author Sahil Gujrati (@mgnfy-view).
/// @notice Maker-selected pricing address and implementation-specific settings committed into an order.
interface IMoongladeSwap {
    /// @notice Swap instruction configuration with a forty-byte header and opaque parameter bytes.
    struct Config {
        /// @notice Note traded against its attached loan token, with matching decimals.
        address note;
        /// @notice Maker-selected contract implementing IMoongladeCurve.
        address curve;
        /// @notice Settings interpreted exclusively by the selected pricing implementation.
        bytes data;
    }

    /// @notice A required address is zero or the payload exceeds the instruction's one-byte length field.
    error MoongladeSwap__InvalidConfig();
}
