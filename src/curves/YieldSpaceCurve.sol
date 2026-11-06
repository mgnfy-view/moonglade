// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { IERC20Metadata } from "@openzeppelin-contracts/token/ERC20/extensions/IERC20Metadata.sol";

import { Math } from "@openzeppelin-contracts/utils/math/Math.sol";
import "prb-math/src/UD60x18.sol" as PRBMath;

import { IYieldSpaceCurve } from "src/curves/interfaces/IYieldSpaceCurve.sol";

import { YieldSpaceCurveConfig } from "src/curves/YieldSpaceCurveConfig.sol";

/// @title Sample YieldSpace pricing curve.
/// @author Sahil Gujrati (@mgnfy-view).
/// @notice Price net credit shares with x^a+y^a and a fixed maker-favored margin.
/// @dev Original formulas using PRB-Math; the margin is empirical, not certified numerical bounds.
contract YieldSpaceCurve is IYieldSpaceCurve {
    /// @notice Fixed-point scale for prices, powers, rates and payout.
    uint256 private constant WAD = 1e18;
    /// @notice Relative price margin of one part per billion.
    uint256 private constant MARGIN = 1e9;
    /// @notice Nonlinear solver legs must exceed one ppm of the larger reserve, divided by the WAD exponent.
    /// @dev Operating resolution policy with headroom for normalization; not a certified PRB-Math error bound.
    uint256 private constant MIN_RESOLVED_FRACTION = 1e12;
    /// @notice Seconds in the annualization period.
    uint256 private constant YEAR = 365 days;
    /// @notice Maximum note precision supported by WAD normalization.
    uint8 private constant MAX_TOKEN_DECIMALS = 18;

    /// @notice Quote a native cash or share quantity using packed sensitivity and rate-floor settings.
    /// @dev Apply the margin in WAD cash before native rounding. For fixed cash, adjust the solver's cash
    /// budget or target first, so its share result already includes the margin. Tick rounding belongs to the opcode.
    /// Fixed-cash quotes revert if the resulting share bound cannot satisfy the payout/par cap.
    /// Nonlinear quotes reject either solver leg below the reserve- and exponent-scaled resolution threshold.
    /// @return shares Native share bound, or the exact specified shares.
    /// @return assets Native cash bound, or the exact specified cash.
    function quote(
        MarketState calldata _market,
        uint256 _amount,
        bool _sharesSpecified,
        bool _deskBuying,
        bytes calldata _data
    ) external view returns (uint256 shares, uint256 assets) {
        Parameters memory parameters = YieldSpaceCurveConfig.decode(_data);
        (uint256 reserveIn, uint256 reserveOut, uint256 scale) = _reserves(_market);
        if (_deskBuying) (reserveIn, reserveOut) = (reserveOut, reserveIn);
        uint256 a = _exponent(parameters.sensitivity, _market.timeLeft);
        // Shares are input when the desk buys and output when it sells.
        bool exactIn = _sharesSpecified == _deskBuying;
        Math.Rounding rounding = _deskBuying ? Math.Rounding.Floor : Math.Rounding.Ceil;
        uint256 factor = _deskBuying ? WAD - MARGIN : WAD + MARGIN;
        uint256 amountWad = _sharesSpecified
            ? Math.mulDiv(_amount, _market.payout, WAD / scale, rounding)
            : Math.mulDiv(_amount * scale, WAD, factor, _deskBuying ? Math.Rounding.Ceil : Math.Rounding.Floor);
        uint256 result = _solve(amountWad, reserveIn, reserveOut, a, exactIn);
        uint256 cap = Math.min(_market.payout, WAD);
        if (_sharesSpecified) {
            shares = _amount;
            uint256 maxAssets = Math.mulDiv(shares, cap, WAD);
            if (Math.mulDiv(result, 1, scale, rounding) > maxAssets) revert YieldSpaceCurve__PriceAbovePar();
            assets = Math.min(Math.mulDiv(Math.mulDiv(result, factor, WAD, rounding), 1, scale, rounding), maxAssets);
        } else {
            shares = Math.mulDiv(
                result, WAD / scale, _market.payout, _deskBuying ? Math.Rounding.Ceil : Math.Rounding.Floor
            );
            assets = _amount;
            if (assets > Math.mulDiv(shares, cap, WAD)) revert YieldSpaceCurve__PriceAbovePar();
        }
        if (assets == 0) revert YieldSpaceCurve__ZeroAmount();
    }

    /// @notice Enforce positive final quantities, output reserves, post-trade face >= cash, and the rate floor.
    /// @dev Uses actual snapped transfers and the same packed model parameters; no funds or state are changed.
    function validateTrade(
        MarketState calldata _market,
        uint256 _shares,
        uint256 _assets,
        bool _deskBuying,
        bytes calldata _data
    ) external view {
        Parameters memory parameters = YieldSpaceCurveConfig.decode(_data);
        if (_shares == 0 || _assets == 0) revert YieldSpaceCurve__ZeroAmount();
        MarketState memory afterMarket = _market;
        afterMarket.cashBalance = _deskBuying ? _market.cashBalance - _assets : _market.cashBalance + _assets;
        afterMarket.noteBalance = _deskBuying ? _market.noteBalance + _shares : _market.noteBalance - _shares;
        (uint256 x, uint256 y,) = _reserves(afterMarket);
        if (_rate(parameters.sensitivity, x, y) < parameters.rateFloor) revert YieldSpaceCurve__RateFloor();
    }

    /// @notice Return the current WAD marginal price from live reserves and packed sensitivity.
    /// @dev At maturity the price equals payout; this view has no spread margin.
    /// @return WAD loan tokens per share.
    function marginalPrice(MarketState calldata _market, bytes calldata _data) external view returns (uint256) {
        Parameters memory parameters = YieldSpaceCurveConfig.decode(_data);
        (uint256 x, uint256 y,) = _reserves(_market);
        uint256 a = _exponent(parameters.sensitivity, _market.timeLeft);

        return Math.mulDiv(_power(Math.mulDiv(x, WAD, y), WAD - a), _market.payout, WAD);
    }

    /// @notice Read the reserve-implied continuous annual rate using packed sensitivity.
    /// @return WAD annual rate; the rate-floor setting is enforced only by validateTrade.
    function rate(MarketState calldata _market, bytes calldata _data) external view returns (uint256) {
        Parameters memory parameters = YieldSpaceCurveConfig.decode(_data);
        (uint256 x, uint256 y,) = _reserves(_market);

        return _rate(parameters.sensitivity, x, y);
    }

    /// @notice Normalize matching-decimal reserves to WAD cash and net face value.
    /// @dev Assumes a trusted note with at most eighteen decimals; scaling uses checked arithmetic.
    /// @return Positive cash reserve, face reserve at least cash, and the native-to-WAD scale.
    function _reserves(MarketState memory _market) private view returns (uint256, uint256, uint256) {
        uint8 decimals = IERC20Metadata(_market.note).decimals();
        uint256 scale = 10 ** (MAX_TOKEN_DECIMALS - decimals);
        uint256 x = _market.cashBalance * scale;
        uint256 y = Math.mulDiv(_market.noteBalance, _market.payout, WAD / scale);
        if (x == 0 || y < x) revert YieldSpaceCurve__InvalidReserves();

        return (x, y, scale);
    }

    /// @notice Compute the positive annualized invariant exponent from sensitivity and seconds remaining.
    /// @return WAD power exponent.
    function _exponent(uint256 _sensitivity, uint256 _timeLeft) private pure returns (uint256) {
        uint256 elapsed = Math.mulDiv(_sensitivity, _timeLeft, YEAR);
        if (elapsed >= WAD) revert YieldSpaceCurve__InvalidExponent();

        return WAD - elapsed;
    }

    /// @dev Solve x^a + y^a normalized by input reserve; a == WAD gives constant-sum pricing.
    /// @return Raw WAD amount before margin and native rounding; quote() rejects zero native results.
    function _solve(uint256 _amount, uint256 _x, uint256 _y, uint256 _a, bool _exactIn)
        internal
        pure
        returns (uint256)
    {
        if (_amount == 0) revert YieldSpaceCurve__ZeroAmount();
        // Constant-sum trades exchange normalized cash and face value exactly, without reserve cancellation.
        if (_a == WAD) {
            if (_amount >= _y) revert YieldSpaceCurve__InsufficientLiquidity();
            return _amount;
        }
        if (!_exactIn && _amount >= _y) revert YieldSpaceCurve__InsufficientLiquidity();
        // Small exponents amplify normalization error through the inverse power; bound both trade legs.
        uint256 minimumResolved = Math.mulDiv(Math.max(_x, _y), MIN_RESOLVED_FRACTION, _a, Math.Rounding.Ceil);
        if (_amount < minimumResolved) revert YieldSpaceCurve__InsufficientPrecision();
        uint256 invariant = WAD + _power(Math.mulDiv(_y, WAD, _x), _a);
        uint256 changed = _exactIn ? _x + _amount : _y - _amount;
        uint256 term = _power(Math.mulDiv(changed, WAD, _x), _a);
        uint256 remaining = Math.mulDiv(_power(invariant - term, WAD * WAD / _a), _x, WAD);
        if (_exactIn && remaining == 0) revert YieldSpaceCurve__InsufficientLiquidity();

        uint256 result = _exactIn ? _y - remaining : remaining - _x;
        if (result < minimumResolved) revert YieldSpaceCurve__InsufficientPrecision();
        return result;
    }

    /// @notice Evaluate a WAD power; PRB-Math v4.1 natively handles bases below WAD.
    /// @return WAD power result.
    function _power(uint256 _base, uint256 _exponentValue) private pure returns (uint256) {
        return PRBMath.unwrap(PRBMath.pow(PRBMath.ud(_base), PRBMath.ud(_exponentValue)));
    }

    /// @notice Compute sensitivity * ln(face/cash) for validated positive reserves.
    /// @return WAD continuous annual rate.
    function _rate(uint256 _sensitivity, uint256 _x, uint256 _y) private pure returns (uint256) {
        return Math.mulDiv(_sensitivity, PRBMath.unwrap(PRBMath.ln(PRBMath.ud(Math.mulDiv(_y, WAD, _x)))), WAD);
    }
}
