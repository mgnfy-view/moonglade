// SPDX-License-Identifier: MIT
pragma solidity 0.8.34;

import { IMidnight, Market } from "midnight/src/interfaces/IMidnight.sol";

import { IdLib } from "midnight/src/libraries/IdLib.sol";

import { IMoongladeNoteFactory } from "src/note/interfaces/IMoongladeNoteFactory.sol";

import { MoongladeNote } from "src/note/MoongladeNote.sol";
import { MoongladeNoteFactory } from "src/note/MoongladeNoteFactory.sol";
import { MoongladeNoteTestBase } from "test/helpers/MoongladeNoteTestBase.sol";

contract MoongladeNoteFactoryTest is MoongladeNoteTestBase {
    function testFactoryReusesOneRegisteredNotePerMarket() public {
        uint8 expectedDecimals = 6;

        assertEq(factory.create(market), address(note));
        assertEq(factory.notes(marketId), address(note));
        assertTrue(factory.isMoongladeNote(address(note)));
        assertEq(note.marketId(), marketId);
        assertEq(note.decimals(), expectedDecimals);
        assertEq(note.ratifier(), address(factory.ratifier()));
        assertEq(note.totalSupply(), 0);
        assertEq(midnight.debt(marketId, alice), 0);
    }

    function testDifferentMarketsReceiveDistinctRegisteredNotes() public {
        uint256 additionalDuration = 1 days;
        Market memory otherMarket = market;
        otherMarket.maturity += additionalDuration;
        bytes32 otherMarketId = IdLib.toId(otherMarket);

        address otherNote = factory.create(otherMarket);

        assertNotEq(otherNote, address(note));
        assertEq(factory.notes(otherMarketId), otherNote);
        assertTrue(factory.isMoongladeNote(otherNote));
        assertEq(MoongladeNote(otherNote).marketId(), otherMarketId);
        assertEq(MoongladeNote(otherNote).ratifier(), address(factory.ratifier()));
        assertEq(factory.create(otherMarket), otherNote);
        assertEq(factory.notes(marketId), address(note));
    }

    function testRejectsInvalidDeploymentAndIneligibleMarkets() public {
        uint256 chainIdOffset = 1;
        address gate = makeAddr("gate");
        Market memory ineligibleMarket = market;

        vm.expectRevert(IMoongladeNoteFactory.MoongladeNoteFactory__InvalidMidnight.selector);
        new MoongladeNoteFactory(IMidnight(address(0)));

        ineligibleMarket.chainId += chainIdOffset;
        vm.expectRevert(IMoongladeNoteFactory.MoongladeNoteFactory__InvalidChain.selector);
        factory.create(ineligibleMarket);

        ineligibleMarket.chainId = block.chainid;
        ineligibleMarket.enterGate = gate;
        vm.expectRevert(IMoongladeNoteFactory.MoongladeNoteFactory__GatedMarket.selector);
        factory.create(ineligibleMarket);

        ineligibleMarket.enterGate = address(0);
        ineligibleMarket.liquidatorGate = gate;
        vm.expectRevert(IMoongladeNoteFactory.MoongladeNoteFactory__GatedMarket.selector);
        factory.create(ineligibleMarket);
    }

    function testMaturityPreservesExistingLookupButRejectsNewNote() public {
        uint256 maturityOffset = 1;
        Market memory unregisteredMarket = market;
        unregisteredMarket.maturity -= maturityOffset;
        bytes32 unregisteredMarketId = IdLib.toId(unregisteredMarket);
        vm.warp(market.maturity);

        assertEq(factory.create(market), address(note));
        vm.expectRevert(IMoongladeNoteFactory.MoongladeNoteFactory__MarketMatured.selector);
        factory.create(unregisteredMarket);
        assertEq(factory.notes(unregisteredMarketId), address(0));
    }
}
