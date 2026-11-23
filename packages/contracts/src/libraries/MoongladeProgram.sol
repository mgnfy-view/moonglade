// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { IMoongladeSwap } from "src/instructions/interfaces/IMoongladeSwap.sol";

import { MoongladeSwap } from "src/instructions/MoongladeSwap.sol";

/// @title Moonglade SwapVM program builder.
/// @author Sahil Gujrati (@mgnfy-view).
/// @notice Build the canonical SwapVM program for a configured note market.
/// @dev Instruction indices target the pinned SwapVM v1.0.2 dependency.
library MoongladeProgram {
    /// @notice Opcode shared by the program encoder and router for Moonglade pricing.
    uint8 internal constant MOONGLADE_SWAP_OPCODE = MoongladeSwap.OPCODE;

    // ===== Internal functions =====

    /// @notice Build average-price evaluation, Midnight tick snapping, and a uniqueness salt.
    /// @dev v1.0.2 opcode indices: salt=20; custom pricing and snapping=208.
    /// @param _config Note, pricing implementation, and opaque settings committed into the instruction.
    /// @param _salt Salt appended to distinguish otherwise identical programs.
    /// @return Packed SwapVM program bytes.
    function build(IMoongladeSwap.Config memory _config, uint64 _salt) internal pure returns (bytes memory) {
        return bytes.concat(MoongladeSwap.build(_config), abi.encodePacked(uint8(20), uint8(8), _salt));
    }
}
