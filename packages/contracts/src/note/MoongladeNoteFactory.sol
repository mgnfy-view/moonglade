// SPDX-License-Identifier: MIT
pragma solidity 0.8.34;

import { IMidnight } from "midnight/src/interfaces/IMidnight.sol";

import { IdLib } from "midnight/src/libraries/IdLib.sol";
import { Market } from "midnight/src/interfaces/IMidnight.sol";

import { IMoongladeNoteFactory } from "src/note/interfaces/IMoongladeNoteFactory.sol";
import { IMoongladeNoteRatifier } from "src/note/interfaces/IMoongladeNoteRatifier.sol";

import { MoongladeNote } from "src/note/MoongladeNote.sol";
import { MoongladeNoteRatifier } from "src/note/MoongladeNoteRatifier.sol";

/// @title Moonglade Note Factory.
/// @author Sahil Gujrati (@mgnfy-view).
/// @notice Permissionless, deterministic, one-wrapper-per-market registry for one Midnight deployment.
/// @dev Only ungated markets are eligible; the immutable shared ratifier trusts this registry.
contract MoongladeNoteFactory is IMoongladeNoteFactory {
    // ==================== Immutables ====================

    /// @notice Midnight deployment used by every registered note.
    IMidnight public immutable midnight;
    /// @notice Shared ratifier created exclusively for this registry.
    IMoongladeNoteRatifier public immutable ratifier;

    // ==================== State ====================

    /// @notice Deterministic note registered for each market identifier.
    mapping(bytes32 marketId => address wrapper) public notes;
    /// @notice Whether an address was deployed and registered by this factory.
    mapping(address wrapper => bool registered) public isMoongladeNote;

    /// @notice Bind the registry to Midnight and deploy its immutable ratifier.
    /// @dev Requires a nonzero Midnight address; no owner or later configuration exists.
    /// @param _midnight Midnight deployment used for market validation and note credit.
    constructor(IMidnight _midnight) {
        if (address(_midnight) == address(0)) revert IMoongladeNoteFactory.MoongladeNoteFactory__InvalidMidnight();

        midnight = _midnight;
        ratifier = new MoongladeNoteRatifier(address(_midnight), IMoongladeNoteFactory(address(this)));
    }

    // ==================== User actions ====================

    /// @notice Return the existing note or deploy and register one for an eligible market.
    /// @dev Anyone may create a note. Midnight validates market parameters before CREATE2 deployment.
    /// Existing registered notes remain available after maturity; gated markets are always rejected.
    /// @param _market Ungated market for this Midnight deployment and chain.
    /// @return Existing or newly deployed note address.
    function create(Market memory _market) external returns (address) {
        if (_market.chainId != block.chainid) revert IMoongladeNoteFactory.MoongladeNoteFactory__InvalidChain();
        if (_market.enterGate != address(0) || _market.liquidatorGate != address(0)) {
            revert IMoongladeNoteFactory.MoongladeNoteFactory__GatedMarket();
        }

        bytes32 id = IdLib.toId(_market);
        address wrapper = notes[id];
        if (wrapper != address(0)) return wrapper;
        if (_market.maturity <= block.timestamp) revert IMoongladeNoteFactory.MoongladeNoteFactory__MarketMatured();

        // Validate and initialize (if doesn't exist) the Midnight market.
        midnight.touchMarket(_market);
        wrapper = address(new MoongladeNote{ salt: id }(midnight, address(ratifier), _market));
        notes[id] = wrapper;
        isMoongladeNote[wrapper] = true;

        emit IMoongladeNoteFactory.MoongladeNoteCreated(id, wrapper);

        return wrapper;
    }
}
