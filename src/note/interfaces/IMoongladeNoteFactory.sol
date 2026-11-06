// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

/// @title Moonglade Note Factory Interface.
/// @author Sahil Gujrati (@mgnfy-view).
/// @notice Identifies notes eligible to use the shared ratifier.
interface IMoongladeNoteFactory {
    function isMoongladeNote(address _wrapper) external view returns (bool);
}
