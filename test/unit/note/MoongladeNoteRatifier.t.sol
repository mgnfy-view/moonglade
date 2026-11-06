// SPDX-License-Identifier: MIT
pragma solidity 0.8.34;

import { Offer } from "midnight/src/interfaces/IMidnight.sol";

import { CALLBACK_SUCCESS } from "midnight/src/libraries/ConstantsLib.sol";

import { IMoongladeNote } from "src/note/interfaces/IMoongladeNote.sol";
import { IMoongladeNoteRatifier } from "src/note/interfaces/IMoongladeNoteRatifier.sol";

import { MoongladeNoteTestBase } from "test/helpers/MoongladeNoteTestBase.sol";

contract MoongladeNoteRatifierTest is MoongladeNoteTestBase {
    function testRatifiesExactActiveOfferForRegisteredNote() public {
        uint256 offeredUnits = 1000 * UNIT;
        IMoongladeNoteRatifier ratifier = factory.ratifier();
        Offer memory offer = _externalOffer(false, offeredUnits, alice);
        offer.ratifier = address(ratifier);
        bytes32 activeOfferHash = keccak256(abi.encode(offer));
        vm.mockCall(address(note), abi.encodeCall(IMoongladeNote.activeOfferHash, ()), abi.encode(activeOfferHash));

        vm.prank(address(midnight));
        bytes32 result = ratifier.isRatified(offer, "", address(note));

        assertEq(result, CALLBACK_SUCCESS);
    }

    function testRejectsInactiveOrMismatchedOffer() public {
        uint256 offeredUnits = 1000 * UNIT;
        IMoongladeNoteRatifier ratifier = factory.ratifier();
        Offer memory offer = _externalOffer(false, offeredUnits, alice);
        offer.ratifier = address(ratifier);

        vm.prank(address(midnight));
        bytes32 inactiveResult = ratifier.isRatified(offer, "", address(note));
        assertEq(inactiveResult, bytes32(0));

        bytes32 activeOfferHash = keccak256(abi.encode(offer));
        vm.mockCall(address(note), abi.encodeCall(IMoongladeNote.activeOfferHash, ()), abi.encode(activeOfferHash));
        offer.receiverIfMakerIsSeller = bob;
        vm.prank(address(midnight));
        bytes32 mismatchedResult = ratifier.isRatified(offer, "", address(note));
        assertEq(mismatchedResult, bytes32(0));
    }

    function testRejectsWrongCallerUnregisteredTakerOrNonemptyData() public {
        uint256 offeredUnits = 1000 * UNIT;
        IMoongladeNoteRatifier ratifier = factory.ratifier();
        bytes memory unexpectedRatifierData = bytes("unexpected");
        Offer memory offer = _externalOffer(false, offeredUnits, alice);
        offer.ratifier = address(ratifier);
        bytes32 activeOfferHash = keccak256(abi.encode(offer));
        vm.mockCall(address(note), abi.encodeCall(IMoongladeNote.activeOfferHash, ()), abi.encode(activeOfferHash));

        assertEq(ratifier.isRatified(offer, "", address(note)), bytes32(0));
        vm.prank(address(midnight));
        bytes32 unregisteredResult = ratifier.isRatified(offer, "", bob);
        assertEq(unregisteredResult, bytes32(0));
        vm.prank(address(midnight));
        bytes32 nonemptyDataResult = ratifier.isRatified(offer, unexpectedRatifierData, address(note));
        assertEq(nonemptyDataResult, bytes32(0));
    }
}
