// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

/// @title Moonglade pricing interface.
/// @author Sahil Gujrati (@mgnfy-view).
/// @notice Maker-selected curves return conservative native amount bounds before tick snapping.
/// @dev Calls are static. Note shares adopt loan-token decimals; prices, rates, and payout factors use WAD.
interface IMoongladeCurve {
    /// @notice Live market inputs supplied by the router or desk hook, independent of the pricing model.
    struct MarketState {
        /// @notice Note whose shares adopt its loan token's precision.
        address note;
        /// @notice Pre-trade virtual loan-token reserve in native units.
        uint256 cashBalance;
        /// @notice Pre-trade virtual note reserve in native units.
        uint256 noteBalance;
        /// @notice Seconds until maturity, clamped to zero for maintenance after maturity.
        uint256 timeLeft;
        /// @notice Net loan-token face value per share, scaled by WAD; WAD for empty supply.
        uint256 payout;
    }

    // ===== User actions =====

    function quote(
        MarketState calldata _market,
        uint256 _amount,
        bool _sharesSpecified,
        bool _deskBuying,
        bytes calldata _data
    ) external view returns (uint256, uint256);

    function validateTrade(
        MarketState calldata _market,
        uint256 _shares,
        uint256 _assets,
        bool _deskBuying,
        bytes calldata _data
    ) external view;

    // ===== Views =====

    function marginalPrice(MarketState calldata _market, bytes calldata _data) external view returns (uint256);

    function rate(MarketState calldata _market, bytes calldata _data) external view returns (uint256);
}
