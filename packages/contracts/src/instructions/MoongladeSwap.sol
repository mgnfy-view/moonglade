// SPDX-License-Identifier: MIT AND LicenseRef-Degensoft-SwapVM-1.1
pragma solidity 0.8.30;

import { IMidnight } from "midnight/src/interfaces/IMidnight.sol";

import { Math } from "@openzeppelin-contracts/utils/math/Math.sol";
import { TickLib } from "midnight/src/libraries/TickLib.sol";
import { Context } from "swap-vm/src/libs/VM.sol";

import { IMoongladeCurve } from "src/curves/interfaces/IMoongladeCurve.sol";
import { IMoongladeSwap } from "src/instructions/interfaces/IMoongladeSwap.sol";
import { IMoongladeNote } from "src/note/interfaces/IMoongladeNote.sol";
import { IMoongladeRouter } from "src/routers/interfaces/IMoongladeRouter.sol";

import { MidnightTicks } from "src/libraries/MidnightTicks.sol";

/// @title Moonglade's Morpho Midnight tick-aligned pricing instruction.
/// @author Sahil Gujrati (@mgnfy-view).
/// @notice Price with a maker-selected curve, snap to Midnight ticks, and compute final swap amounts.
/// @dev Model calls are static; this instruction changes only SwapVM memory and never transfers tokens.
library MoongladeSwap {
    /// @notice Fixed-point scale for share prices and payout factors.
    uint256 private constant WAD = 1e18;
    /// @notice Time before maturity when swaps and new desk configurations stop being accepted.
    uint256 internal constant MATURITY_BUFFER = 1 days;
    /// @notice Custom SwapVM opcode for pricing and native tick-aligned amount calculation.
    uint8 internal constant OPCODE = 0xd0;
    /// @notice Packed byte length of the note and pricing-contract addresses.
    uint8 internal constant HEADER_LENGTH = 40;
    /// @notice Maximum implementation-specific settings after the fixed address header.
    uint8 internal constant MAX_DATA_LENGTH = type(uint8).max - HEADER_LENGTH;

    // ===== Internal functions =====

    /// @notice Build the complete pricing instruction, including its opcode and bounded argument length.
    /// @param _config Note, pricing contract, and opaque settings committed into the maker order.
    /// @return Encoded pricing instruction.
    function build(IMoongladeSwap.Config memory _config) internal pure returns (bytes memory) {
        bytes memory args = MoongladeSwap.encode(_config);

        return abi.encodePacked(OPCODE, uint8(args.length), args);
    }

    /// @notice Compute final token amounts using the selected curve and maker-favored native tick rounding.
    /// @dev Reads market inputs once, obtains static native amount bounds, and validates the snapped amounts before
    /// populating the missing-amount register. No storage or transient state is written, preserving static quotes.
    /// @param _ctx SwapVM query, pre-trade reserves, and partially computed amounts.
    /// @param _data Common address header followed by model-specific settings.
    function exec(Context memory _ctx, bytes calldata _data) internal view {
        if (_ctx.query.isExactIn ? _ctx.swap.amountOut != 0 : _ctx.swap.amountIn != 0) {
            revert IMoongladeRouter.MoongladeRouter__Recompute();
        }

        IMoongladeSwap.Config memory c = MoongladeSwap.decode(_data);
        (IMoongladeCurve.MarketState memory market, bool buying) = _marketState(_ctx, c.note);
        bool sharesSpecified = buying == _ctx.query.isExactIn;
        uint256 amount = _ctx.query.isExactIn ? _ctx.swap.amountIn : _ctx.swap.amountOut;
        (uint256 shares, uint256 assets) =
            IMoongladeCurve(c.curve).quote(market, amount, sharesSpecified, buying, c.data);
        IMoongladeNote note = IMoongladeNote(c.note);
        uint256 spacing = IMidnight(note.midnight()).tickSpacing(note.marketId());
        IMoongladeRouter.Trade memory result = _snap(shares, assets, sharesSpecified, buying, spacing);
        _checkQuote(result, market, amount, sharesSpecified, buying);
        IMoongladeCurve(c.curve).validateTrade(market, result.shares, result.assets, buying, c.data);
        if (_ctx.query.isExactIn) _ctx.swap.amountOut = buying ? result.assets : result.shares;
        else _ctx.swap.amountIn = buying ? result.shares : result.assets;
    }

    /// @notice Validate the common configuration and pack the pricing instruction payload.
    /// @param _config Note, selected implementation, and implementation-specific settings.
    /// @return Packed header followed by unmodified curve settings.
    function encode(IMoongladeSwap.Config memory _config) internal pure returns (bytes memory) {
        MoongladeSwap.validate(_config);

        return abi.encodePacked(_config.note, _config.curve, _config.data);
    }

    /// @notice Decode a bounded pricing payload without interpreting implementation-specific settings.
    /// @param _data Packed address header and opaque curve settings.
    /// @return Common pricing configuration.
    function decode(bytes calldata _data) internal pure returns (IMoongladeSwap.Config memory) {
        if (_data.length < HEADER_LENGTH) {
            revert IMoongladeSwap.MoongladeSwap__InvalidConfig();
        }

        IMoongladeSwap.Config memory config;
        config.note = address(bytes20(_data[0:20]));
        config.curve = address(bytes20(_data[20:HEADER_LENGTH]));
        config.data = _data[HEADER_LENGTH:];
        MoongladeSwap.validate(config);

        return config;
    }

    /// @notice Reject missing addresses or settings too large for the instruction format.
    /// @dev The maker trusts its chosen pricing implementation to validate its opaque settings.
    /// @param _config Common pricing configuration.
    function validate(IMoongladeSwap.Config memory _config) internal pure {
        if (_config.note == address(0) || _config.curve == address(0) || _config.data.length > MAX_DATA_LENGTH) {
            revert IMoongladeSwap.MoongladeSwap__InvalidConfig();
        }
    }

    // ===== Private functions =====

    /// @notice Load authoritative market inputs independently of the chosen pricing model.
    /// @param _ctx SwapVM query and pre-trade virtual balances.
    /// @param _note Configured note address.
    /// @return Native reserves, note payout, and time remaining.
    /// @return Whether the maker receives notes and pays cash.
    function _marketState(Context memory _ctx, address _note)
        private
        view
        returns (IMoongladeCurve.MarketState memory, bool)
    {
        IMoongladeNote token = IMoongladeNote(_note);
        uint256 maturity = token.maturity();
        if (maturity <= MATURITY_BUFFER) revert IMoongladeRouter.MoongladeRouter__InvalidCurveMarket();
        if (block.timestamp >= maturity - MATURITY_BUFFER) revert IMoongladeRouter.MoongladeRouter__MarketClosed();
        address loan = address(token.loanToken());
        bool buying = _ctx.query.tokenIn == _note && _ctx.query.tokenOut == loan;
        if (!buying && !(_ctx.query.tokenIn == loan && _ctx.query.tokenOut == _note)) {
            revert IMoongladeRouter.MoongladeRouter__InvalidPair();
        }

        IMoongladeCurve.MarketState memory market = IMoongladeCurve.MarketState({
            note: _note,
            cashBalance: buying ? _ctx.swap.balanceOut : _ctx.swap.balanceIn,
            noteBalance: buying ? _ctx.swap.balanceIn : _ctx.swap.balanceOut,
            timeLeft: maturity - block.timestamp,
            payout: token.totalSupply() == 0 ? WAD : token.payoutPerShare()
        });

        return (market, buying);
    }

    /// @notice Validate a custom quote independently of the selected pricing model.
    /// @dev Snapping guarantees the grid and native amount relationship. Enforce the exact specified amount,
    /// positive cash, the note's payout cap, and available virtual output reserves.
    /// @param _quote Proposed final native amounts and execution tick.
    /// @param _market Authoritative market inputs used for this quote.
    /// @param _amount Taker-specified native quantity.
    /// @param _sharesSpecified Whether that exact quantity is shares.
    /// @param _deskBuying Whether the maker receives shares and pays cash.
    function _checkQuote(
        IMoongladeRouter.Trade memory _quote,
        IMoongladeCurve.MarketState memory _market,
        uint256 _amount,
        bool _sharesSpecified,
        bool _deskBuying
    ) private pure {
        if (_quote.assets == 0 || (_sharesSpecified ? _quote.shares : _quote.assets) != _amount) {
            revert IMoongladeRouter.MoongladeRouter__InvalidQuote();
        }
        if (_quote.assets > Math.mulDiv(_quote.shares, _market.payout, WAD)) {
            revert IMoongladeRouter.MoongladeRouter__InvalidQuote();
        }
        if (_deskBuying ? _quote.assets >= _market.cashBalance : _quote.shares >= _market.noteBalance) {
            revert IMoongladeRouter.MoongladeRouter__InsufficientLiquidity();
        }
    }

    /// @notice Select the maker-favored Midnight tick for an execution price.
    /// @dev Midnight enforces the price range; a zero-price tick cannot execute a positive trade.
    /// @param _price WAD price derived from the model's native amount bounds.
    /// @param _deskBuying Whether the maker pays cash, requiring a downward tick.
    /// @param _spacing Market's actual native tick spacing.
    /// @return Valid native tick.
    /// @return Its positive WAD price.
    function _snapPrice(uint256 _price, bool _deskBuying, uint256 _spacing) private pure returns (uint256, uint256) {
        uint256 tick = _deskBuying ? MidnightTicks.floor(_price, _spacing) : MidnightTicks.ceil(_price, _spacing);
        uint256 price = TickLib.tickToPrice(tick);
        if (price == 0) revert IMoongladeRouter.MoongladeRouter__InvalidQuote();

        return (tick, price);
    }

    /// @notice Snap once; directional rounding preserves the curve's conservative native bounds.
    /// @param _shares Native share bound, or exact specified shares.
    /// @param _assets Native cash bound, or exact specified cash.
    /// @param _sharesSpecified Whether the exact quantity is shares.
    /// @param _deskBuying Whether the maker receives shares and pays cash.
    /// @param _spacing Actual native tick spacing.
    /// @return Final native quantities and their execution tick.
    function _snap(uint256 _shares, uint256 _assets, bool _sharesSpecified, bool _deskBuying, uint256 _spacing)
        private
        pure
        returns (IMoongladeRouter.Trade memory)
    {
        if (_shares == 0) revert IMoongladeRouter.MoongladeRouter__InvalidQuote();
        Math.Rounding cashRounding = _deskBuying ? Math.Rounding.Floor : Math.Rounding.Ceil;
        uint256 quotedPrice = Math.mulDiv(_assets, WAD, _shares, cashRounding);
        IMoongladeRouter.Trade memory result;
        uint256 price;
        (result.tick, price) = _snapPrice(quotedPrice, _deskBuying, _spacing);
        if (_sharesSpecified) {
            result.shares = _shares;
            result.assets = Math.mulDiv(_shares, price, WAD, cashRounding);
        } else {
            result.assets = _assets;
            result.shares = Math.mulDiv(_assets, WAD, price, _deskBuying ? Math.Rounding.Ceil : Math.Rounding.Floor);
        }

        return result;
    }
}
