// SPDX-License-Identifier: MIT AND LicenseRef-Degensoft-SwapVM-1.1
pragma solidity 0.8.30;

import { AquaOpcodes } from "swap-vm/src/opcodes/AquaOpcodes.sol";
import { Context } from "swap-vm/src/libs/VM.sol";

import { IMoongladeRouter } from "src/routers/interfaces/IMoongladeRouter.sol";

import { MoongladeSwap } from "src/instructions/MoongladeSwap.sol";

/// @title Moonglade opcode table.
/// @author Sahil Gujrati (@mgnfy-view).
/// @notice Extend Aqua's pinned opcode table with maker pricing and Midnight tick snapping.
/// @dev Existing instruction indices remain intact; unassigned extended indices revert.
abstract contract MoongladeOpcodes is AquaOpcodes, IMoongladeRouter {
    /// @notice Opcode combining maker-selected pricing with native tick snapping.
    uint256 public constant MOONGLADE_SWAP_OPCODE = MoongladeSwap.OPCODE;

    /// @notice Bind inherited Aqua-aware instructions to the selected Aqua instance.
    /// @param _aqua Aqua registry and settlement contract.
    constructor(address _aqua) AquaOpcodes(_aqua) { }

    // ===== Internal functions =====

    /// @notice Extend Aqua's opcode table with the combined pricing and Midnight tick-snapping handler.
    /// @dev Unassigned slots revert, preserving all inherited opcode positions.
    /// @return Opcode handlers indexed by the instruction byte.
    function _opcodes() internal pure override returns (function(Context memory, bytes calldata) internal[] memory) {
        function(Context memory, bytes calldata) internal[] memory inherited = super._opcodes();
        function(Context memory, bytes calldata) internal[] memory result =
            new function(Context memory, bytes calldata) internal[](MOONGLADE_SWAP_OPCODE + 1);

        for (uint256 i; i < result.length; ++i) {
            result[i] = i < inherited.length ? inherited[i] : _unknown;
        }
        result[MOONGLADE_SWAP_OPCODE] = MoongladeSwap.exec;

        return result;
    }

    /// @notice Reject an unassigned opcode.
    function _unknown(Context memory, bytes calldata) internal pure {
        revert IMoongladeRouter.MoongladeRouter__UnknownOpcode();
    }
}
