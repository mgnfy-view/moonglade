// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import { IRatifier } from "midnight/src/interfaces/IRatifier.sol";

import { IMoongladeNoteFactory } from "src/note/interfaces/IMoongladeNoteFactory.sol";

/// @title Moonglade Note Ratifier Interface.
/// @author Sahil Gujrati (@mgnfy-view).
/// @notice Exposes the shared note ratifier's fixed deployment and registry dependencies.
/// @dev Midnight's IRatifier defines the authorization callback signature.
interface IMoongladeNoteRatifier is IRatifier {
    function midnight() external view returns (address);
    function factory() external view returns (IMoongladeNoteFactory);
}
