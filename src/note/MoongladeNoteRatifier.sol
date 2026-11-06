// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import { Offer } from "midnight/src/interfaces/IMidnight.sol";

import { CALLBACK_SUCCESS } from "midnight/src/libraries/ConstantsLib.sol";

import { IMoongladeNote } from "src/note/interfaces/IMoongladeNote.sol";
import { IMoongladeNoteFactory } from "src/note/interfaces/IMoongladeNoteFactory.sol";
import { IMoongladeNoteRatifier } from "src/note/interfaces/IMoongladeNoteRatifier.sol";

/// @title Moonglade Note Ratifier.
/// @author Sahil Gujrati (@mgnfy-view).
/// @notice Ratifies only the exact offer currently being taken by a factory-created wrapper.
/// @dev Holds no mutable state and never calls Midnight or exercises an operator authorization.
contract MoongladeNoteRatifier is IMoongladeNoteRatifier {
    // ==================== Immutables ====================

    /// @notice Only this Midnight deployment may request ratification.
    address public immutable midnight;
    /// @notice Registry whose deployed notes may activate internal offers.
    IMoongladeNoteFactory public immutable factory;

    /// @notice Fix the only Midnight caller and the trusted note registry.
    /// @dev Factory deployment supplies both immutable dependencies without external calls.
    /// @param _midnight Midnight deployment allowed to invoke the callback.
    /// @param _factory Registry used to authenticate note takers.
    constructor(address _midnight, IMoongladeNoteFactory _factory) {
        midnight = _midnight;
        factory = _factory;
    }

    // ==================== External views ====================

    /// @notice Authorize only a registered note's exact transient internal offer.
    /// @dev Rejects other callers, nonempty data, unregistered takers, and inactive or mismatched hashes.
    /// Midnight dispatches the callback to the ratifier named in the offer.
    /// Calls the fixed registry and then the authenticated note's context; neither call mutates state.
    /// @param _offer Offer being settled by Midnight.
    /// @param _ratifierData Must be empty for wrapper-issued offers.
    /// @param _taker Registered note that activated the offer hash.
    /// @return Midnight callback success constant, or zero when authorization fails.
    function isRatified(Offer memory _offer, bytes memory _ratifierData, address _taker)
        external
        view
        returns (bytes32)
    {
        if (msg.sender != midnight || _ratifierData.length != 0) {
            return bytes32(0);
        }
        if (!factory.isMoongladeNote(_taker)) return bytes32(0);

        bytes32 activeHash = IMoongladeNote(_taker).activeOfferHash();
        if (activeHash == bytes32(0) || activeHash != keccak256(abi.encode(_offer))) return bytes32(0);

        return CALLBACK_SUCCESS;
    }
}
