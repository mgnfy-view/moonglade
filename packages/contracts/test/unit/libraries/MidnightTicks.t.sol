// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { Test } from "forge-std/Test.sol";
import { TickLib, MAX_TICK } from "midnight/src/libraries/TickLib.sol";

import { MidnightTicks } from "src/libraries/MidnightTicks.sol";

contract MidnightTicksTest is Test {
    function test_CeilAndFloorBracketPriceOnGridFour() public pure {
        uint256 tickSpacing = 4;
        uint256 targetPrice = 0.96e18;
        uint256 expectedLowerTick = 4008;
        uint256 expectedUpperTick = 4012;
        uint256 expectedLowerPrice = 0.9597547e18;
        uint256 expectedUpperPrice = 0.9605221e18;

        uint256 lower = MidnightTicks.floor(targetPrice, tickSpacing);
        uint256 upper = MidnightTicks.ceil(targetPrice, tickSpacing);

        assertEq(lower, expectedLowerTick);
        assertEq(upper, expectedUpperTick);
        assertEq(TickLib.tickToPrice(lower), expectedLowerPrice);
        assertEq(TickLib.tickToPrice(upper), expectedUpperPrice);
        assertLt(TickLib.tickToPrice(lower), targetPrice);
        assertGt(TickLib.tickToPrice(upper), targetPrice);
    }

    function test_EndpointsRespectZeroAndParPlateaus() public pure {
        uint256 tickSpacing = 4;
        uint256 parPrice = 1e18;
        uint256 lastZero = MidnightTicks.floor(0, tickSpacing);
        uint256 firstPar = MidnightTicks.ceil(parPrice, tickSpacing);

        assertEq(MidnightTicks.ceil(0, tickSpacing), 0);
        assertEq(TickLib.tickToPrice(lastZero), 0);
        assertGt(TickLib.tickToPrice(lastZero + tickSpacing), 0);
        assertEq(TickLib.tickToPrice(firstPar), parPrice);
        assertLt(TickLib.tickToPrice(firstPar - tickSpacing), parPrice);
        assertEq(MidnightTicks.floor(parPrice, tickSpacing), MAX_TICK);
        assertEq(MidnightTicks.nearest(0, tickSpacing), 0);
        assertEq(MidnightTicks.nearest(parPrice, tickSpacing), firstPar);
    }

    function test_NearestSelectsClosestPriceAndRoundsTiesDown() public pure {
        uint256 tickSpacing = 4;
        uint256 targetPrice = 0.96e18;
        uint256 lowerTick = 4008;
        uint256 upperTick = 4012;
        uint256 priceAtom = 1;
        uint256 lowerPrice = TickLib.tickToPrice(lowerTick);
        uint256 upperPrice = TickLib.tickToPrice(upperTick);
        uint256 midpoint = (lowerPrice + upperPrice) / 2;

        assertEq(MidnightTicks.nearest(targetPrice, tickSpacing), lowerTick);
        assertEq(MidnightTicks.nearest(lowerPrice, tickSpacing), lowerTick);
        assertEq(MidnightTicks.nearest(midpoint, tickSpacing), lowerTick);
        assertEq(MidnightTicks.nearest(midpoint + priceAtom, tickSpacing), upperTick);
    }
}
