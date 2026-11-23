// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { IERC20 } from "@openzeppelin-contracts/token/ERC20/IERC20.sol";
import { ISwapVM } from "swap-vm/src/interfaces/ISwapVM.sol";

import { Ownable } from "@openzeppelin-contracts/access/Ownable.sol";

import { IMoongladeRouter } from "src/routers/interfaces/IMoongladeRouter.sol";

import { RouterTestBase, RouterTestToken } from "test/helpers/RouterTestBase.sol";

contract MoongladeRouterTest is RouterTestBase {
    function test_RenouncedOwnershipDisablesTokenRescue() public {
        uint256 strandedAssets = 1e6;
        cashToken.mint(address(router), strandedAssets);

        assertEq(router.owner(), address(0));
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(this)));
        router.rescueFunds(IERC20(address(cashToken)), strandedAssets);
        assertEq(cashToken.balanceOf(address(router)), strandedAssets);
    }

    function test_QuoteAndSwapNotesForCashSettleThroughAqua() public {
        uint256 sharesIn = 100e6;

        uint256 assetsOut = _settleAndAssert(noteToken, cashToken, sharesIn);

        assertLt(assetsOut, sharesIn);
    }

    function test_QuoteAndSwapCashForNotesSettleThroughAqua() public {
        uint256 assetsIn = 100e6;

        uint256 sharesOut = _settleAndAssert(cashToken, noteToken, assetsIn);

        assertGt(sharesOut, assetsIn);
    }

    function test_ClosedMarketRejectsQuoteAndSwapWithoutTransfers() public {
        uint256 maturityBuffer = 1 days;
        uint256 sharesIn = 100e6;
        uint256 takerNotesBefore = noteToken.balanceOf(taker);
        uint256 makerCashBefore = cashToken.balanceOf(maker);
        bytes memory takerData = _takerData(0);
        vm.warp(maturity - maturityBuffer);

        vm.expectRevert(IMoongladeRouter.MoongladeRouter__MarketClosed.selector);
        vm.prank(taker);
        ISwapVM(address(router)).quote(order, address(noteToken), address(cashToken), sharesIn, takerData);
        vm.expectRevert(IMoongladeRouter.MoongladeRouter__MarketClosed.selector);
        vm.prank(taker);
        router.swap(order, address(noteToken), address(cashToken), sharesIn, takerData);

        assertEq(noteToken.balanceOf(taker), takerNotesBefore);
        assertEq(cashToken.balanceOf(maker), makerCashBefore);
    }

    function _settleAndAssert(RouterTestToken _tokenIn, RouterTestToken _tokenOut, uint256 _amount)
        private
        returns (uint256)
    {
        uint256 takerInputBefore = _tokenIn.balanceOf(taker);
        uint256 takerOutputBefore = _tokenOut.balanceOf(taker);
        uint256 makerInputBefore = _tokenIn.balanceOf(maker);
        uint256 makerOutputBefore = _tokenOut.balanceOf(maker);
        bytes32 expectedHash = router.hash(order);
        (uint256 virtualInputBefore, uint256 virtualOutputBefore) =
            aqua.safeBalances(maker, address(router), expectedHash, address(_tokenIn), address(_tokenOut));
        bytes memory quoteData = _takerData(0);

        vm.prank(taker);
        (uint256 quotedIn, uint256 quotedOut, bytes32 quoteHash) =
            ISwapVM(address(router)).quote(order, address(_tokenIn), address(_tokenOut), _amount, quoteData);

        assertEq(quotedIn, _amount);
        assertGt(quotedOut, 0);
        assertEq(quoteHash, expectedHash);
        assertEq(_tokenIn.balanceOf(taker), takerInputBefore);
        assertEq(_tokenOut.balanceOf(maker), makerOutputBefore);
        bytes memory swapData = _takerData(quotedOut);

        vm.prank(taker);
        (uint256 actualIn, uint256 actualOut, bytes32 swapHash) =
            router.swap(order, address(_tokenIn), address(_tokenOut), _amount, swapData);

        assertEq(actualIn, quotedIn);
        assertEq(actualOut, quotedOut);
        assertEq(swapHash, expectedHash);
        assertEq(_tokenIn.balanceOf(taker), takerInputBefore - actualIn);
        assertEq(_tokenOut.balanceOf(taker), takerOutputBefore + actualOut);
        assertEq(_tokenIn.balanceOf(maker), makerInputBefore + actualIn);
        assertEq(_tokenOut.balanceOf(maker), makerOutputBefore - actualOut);
        (uint256 virtualInputAfter, uint256 virtualOutputAfter) =
            aqua.safeBalances(maker, address(router), expectedHash, address(_tokenIn), address(_tokenOut));
        assertEq(virtualInputAfter, virtualInputBefore + actualIn);
        assertEq(virtualOutputAfter, virtualOutputBefore - actualOut);
        assertEq(_tokenIn.balanceOf(address(router)), 0);
        assertEq(_tokenOut.balanceOf(address(router)), 0);

        return actualOut;
    }
}
