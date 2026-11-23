// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { IMidnight } from "midnight/src/interfaces/IMidnight.sol";

import { Test } from "forge-std/Test.sol";
import { Context } from "swap-vm/src/libs/VM.sol";

import { IMoongladeCurve } from "src/curves/interfaces/IMoongladeCurve.sol";
import { IMoongladeNote } from "src/note/interfaces/IMoongladeNote.sol";
import { IMoongladeRouter } from "src/routers/interfaces/IMoongladeRouter.sol";

import { MoongladeSwap } from "src/instructions/MoongladeSwap.sol";

contract MoongladeSwapTest is Test {
    address private constant NOTE = address(0x1001);
    address private constant LOAN_TOKEN = address(0x1002);
    address private constant CURVE = address(0x1003);
    address private constant MIDNIGHT = address(0x1004);
    bytes32 private constant MARKET_ID = keccak256("market");

    MoongladeSwapHarness private harness;

    function setUp() public {
        uint256 currentTime = 1_700_000_000;
        uint256 timeUntilMaturity = 30 days;
        uint256 maturity = currentTime + timeUntilMaturity;
        uint256 noteSupply = 1e6;
        uint256 payoutPerShare = 1e18;
        uint8 tickSpacing = 4;
        uint256 quotedShares = 100e6;
        uint256 quotedAssets = 96e6;

        harness = new MoongladeSwapHarness();
        vm.warp(currentTime);
        vm.mockCall(NOTE, abi.encodeWithSelector(IMoongladeNote.maturity.selector), abi.encode(maturity));
        vm.mockCall(NOTE, abi.encodeWithSelector(IMoongladeNote.loanToken.selector), abi.encode(LOAN_TOKEN));
        vm.mockCall(NOTE, abi.encodeWithSignature("totalSupply()"), abi.encode(noteSupply));
        vm.mockCall(NOTE, abi.encodeWithSelector(IMoongladeNote.payoutPerShare.selector), abi.encode(payoutPerShare));
        vm.mockCall(NOTE, abi.encodeWithSelector(IMoongladeNote.midnight.selector), abi.encode(MIDNIGHT));
        vm.mockCall(NOTE, abi.encodeWithSelector(IMoongladeNote.marketId.selector), abi.encode(MARKET_ID));
        vm.mockCall(MIDNIGHT, abi.encodeCall(IMidnight.tickSpacing, (MARKET_ID)), abi.encode(tickSpacing));
        // A custom curve deliberately quotes between ticks so the instruction must favor the maker.
        vm.etch(CURVE, hex"00");
        vm.mockCall(
            CURVE, abi.encodeWithSelector(IMoongladeCurve.quote.selector), abi.encode(quotedShares, quotedAssets)
        );
        vm.mockCall(CURVE, abi.encodeWithSelector(IMoongladeCurve.validateTrade.selector), bytes(""));
    }

    function test_ExactInNotesSnapCashDownForBuyingMaker() public {
        uint256 sharesIn = 100e6;
        uint256 quotedAssets = 96e6;
        uint256 expectedAssetsOut = 95_975_470;

        vm.expectCall(
            CURVE,
            abi.encodeCall(IMoongladeCurve.validateTrade, (_market(), sharesIn, expectedAssetsOut, true, bytes("")))
        );

        (uint256 amountIn, uint256 amountOut) =
            harness.exec(NOTE, LOAN_TOKEN, true, true, sharesIn, abi.encodePacked(NOTE, CURVE));

        assertEq(amountIn, sharesIn);
        assertEq(amountOut, expectedAssetsOut);
        assertLt(amountOut, quotedAssets);
    }

    function test_ExactOutNotesSnapCashUpForSellingMaker() public {
        uint256 sharesOut = 100e6;
        uint256 quotedAssets = 96e6;
        uint256 expectedAssetsIn = 96_052_210;

        vm.expectCall(
            CURVE,
            abi.encodeCall(IMoongladeCurve.validateTrade, (_market(), sharesOut, expectedAssetsIn, false, bytes("")))
        );

        (uint256 amountIn, uint256 amountOut) =
            harness.exec(NOTE, LOAN_TOKEN, false, false, sharesOut, abi.encodePacked(NOTE, CURVE));

        assertEq(amountIn, expectedAssetsIn);
        assertEq(amountOut, sharesOut);
        assertGt(amountIn, quotedAssets);
    }

    function test_RejectsCustomQuoteAboveNotePayout() public {
        uint256 payoutPerShare = 0.9e18;
        uint256 sharesIn = 100e6;
        vm.mockCall(NOTE, abi.encodeWithSelector(IMoongladeNote.payoutPerShare.selector), abi.encode(payoutPerShare));

        vm.expectRevert(IMoongladeRouter.MoongladeRouter__InvalidQuote.selector);
        harness.exec(NOTE, LOAN_TOKEN, true, true, sharesIn, abi.encodePacked(NOTE, CURVE));
    }

    function _market() private pure returns (IMoongladeCurve.MarketState memory) {
        uint256 cashReserve = 1000e6;
        uint256 noteReserve = 1000e6;
        uint256 timeUntilMaturity = 30 days;
        uint256 payoutPerShare = 1e18;

        return IMoongladeCurve.MarketState({
            note: NOTE,
            cashBalance: cashReserve,
            noteBalance: noteReserve,
            timeLeft: timeUntilMaturity,
            payout: payoutPerShare
        });
    }
}

contract MoongladeSwapHarness {
    function exec(
        address _note,
        address _loanToken,
        bool _buying,
        bool _isExactIn,
        uint256 _amount,
        bytes calldata _data
    ) external view returns (uint256, uint256) {
        uint256 reserveIn = 1000e6;
        uint256 reserveOut = 1000e6;

        Context memory ctx;
        ctx.query.tokenIn = _buying ? _note : _loanToken;
        ctx.query.tokenOut = _buying ? _loanToken : _note;
        ctx.query.isExactIn = _isExactIn;
        ctx.swap.balanceIn = reserveIn;
        ctx.swap.balanceOut = reserveOut;
        if (_isExactIn) ctx.swap.amountIn = _amount;
        else ctx.swap.amountOut = _amount;

        MoongladeSwap.exec(ctx, _data);

        return (ctx.swap.amountIn, ctx.swap.amountOut);
    }
}
