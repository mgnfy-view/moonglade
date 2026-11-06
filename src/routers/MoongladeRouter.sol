// SPDX-License-Identifier: MIT AND LicenseRef-Degensoft-SwapVM-1.1
pragma solidity 0.8.30;

import { Simulator } from "@1inch/solidity-utils/contracts/mixins/Simulator.sol";
import { SwapVM } from "swap-vm/src/SwapVM.sol";
import { Context } from "swap-vm/src/libs/VM.sol";

import { IMoongladeRouter } from "src/routers/interfaces/IMoongladeRouter.sol";

import { MoongladeOpcodes } from "src/opcodes/MoongladeOpcodes.sol";

/// @title Moonglade SwapVM router.
/// @author Sahil Gujrati (@mgnfy-view).
/// @notice Ownerless SwapVM integration using Aqua and the Moonglade instruction table.
/// @dev Instruction builders and execution live in instructions/; dispatch lives in opcodes/.
contract MoongladeRouter is Simulator, SwapVM, IMoongladeRouter, MoongladeOpcodes {
    /// @notice Bind Aqua and WETH and permanently renounce inherited rescue ownership.
    /// @param _aqua Aqua balance and settlement contract.
    /// @param _weth Wrapped native token used by inherited settlement.
    constructor(address _aqua, address _weth)
        SwapVM(_aqua, _weth, address(this), "MoongladeRouter", "1")
        MoongladeOpcodes(_aqua)
    {
        _transferOwnership(address(0));
    }

    /// @notice Supply the Moonglade-extended opcode table to SwapVM's interpreter.
    /// @return Instruction handlers indexed by opcode byte.
    function _instructions()
        internal
        pure
        override
        returns (function(Context memory, bytes calldata) internal[] memory)
    {
        return _opcodes();
    }
}
