// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { Controls } from "swap-vm/src/instructions/Controls.sol";

import { IMoongladeRouter } from "src/routers/interfaces/IMoongladeRouter.sol";

import { MoongladeSwap } from "src/instructions/MoongladeSwap.sol";
import { RouterTestBase } from "test/helpers/RouterTestBase.sol";

contract MoongladeOpcodesTest is RouterTestBase {
    function test_CustomOpcodeDispatchesPricingInstruction() public {
        uint256 sharesIn = 100e6;
        bytes memory program = MoongladeSwap.build(pricingConfig);

        (uint256 amountIn, uint256 amountOut) = _runProgram(program, sharesIn);

        assertEq(amountIn, sharesIn);
        assertGt(amountOut, 0);
        assertLt(amountOut, sharesIn);
    }

    function test_InheritedDeadlineOpcodeStillRejectsExpiredProgram() public {
        uint8 deadlineOpcode = 13;
        uint8 deadlineLength = 5;
        uint256 timePastDeadline = 1 seconds;
        uint40 expiredDeadline = uint40(block.timestamp - timePastDeadline);
        uint256 sharesIn = 100e6;
        bytes memory program = abi.encodePacked(deadlineOpcode, deadlineLength, expiredDeadline);

        vm.expectRevert(abi.encodeWithSelector(Controls.DeadlineReached.selector, address(this), expiredDeadline));
        _runProgram(program, sharesIn);
    }

    function test_UnassignedExtendedOpcodeRejectsExecution() public {
        uint8 unassignedOpcode = 0xcf;
        uint256 sharesIn = 100e6;
        bytes memory program = abi.encodePacked(unassignedOpcode, uint8(0));

        vm.expectRevert(IMoongladeRouter.MoongladeRouter__UnknownOpcode.selector);
        _runProgram(program, sharesIn);
    }
}
