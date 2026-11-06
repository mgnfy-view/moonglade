// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

/// @title Moonglade Note Interface.
/// @author Sahil Gujrati (@mgnfy-view).
/// @notice Exposes the active offer authenticated by the note ratifier.
interface IMoongladeNote {
    function activeOfferHash() external view returns (bytes32);
}
