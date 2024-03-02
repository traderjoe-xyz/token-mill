// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";

import {Math} from "../../src/libraries/Math.sol";

contract MathTest is Test {
    using Math for uint256;

    function test_Fuzz_AddDelta(uint256 x, int256 delta) public {
        x = bound(x, 0, uint256(type(int256).max));
        delta = bound(delta, -int256(x), type(int256).max - int256(x));

        uint256 y = x.addDelta(delta);

        if (delta < 0) {
            assertEq(x - uint256(-delta), y);
        } else {
            assertEq(x + uint256(delta), y);
        }
    }

    function test_Fuzz_Revert_AddDelta(uint256 x, int256 delta) public {
        uint256 x0 = bound(x, 0, uint256(type(int256).max) - 1);
        int256 delta0 = bound(delta, type(int256).min, -int256(x0) - 1);

        vm.expectRevert(Math.Math__UnderOverflow.selector);
        x0.addDelta(delta0);

        uint256 x1 = bound(x, 1, uint256(type(int256).max));
        int256 delta1 = bound(delta, type(int256).max - (int256(x1) - 1), type(int256).max);

        vm.expectRevert(Math.Math__UnderOverflow.selector);
        x1.addDelta(delta1);
    }

    function test_Fuzz_Sub(uint256 x, uint256 y) public {
        x = bound(x, 0, uint256(type(int256).max));
        y = bound(y, 0, uint256(type(int256).max));

        int256 delta = x.sub(y);

        if (y > x) {
            assertEq(-int256(y - x), delta);
        } else {
            assertEq(int256(x - y), delta);
        }
    }

    function test_Fuzz_Revert_Sub(uint256 x, uint256 y) public {
        uint256 x0 = bound(x, uint256(type(int256).max) + 1, type(uint256).max);

        vm.expectRevert(Math.Math__UnderOverflow.selector);
        x0.sub(0);

        uint256 y0 = bound(y, uint256(type(int256).max) + 1, type(uint256).max);

        vm.expectRevert(Math.Math__UnderOverflow.selector);
        uint256(0).sub(y0);

        vm.expectRevert(Math.Math__UnderOverflow.selector);
        x0.sub(y0);
    }

    function test_Fuzz_MostSignificantBit(uint256 x) public {
        x = bound(x, 1, type(uint256).max);

        uint8 msb = x.mostSignificantBit();

        assertGe(x, 1 << msb);
        assertLt(x >> 1, 1 << msb);
    }

    function test_Fuzz_Sqrt(uint256 x) public {
        x = bound(x, 0, type(uint256).max);

        uint256 y = x.sqrt();

        assertLe(y * y, x);
        if (y < type(uint128).max) assertGt((y + 1) * (y + 1), x);
    }
}
