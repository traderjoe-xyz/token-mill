// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";

import "../../src/libraries/PackedRoute.sol";

contract PackedRouteTest is Test {
    function test_Fuzz_Id(uint256 v, uint256 sv, uint256 t) public pure {
        v = bound(v, 0, type(uint8).max);
        sv = bound(sv, 0, type(uint8).max);
        t = bound(t, 0, type(uint16).max);

        uint256 id = PackedRoute.encodeId(v, sv, t);
        assertEq(uint256(id), (v << 24) | (sv << 16) | t, "test_Fuzz_Id::1");

        (uint256 v_, uint256 sv_, uint256 t_) = PackedRoute.decodeId(id);

        assertEq(v_, v, "test_Fuzz_Id::2");
        assertEq(sv_, sv, "test_Fuzz_Id::3");
        assertEq(t_, t, "test_Fuzz_Id::4");
    }

    function test_Fuzz_Revert_Id(uint256 v, uint256 sv, uint256 t, uint256 i) public {
        v = bound(v, uint256(type(uint8).max) + 1, type(uint256).max);
        sv = bound(sv, uint256(type(uint8).max) + 1, type(uint256).max);
        t = bound(t, uint256(type(uint16).max) + 1, type(uint256).max);
        i = bound(i, uint256(type(uint32).max) + 1, type(uint256).max);

        vm.expectRevert(PackedRoute.PackedRoute__InvalidId.selector);
        PackedRoute.encodeId(v, 0, 0);

        vm.expectRevert(PackedRoute.PackedRoute__InvalidId.selector);
        PackedRoute.encodeId(0, sv, 0);

        vm.expectRevert(PackedRoute.PackedRoute__InvalidId.selector);
        PackedRoute.encodeId(0, 0, t);

        vm.expectRevert(PackedRoute.PackedRoute__InvalidId.selector);
        PackedRoute.encodeId(v, sv, 0);

        vm.expectRevert(PackedRoute.PackedRoute__InvalidId.selector);
        PackedRoute.encodeId(0, sv, t);

        vm.expectRevert(PackedRoute.PackedRoute__InvalidId.selector);
        PackedRoute.encodeId(v, 0, t);

        vm.expectRevert(PackedRoute.PackedRoute__InvalidId.selector);
        PackedRoute.encodeId(v, sv, t);

        vm.expectRevert(PackedRoute.PackedRoute__InvalidId.selector);
        PackedRoute.decodeId(i);
    }

    function test_Fuzz_Length(uint256 l) public pure {
        l = bound(l, 1, 10);

        bytes memory route = new bytes(20 + l * 24);
        assertEq(PackedRoute.length(route), l + 1, "test_Fuzz_Length::1");
    }

    function test_Fuzz_Revert_Length(uint256 l) public {
        l = bound(l, 0, 256);
        if (l >= 44 && l % 24 == 20) ++l;

        bytes memory route = new bytes(l);
        vm.expectRevert(PackedRoute.PackedRoute__InvalidRoute.selector);
        PackedRoute.length(route);
    }

    function test_Fuzz_FirstAndLast(address token0, address token1) public pure {
        bytes memory route = abi.encodePacked(token0, PackedRoute.encodeId(0, 0, 0), token1);
        vm.toString(route);

        assertEq(PackedRoute.first(route), token0, "test_Fuzz_FirstAndLast::1");
        assertEq(PackedRoute.last(route), token1, "test_Fuzz_FirstAndLast::2");
    }

    function test_Revert_FirstAndLast(uint256 l) public {
        l = bound(l, 0, 256);
        if (l >= 44 && l % 24 == 20) ++l;

        bytes memory route = new bytes(l);

        vm.expectRevert(PackedRoute.PackedRoute__InvalidRoute.selector);
        PackedRoute.first(route);

        vm.expectRevert(PackedRoute.PackedRoute__InvalidRoute.selector);
        PackedRoute.last(route);
    }

    function test_Fuzz_AtAndId(address[] memory tokens, uint32[] memory ids) public pure {
        vm.assume(tokens.length > 2 && ids.length > 1);

        uint256 lt = tokens.length - 1;
        uint256 li = ids.length;

        uint256 length = lt > li ? li : lt;
        length = length > 10 ? 10 : length;

        bytes memory route = abi.encodePacked(tokens[0], ids[0]);
        for (uint256 i = 1; i < length; ++i) {
            route = abi.encodePacked(route, tokens[i], ids[i]);
        }
        route = abi.encodePacked(route, tokens[length]);

        for (uint256 i = 0; i < length; ++i) {
            assertEq(PackedRoute.at(route, i), tokens[i], "test_Fuzz_AtAndId::1");
            assertEq(PackedRoute.at(route, i + 1), tokens[i + 1], "test_Fuzz_AtAndId::2");
            assertEq(PackedRoute.id(route, i), ids[i], "test_Fuzz_AtAndId::3");
        }
    }
}
