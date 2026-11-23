// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import { TickLib, MAX_TICK } from "midnight/src/libraries/TickLib.sol";

/// @title Midnight tick-grid conversions.
/// @author Sahil Gujrati (@mgnfy-view).
/// @notice Select valid native ticks with explicit rounding and plateau handling.
/// @dev Tick lookup delegates to Midnight; wrappers preserve directional bounds and equal-price tie rules.
/// Every spacing argument must come from an initialized Midnight market: 1, 2, or 4.
library MidnightTicks {
    /// @notice Largest supported price, representing par.
    uint256 private constant WAD = 1e18;

    /// @notice A tick is outside Midnight's range or off the selected grid.
    /// @param _tick Unsupported tick.
    /// @param _spacing Required grid spacing.
    error MidnightTicks__InvalidTick(uint256 _tick, uint256 _spacing);

    // ===== Internal functions =====

    /// @notice Require a tick on the selected nonempty Midnight grid.
    /// @param _tick Tick to validate.
    /// @param _spacing Spacing of an initialized Midnight market.
    function validate(uint256 _tick, uint256 _spacing) internal pure {
        if (_tick > MAX_TICK || _tick % _spacing != 0) {
            revert MidnightTicks__InvalidTick(_tick, _spacing);
        }
    }

    /// @notice Select the smallest valid tick whose rounded native price is at least the requested price.
    /// @param _price Requested WAD price, at most par.
    /// @param _spacing Spacing of an initialized Midnight market.
    /// @return Smallest grid tick whose price is at least the requested price.
    function ceil(uint256 _price, uint256 _spacing) internal pure returns (uint256) {
        return TickLib.priceToTick(_price, _spacing);
    }

    /// @notice Select the largest valid tick whose rounded native price is no greater than the requested price.
    /// @dev A zero-price tick is valid; callers separately decide whether zero-price execution is allowed.
    /// Ceiling of the next price atom finds the first strictly higher price, including after a plateau.
    /// @param _price Requested WAD price, at most par.
    /// @param _spacing Spacing of an initialized Midnight market.
    /// @return Floor tick, including the last tick of any exact-price plateau.
    function floor(uint256 _price, uint256 _spacing) internal pure returns (uint256) {
        if (_price == WAD) return MAX_TICK;

        // One price atom above the target skips all ticks on its equal-price plateau.
        uint256 upper = MidnightTicks.ceil(_price + 1, _spacing);

        return upper - _spacing;
    }

    /// @notice Select the closest rounded native price, choosing the lowest tick on a tie or price plateau.
    /// @dev At most two native lookups select the lowest grid tick at the chosen rounded price.
    /// @param _price Requested WAD price, at most par.
    /// @param _spacing Spacing of an initialized Midnight market.
    /// @return Nearest valid tick, with all ties resolved downward.
    function nearest(uint256 _price, uint256 _spacing) internal pure returns (uint256) {
        uint256 upper = MidnightTicks.ceil(_price, _spacing);
        uint256 upperPrice = TickLib.tickToPrice(upper);
        if (upperPrice == _price) return upper;

        uint256 lowerPrice = TickLib.tickToPrice(upper - _spacing);
        if (upperPrice - _price < _price - lowerPrice) return upper;
        return MidnightTicks.ceil(lowerPrice, _spacing);
    }
}
