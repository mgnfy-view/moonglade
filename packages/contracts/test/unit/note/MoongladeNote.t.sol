// SPDX-License-Identifier: MIT
pragma solidity 0.8.34;

import { IMidnight, Offer } from "midnight/src/interfaces/IMidnight.sol";

import { MAX_TICK } from "midnight/src/libraries/TickLib.sol";

import { IMoongladeNote } from "src/note/interfaces/IMoongladeNote.sol";

import { MoongladeNoteTestBase, NoteTestRatifier } from "test/helpers/MoongladeNoteTestBase.sol";

contract MoongladeNoteTest is MoongladeNoteTestBase {
    function testMintCreatesBorrowerDebtAndNetCreditShares() public {
        uint256 requestedShares = 10_000 * UNIT;
        uint256 expectedGrossUnits = 10_024_719_486;
        uint256 expectedPendingFee = 24_718_486;
        uint256 expectedDeadShares = 1000;
        uint256 expectedSettlementCost = 5_012_360;
        uint256 expectedPayout = 1e18;
        uint256 beforeCash = loan.balanceOf(alice);
        (uint256 units, uint256 shares) = _mint(alice, requestedShares);

        // 180 days at 0.5% annual continuous fees, plus the initial 0.001-share reserve.
        assertEq(units, expectedGrossUnits);
        assertEq(shares, requestedShares);
        assertEq(midnight.debt(marketId, alice), units);
        assertEq(midnight.debt(marketId, address(note)), 0);
        assertEq(midnight.credit(marketId, address(note)), units);
        assertEq(midnight.pendingFee(marketId, address(note)), expectedPendingFee);
        assertEq(note.totalAssets(), requestedShares + expectedDeadShares);
        assertEq(note.totalSupply(), note.totalAssets());
        assertEq(note.balanceOf(alice), shares);
        assertEq(note.balanceOf(note.DEAD_SHARES()), expectedDeadShares);
        assertEq(note.payoutPerShare(), expectedPayout);
        assertEq(beforeCash - loan.balanceOf(alice), expectedSettlementCost);
        assertEq(loan.balanceOf(address(note)), 0);
        assertEq(note.activeOfferHash(), bytes32(0));
    }

    function testMintConsumesExistingCreditBeforeCreatingDebt() public {
        uint256 existingCredit = 100 * UNIT;
        uint256 requestedShares = 1000 * UNIT;
        NoteTestRatifier externalRatifier = new NoteTestRatifier();
        vm.prank(bob);
        midnight.setIsAuthorized(address(externalRatifier), true, bob);
        Offer memory offer;
        offer.market = market;
        offer.maker = bob;
        offer.expiry = type(uint256).max;
        offer.tick = MAX_TICK;
        offer.maxUnits = uint128(existingCredit);
        offer.receiverIfMakerIsSeller = bob;
        offer.ratifier = address(externalRatifier);
        offer.continuousFeeCap = type(uint256).max;
        vm.prank(alice);
        midnight.take(offer, "", existingCredit, alice, address(0), address(0), "");
        assertEq(midnight.credit(marketId, alice), existingCredit);

        (uint256 units, uint256 shares) = _mint(alice, requestedShares);

        assertEq(shares, requestedShares);
        assertEq(midnight.credit(marketId, alice), 0);
        assertEq(midnight.debt(marketId, alice), units - existingCredit);
        assertEq(midnight.credit(marketId, address(note)), units);
    }

    function testBurnCancelsGrossDebtAndChargesOnlySettlementFee() public {
        uint256 requestedShares = 10_000 * UNIT;
        (uint256 borrowed, uint256 shares) = _mint(alice, requestedShares);
        (uint256 expectedUnits, uint256 expectedCost) = note.previewBurn(shares);
        uint256 beforeCash = loan.balanceOf(alice);
        vm.prank(alice);
        (uint256 repaid, uint256 cost) = note.burnToRepay(shares, expectedCost, alice, MAX_TICK);

        assertGt(repaid, shares);
        assertEq(repaid, expectedUnits);
        assertEq(cost, expectedCost);
        assertEq(beforeCash - loan.balanceOf(alice), cost);
        assertEq(midnight.debt(marketId, alice), borrowed - repaid);
        assertEq(midnight.credit(marketId, address(note)), borrowed - repaid);
        assertEq(note.balanceOf(alice), 0);
        assertEq(note.totalSupply(), note.MINIMUM_SHARES());
        assertEq(loan.balanceOf(address(note)), 0);
        assertEq(note.activeOfferHash(), bytes32(0));
    }

    function testDelegatedMintConsumesExactBudgetAndKeepsDebtOnBorrower() public {
        uint256 requestedShares = 1000 * UNIT;
        uint256 maxFront = type(uint256).max;
        uint40 approvalDeadline = uint40(block.timestamp + 1 days);
        uint256 units = note.previewMintUnits(requestedShares);
        vm.prank(alice);
        note.approveMint(bob, uint128(units), approvalDeadline);
        vm.prank(bob);
        (uint256 processed, uint256 shares) =
            note.mintFromPosition(requestedShares, units, maxFront, alice, alice, MAX_TICK);

        (uint128 remaining,) = note.borrowAllowances(alice, bob);
        assertEq(processed, units);
        assertEq(remaining, 0);
        assertEq(note.balanceOf(alice), shares);
        assertEq(note.balanceOf(bob), 0);
        assertEq(midnight.debt(marketId, alice), units);
        assertEq(midnight.debt(marketId, bob), 0);
    }

    function testDelegatedMintCannotExceedBorrowerBudget() public {
        uint256 requestedShares = 1000 * UNIT;
        uint256 maxFront = type(uint256).max;
        uint40 approvalDeadline = uint40(block.timestamp + 1 days);
        uint256 units = note.previewMintUnits(requestedShares);
        uint128 insufficientBudget = uint128(units - 1);
        vm.prank(alice);
        note.approveMint(bob, insufficientBudget, approvalDeadline);
        uint256 beforeCash = loan.balanceOf(bob);

        vm.prank(bob);
        vm.expectRevert(IMoongladeNote.MoongladeNote__BorrowAllowanceExceeded.selector);
        note.mintFromPosition(requestedShares, units, maxFront, alice, alice, MAX_TICK);

        (uint128 remaining,) = note.borrowAllowances(alice, bob);
        assertEq(remaining, insufficientBudget);
        assertEq(midnight.debt(marketId, alice), 0);
        assertEq(note.totalSupply(), 0);
        assertEq(loan.balanceOf(bob), beforeCash);
    }

    function testDelegatedMintCannotRedirectBorrowerShares() public {
        uint256 requestedShares = 1000 * UNIT;
        uint256 maxFront = type(uint256).max;
        uint40 approvalDeadline = uint40(block.timestamp + 1 days);
        uint256 units = note.previewMintUnits(requestedShares);
        vm.prank(alice);
        note.approveMint(bob, uint128(units), approvalDeadline);

        vm.prank(bob);
        vm.expectRevert(
            abi.encodeWithSelector(IMoongladeNote.MoongladeNote__InvalidBorrowReceiver.selector, alice, bob)
        );
        note.mintFromPosition(requestedShares, units, maxFront, alice, bob, MAX_TICK);

        (uint128 remaining,) = note.borrowAllowances(alice, bob);
        assertEq(remaining, units);
        assertEq(midnight.debt(marketId, alice), 0);
        assertEq(note.totalSupply(), 0);
    }

    function testMintRequiresBorrowerRatifierAuthorization() public {
        uint256 requestedShares = 1000 * UNIT;
        uint256 maxUnits = type(uint256).max;
        uint256 maxFront = type(uint256).max;
        address ratifier = note.ratifier();
        vm.prank(alice);
        midnight.setIsAuthorized(ratifier, false, alice);
        uint256 beforeCash = loan.balanceOf(alice);

        vm.prank(alice);
        vm.expectRevert(IMidnight.RatifierUnauthorized.selector);
        note.mintFromPosition(requestedShares, maxUnits, maxFront, alice, alice, MAX_TICK);

        assertEq(loan.balanceOf(alice), beforeCash);
        assertEq(midnight.debt(marketId, alice), 0);
        assertEq(note.totalSupply(), 0);
        assertEq(note.activeOfferHash(), bytes32(0));
    }

    function testMaturityRepaymentFundsShareRedemption() public {
        uint256 requestedShares = 10_000 * UNIT;
        (uint256 debt, uint256 shares) = _mint(alice, requestedShares);
        vm.prank(alice);
        vm.expectRevert(IMoongladeNote.MoongladeNote__MarketNotMatured.selector);
        note.redeem(shares, bob);

        vm.warp(market.maturity);
        vm.prank(alice);
        midnight.repay(market, debt, alice, address(0), "");
        uint256 beforeCash = loan.balanceOf(bob);
        vm.prank(alice);
        uint256 redeemed = note.redeem(shares, bob);

        assertEq(redeemed, shares);
        assertEq(loan.balanceOf(bob) - beforeCash, redeemed);
        assertEq(midnight.debt(marketId, alice), 0);
        assertEq(note.balanceOf(alice), 0);
        assertEq(note.totalSupply(), note.MINIMUM_SHARES());
        assertEq(note.totalAssets(), note.MINIMUM_SHARES());
    }

    function testWrapExternalSellOfferIssuesSharesAgainstReceivedNetCredit() public {
        uint256 purchasedCreditUnits = 1000 * UNIT;
        Offer memory sellOffer = _externalOffer(false, purchasedCreditUnits, bob);
        uint256 buyerCashBefore = loan.balanceOf(alice);
        uint256 sellerCashBefore = loan.balanceOf(bob);

        vm.prank(alice);
        uint256 issuedShares = note.wrapFromOffer(sellOffer, "", purchasedCreditUnits, alice);

        uint256 expectedNetAssets = purchasedCreditUnits - midnight.pendingFee(marketId, address(note));
        uint256 expectedSupply = issuedShares + note.MINIMUM_SHARES();
        assertGt(issuedShares, 0);
        assertEq(note.balanceOf(alice), issuedShares);
        assertEq(note.totalAssets(), expectedNetAssets);
        assertEq(note.totalSupply(), expectedSupply);
        assertEq(expectedSupply, expectedNetAssets);
        assertEq(midnight.credit(marketId, address(note)), purchasedCreditUnits);
        assertEq(midnight.debt(marketId, bob), purchasedCreditUnits);
        assertEq(midnight.debt(marketId, alice), 0);
        assertLt(loan.balanceOf(alice), buyerCashBefore);
        assertGt(loan.balanceOf(bob), sellerCashBefore);
        assertEq(loan.balanceOf(address(note)), 0);
        assertEq(note.activeOfferHash(), bytes32(0));
    }

    function testUnwrapExternalBuyOfferBurnsSharesAndPaysReceiver() public {
        uint256 requestedShares = 1000 * UNIT;
        (uint256 originalCredit, uint256 issuedShares) = _mint(alice, requestedShares);
        (uint256 creditToSell,) = note.previewBurn(issuedShares);
        Offer memory buyOffer = _externalOffer(true, creditToSell, bob);
        address cashReceiver = makeAddr("cashReceiver");
        uint256 buyerCashBefore = loan.balanceOf(bob);
        uint256 receiverCashBefore = loan.balanceOf(cashReceiver);
        uint256 expectedRemainingCredit = originalCredit - creditToSell;

        vm.prank(alice);
        uint256 receivedAssets = note.unwrapToOffer(issuedShares, buyOffer, "", cashReceiver);

        assertGt(receivedAssets, 0);
        assertEq(loan.balanceOf(cashReceiver) - receiverCashBefore, receivedAssets);
        assertLt(loan.balanceOf(bob), buyerCashBefore);
        assertEq(note.balanceOf(alice), 0);
        assertEq(note.totalSupply(), note.MINIMUM_SHARES());
        assertEq(midnight.credit(marketId, bob), creditToSell);
        assertEq(midnight.credit(marketId, address(note)), expectedRemainingCredit);
        assertEq(midnight.debt(marketId, alice), originalCredit);
        assertEq(loan.balanceOf(address(note)), 0);
        assertEq(note.activeOfferHash(), bytes32(0));
    }
}
