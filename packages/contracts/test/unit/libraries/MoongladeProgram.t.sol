// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { IMoongladeSwap } from "src/instructions/interfaces/IMoongladeSwap.sol";

import { MoongladeSwap } from "src/instructions/MoongladeSwap.sol";
import { MoongladeProgram } from "src/libraries/MoongladeProgram.sol";
import { RouterTestBase } from "test/helpers/RouterTestBase.sol";

contract MoongladeProgramTest is RouterTestBase {
    function test_ProgramPreservesPricingPayloadAndSalt() public {
        uint8 pricingOpcode = 0xd0;
        uint8 saltOpcode = 20;
        uint8 saltLength = 8;
        uint8 addressHeaderLength = 40;
        uint64 strategySalt = 7;
        uint8 payloadLength = addressHeaderLength + uint8(pricingConfig.data.length);
        bytes memory program = MoongladeProgram.build(pricingConfig, strategySalt);
        bytes memory expectedProgram = abi.encodePacked(
            pricingOpcode,
            payloadLength,
            pricingConfig.note,
            pricingConfig.curve,
            pricingConfig.data,
            saltOpcode,
            saltLength,
            strategySalt
        );
        MoongladeProgramHarness harness = new MoongladeProgramHarness();

        IMoongladeSwap.Config memory decoded = harness.decodeConfig(program);

        assertEq(program, expectedProgram);
        assertEq(decoded.note, pricingConfig.note);
        assertEq(decoded.curve, pricingConfig.curve);
        assertEq(decoded.data, pricingConfig.data);
    }

    function test_SaltChangesProgramIdentityWithoutChangingExecution() public {
        uint64 firstSalt = 7;
        uint64 secondSalt = 8;
        uint256 sharesIn = 100e6;
        bytes memory firstProgram = MoongladeProgram.build(pricingConfig, firstSalt);
        bytes memory secondProgram = MoongladeProgram.build(pricingConfig, secondSalt);

        (uint256 firstAmountIn, uint256 firstAmountOut) = _runProgram(firstProgram, sharesIn);
        (uint256 secondAmountIn, uint256 secondAmountOut) = _runProgram(secondProgram, sharesIn);

        assertNotEq(keccak256(firstProgram), keccak256(secondProgram));
        assertEq(firstAmountIn, sharesIn);
        assertEq(secondAmountIn, sharesIn);
        assertGt(firstAmountOut, 0);
        assertEq(firstAmountOut, secondAmountOut);
    }
}

contract MoongladeProgramHarness {
    function decodeConfig(bytes calldata _program) external pure returns (IMoongladeSwap.Config memory) {
        uint256 instructionHeaderLength = 2;
        uint256 payloadLength = uint8(_program[1]);

        return MoongladeSwap.decode(_program[instructionHeaderLength:instructionHeaderLength + payloadLength]);
    }
}
