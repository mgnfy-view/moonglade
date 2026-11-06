// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import { IMidnight, Market } from "midnight/src/interfaces/IMidnight.sol";

import { IMoongladeNoteRatifier } from "src/note/interfaces/IMoongladeNoteRatifier.sol";

/// @title Moonglade Note Factory Interface.
/// @author Sahil Gujrati (@mgnfy-view).
/// @notice Permissionless registry and deterministic deployment surface for market-specific notes.
/// @dev Exposes the fixed Midnight deployment, shared ratifier, and canonical note registration.
interface IMoongladeNoteFactory {
    /// @notice A deterministic note was created and registered for the market.
    /// @param _marketId Canonical Midnight market identifier.
    /// @param _wrapper Deployed note address.
    event MoongladeNoteCreated(bytes32 indexed _marketId, address indexed _wrapper);

    /// @notice Midnight is the zero address.
    error MoongladeNoteFactory__InvalidMidnight();
    /// @notice The market targets a different chain.
    error MoongladeNoteFactory__InvalidChain();
    /// @notice The market restricts entry or liquidation through a gate.
    error MoongladeNoteFactory__GatedMarket();
    /// @notice A new wrapper cannot be created for a matured market.
    error MoongladeNoteFactory__MarketMatured();

    // ==================== User actions ====================

    function create(Market memory _market) external returns (address);

    // ==================== Views ====================

    function midnight() external view returns (IMidnight);
    function ratifier() external view returns (IMoongladeNoteRatifier);
    function notes(bytes32 _marketId) external view returns (address);
    function isMoongladeNote(address _wrapper) external view returns (bool);
}
