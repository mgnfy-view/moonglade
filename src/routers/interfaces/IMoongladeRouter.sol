// SPDX-License-Identifier: MIT AND LicenseRef-Degensoft-SwapVM-1.1
pragma solidity 0.8.30;

/// @title Moonglade router interface.
/// @author Sahil Gujrati (@mgnfy-view).
/// @notice Moonglade-specific failures and getters for the SwapVM router.
/// @dev SwapVM's inherited interfaces define its standard router integration surface.
interface IMoongladeRouter {
    /// @notice Final native quantities and their selected Midnight tick, internal to protocol snapping.
    struct Trade {
        /// @notice Native note shares exchanged.
        uint256 shares;
        /// @notice Native loan-token amount exchanged.
        uint256 assets;
        /// @notice Aligned Midnight execution tick.
        uint256 tick;
    }

    /// @notice The instruction opcode is not implemented.
    error MoongladeRouter__UnknownOpcode();
    /// @notice The trade does not exchange the configured note and its loan token.
    error MoongladeRouter__InvalidPair();
    /// @notice The note maturity cannot represent a valid trading market.
    error MoongladeRouter__InvalidCurveMarket();
    /// @notice A prior instruction already populated the amount this instruction must compute.
    error MoongladeRouter__Recompute();
    /// @notice The market has entered its final day before maturity.
    error MoongladeRouter__MarketClosed();
    /// @notice The resulting output exceeds the available pre-trade reserve.
    error MoongladeRouter__InsufficientLiquidity();
    /// @notice A curve returned an invalid price or snapping cannot produce conservative native amounts.
    error MoongladeRouter__InvalidQuote();

    // ===== Views =====

    function MOONGLADE_SWAP_OPCODE() external view returns (uint256);
}
