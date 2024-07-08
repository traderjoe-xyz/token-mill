// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";

import {Math as OZMath} from "@openzeppelin/contracts/utils/math/Math.sol";

import {Math} from "../../src/libraries/Math.sol";

contract MathTest is Test {
    using Math for uint256;
    using Math for int256;

    function test_Fuzz_Min(uint256 x, uint256 y) public pure {
        uint256 z = x.min(y);

        if (x < y) {
            assertEq(x, z, "test_Fuzz_Min::1");
        } else {
            assertEq(y, z, "test_Fuzz_Min::2");
        }
    }

    function test_Fuzz_Max(uint256 x, uint256 y) public pure {
        uint256 z = x.max(y);

        if (x > y) {
            assertEq(x, z, "test_Fuzz_Max::1");
        } else {
            assertEq(y, z, "test_Fuzz_Max::2");
        }
    }

    function test_Fuzz_Abs(int256 x) public pure {
        uint256 y = x.abs();

        if (x < 0) {
            if (x == type(int256).min) {
                assertEq(uint256(type(int256).max) + 1, y, "test_Fuzz_Abs::1");
            } else {
                assertEq(uint256(-x), y, "test_Fuzz_Abs::2");
            }
        } else {
            assertEq(uint256(x), y, "test_Fuzz_Abs::3");
        }
    }

    function test_Fuzz_AddDelta(uint256 x, int256 delta) public pure {
        x = bound(x, 0, uint256(type(int256).max));
        delta = bound(delta, -int256(x), type(int256).max - int256(x));

        uint256 y = x.addDelta(delta);

        if (delta < 0) {
            assertEq(x - uint256(-delta), y, "test_Fuzz_AddDelta::1");
        } else {
            assertEq(x + uint256(delta), y, "test_Fuzz_AddDelta::2");
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

    function test_Fuzz_Div(uint256 x, uint256 y) public pure {
        y = bound(y, 1, type(uint256).max);

        uint256 z = x.div(y, true);

        assertEq(x == 0 ? 0 : (x - 1) / y + 1, z, "test_Fuzz_Div::1");

        z = x.div(y, false);

        assertEq(x / y, z, "test_Fuzz_Div::2");
    }

    function test_Fuzz_Revert_Div(uint256 x, bool roundUp) public {
        vm.expectRevert(Math.Math__DivisionByZero.selector);
        x.div(0, roundUp);
    }

    function test_Fuzz_MostSignificantBit(uint256 x) public pure {
        x = bound(x, 1, type(uint256).max);

        uint256 msb = x.mostSignificantBit();

        assertGe(x, 1 << msb, "test_Fuzz_MostSignificantBit::1");
        assertLt(x >> 1, 1 << msb, "test_Fuzz_MostSignificantBit::2");
    }

    function test_Fuzz_MulDiv(uint256 x, uint256 y, uint256 z) public {
        z = bound(z, 1, type(uint256).max);

        bool roundUp = false;

        try this.OZMulDiv(x, y, z, roundUp) returns (uint256 r0) {
            uint256 r1 = x.mulDiv(y, z, roundUp);

            assertEq(r1, r0, "test_Fuzz_MulDiv::1");
        } catch {
            vm.expectRevert(Math.Math__UnderOverflow.selector);
            x.mulDiv(y, z, roundUp);
        }

        roundUp = true;

        try this.OZMulDiv(x, y, z, roundUp) returns (uint256 r0) {
            uint256 r1 = x.mulDiv(y, z, roundUp);

            assertEq(r1, r0, "test_Fuzz_MulDiv::2");
        } catch {
            vm.expectRevert(Math.Math__UnderOverflow.selector);
            x.mulDiv(y, z, roundUp);
        }
    }

    function test_Fuzz_Revert_MulDiv(uint256 x, uint256 y, bool roundUp) public {
        vm.expectRevert(Math.Math__DivisionByZero.selector);
        x.mulDiv(y, 0, roundUp);
    }

    function test_Fuzz_Sqrt(uint256 x) public pure {
        x = bound(x, 0, type(uint256).max);

        uint256 yDown = x.sqrt(false);

        assertLe(yDown * yDown, x, "test_Fuzz_Sqrt::1");
        if (yDown < type(uint128).max) assertGt((yDown + 1) * (yDown + 1), x);

        uint256 yUp = x.sqrt(true);

        if (yUp < type(uint128).max) assertGe(yUp * yUp, x, "test_Fuzz_Sqrt::0");
        if (yUp > 0) assertLt((yUp - 1) * (yUp - 1), x);
    }

    function test_Add512(uint256 x0, uint256 x1, uint256 y0, uint256 y1) public pure {
        uint256 remainder = x0 > type(uint256).max - y0 ? 1 : 0;

        x1 = bound(x1, 0, type(uint256).max - remainder);
        y1 = bound(y1, 0, type(uint256).max - remainder - x1);

        (uint256 z0, uint256 z1) = Math.add512(x0, x1, y0, y1);

        unchecked {
            assertEq(z0, x0 + y0, "test_Add512::1");
        }

        assertEq(z1, x1 + y1 + remainder, "test_Add512::2");
    }

    function test_Revert_Add512(uint256 x0, uint256 x1, uint256 y0, uint256 y1) public {
        y1 = bound(y1, type(uint256).max - x1, type(uint256).max);
        y0 = bound(y0, type(uint256).max - x0, type(uint256).max);

        if (x1 == type(uint256).max - y1 && x0 == type(uint256).max - y0) {
            (x0, y0) = x0 == type(uint256).max ? (type(uint256).max, 1) : (x0 + 1, y0);
        }

        vm.expectRevert(Math.Math__UnderOverflow.selector);
        Math.add512(x0, x1, y0, y1);
    }

    function test_Fuzz_Sqrt512(uint256 x, uint256 y) public pure {
        (uint256 xy0, uint256 xy1) = Math.mul512(x, y);

        uint256 sxyDown = Math.sqrt512(xy0, xy1, false);
        uint256 sxyUp = Math.sqrt512(xy0, xy1, true);

        (uint256 xyDown0, uint256 xyDown1) = Math.mul512(sxyDown, sxyDown);
        (uint256 xyUp0, uint256 xyUp1) = Math.mul512(sxyUp, sxyUp);

        if (xyDown1 == xy1) {
            assertLe(xyDown0, xy0, "test_Fuzz_Sqrt512::1");
        } else {
            assertLe(xyDown1, xy1, "test_Fuzz_Sqrt512::2");
        }

        if (xyUp1 == xy1) {
            assertGe(xyUp0, xy0, "test_Fuzz_Sqrt512::3");
        } else {
            assertGe(xyUp1, xy1, "test_Fuzz_Sqrt512::4");
        }
    }

    function test_Revert_Sqrt512() public {
        vm.expectRevert(Math.Math__UnderOverflow.selector);
        Math.sqrt512(0, type(uint256).max, false);

        vm.expectRevert(Math.Math__UnderOverflow.selector);
        Math.sqrt512(0, type(uint256).max, true);
    }

    function OZMulDiv(uint256 x, uint256 y, uint256 z, bool roundUp) external pure returns (uint256) {
        return OZMath.mulDiv(x, y, z, roundUp ? OZMath.Rounding.Ceil : OZMath.Rounding.Floor);
    }
}
