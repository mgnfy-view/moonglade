// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import { TickLib, MAX_TICK } from "midnight/src/libraries/TickLib.sol";

/// @title Midnight tick-grid conversions.
/// @author Sahil Gujrati (@mgnfy-view).
/// @notice Select valid native ticks with explicit rounding and plateau handling.
/// @dev Tick lookup delegates to Midnight; wrappers preserve directional bounds and equal-price tie rules.
library MidnightTicks {
    /// @notice Largest supported price, representing par.
    uint256 private constant WAD = 1e18;

    /// @notice Spacing is zero or exceeds Midnight's largest tick.
    /// @param _spacing Unsupported grid spacing.
    error MidnightTicks__InvalidSpacing(uint256 _spacing);
    /// @notice The requested price exceeds one WAD.
    /// @param _price Unsupported WAD price.
    error MidnightTicks__InvalidPrice(uint256 _price);
    /// @notice A tick is outside Midnight's range or off the selected grid.
    /// @param _tick Unsupported tick.
    /// @param _spacing Required grid spacing.
    error MidnightTicks__InvalidTick(uint256 _tick, uint256 _spacing);

    // ===== Internal functions =====

    /// @notice Require a tick on the selected nonempty Midnight grid.
    /// @param _tick Tick to validate.
    /// @param _spacing Market tick spacing, from one through MAX_TICK.
    function validate(uint256 _tick, uint256 _spacing) internal pure {
        _checkSpacing(_spacing);
        if (_tick > MAX_TICK || _tick % _spacing != 0) {
            revert MidnightTicks__InvalidTick(_tick, _spacing);
        }
    }

    /// @notice Select the smallest valid tick whose rounded native price is at least the requested price.
    /// @param _price Requested WAD price, at most par.
    /// @param _spacing Spacing from an initialized Midnight market: 1, 2, or 4.
    /// @return Smallest grid tick whose price is at least the requested price.
    function ceil(uint256 _price, uint256 _spacing) internal pure returns (uint256) {
        _checkSpacing(_spacing);
        if (_price > WAD) revert MidnightTicks__InvalidPrice(_price);

        return TickLib.priceToTick(_price, _spacing);
    }

    /// @notice Select the largest valid tick whose rounded native price is no greater than the requested price.
    /// @dev A zero-price tick is valid; callers separately decide whether zero-price execution is allowed.
    /// Ceiling of the next price atom finds the first strictly higher price, including after a plateau.
    /// @param _price Requested WAD price, at most par.
    /// @param _spacing Market tick spacing.
    /// @return Floor tick, including the last tick of any exact-price plateau.
    function floor(uint256 _price, uint256 _spacing) internal pure returns (uint256) {
        uint256 last = _lastIndex(_price, _spacing) * _spacing;
        if (TickLib.tickToPrice(last) <= _price) return last;

        // One price atom above the target skips all ticks on its equal-price plateau.
        uint256 upper = ceil(_price + 1, _spacing);

        return upper - _spacing;
    }

    /// @notice Select the closest rounded native price, choosing the lowest tick on a tie or price plateau.
    /// @dev At most two native lookups select the lowest grid tick at the chosen rounded price.
    /// @param _price Requested WAD price, at most par.
    /// @param _spacing Market tick spacing.
    /// @return Nearest valid tick, with all ties resolved downward.
    function nearest(uint256 _price, uint256 _spacing) internal pure returns (uint256) {
        uint256 last = _lastIndex(_price, _spacing) * _spacing;
        uint256 lastPrice = TickLib.tickToPrice(last);
        if (_price > lastPrice) return ceil(lastPrice, _spacing);

        uint256 upper = ceil(_price, _spacing);
        uint256 upperPrice = TickLib.tickToPrice(upper);
        if (upperPrice == _price) return upper;

        uint256 lowerPrice = TickLib.tickToPrice(upper - _spacing);
        if (upperPrice - _price < _price - lowerPrice) return upper;

        return ceil(lowerPrice, _spacing);
    }

    // ===== Private functions =====

    /// @notice Validate price and grid bounds and compute the final valid grid index.
    /// @param _price WAD price to validate.
    /// @param _spacing Selected market spacing.
    /// @return Largest integer index whose grid tick does not exceed MAX_TICK.
    function _lastIndex(uint256 _price, uint256 _spacing) private pure returns (uint256) {
        _checkSpacing(_spacing);
        if (_price > WAD) revert MidnightTicks__InvalidPrice(_price);

        return MAX_TICK / _spacing;
    }

    /// @notice Reject empty grids and spacing greater than the native tick domain.
    /// @param _spacing Selected market spacing.
    function _checkSpacing(uint256 _spacing) private pure {
        if (_spacing == 0 || _spacing > MAX_TICK) {
            revert MidnightTicks__InvalidSpacing(_spacing);
        }
    }
}
