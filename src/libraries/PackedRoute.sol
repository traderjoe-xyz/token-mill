// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

library PackedRoute {
    error PackedRoute__InvalidId();
    error PackedRoute__InvalidRoute();

    function length(bytes memory route) internal pure returns (uint256 l) {
        l = route.length;
        if (l < 44 || l % 24 != 20) revert PackedRoute__InvalidRoute();

        assembly {
            l := add(div(l, 24), 1)
        }
    }

    function first(bytes memory route) internal pure returns (address token) {
        uint256 l = route.length;
        if (l < 44 || l % 24 != 20) revert PackedRoute__InvalidRoute();

        assembly {
            token := shr(96, mload(add(route, 32)))
        }
    }

    function last(bytes memory route) internal pure returns (address token) {
        uint256 l = route.length;
        if (l < 44 || l % 24 != 20) revert PackedRoute__InvalidRoute();

        assembly {
            token := shr(96, mload(add(route, add(l, 12))))
        }
    }

    function at(bytes memory route, uint256 index) internal pure returns (address token) {
        assembly {
            token := shr(96, mload(add(route, add(32, mul(index, 24)))))
        }
    }

    function id(bytes memory route, uint256 index) internal pure returns (uint256 i) {
        assembly {
            i := shr(224, mload(add(route, add(52, mul(index, 24)))))
        }
    }

    function encodeId(uint256 v, uint256 sv, uint256 t) internal pure returns (uint32 i) {
        if (v > type(uint8).max || sv > type(uint8).max || t > type(uint16).max) revert PackedRoute__InvalidId();

        assembly {
            i := or(or(shl(24, v), shl(16, sv)), t)
        }
    }

    function decodeId(uint256 i) internal pure returns (uint256 v, uint256 sv, uint256 t) {
        if (i > type(uint32).max) revert PackedRoute__InvalidId();

        assembly {
            v := and(shr(24, i), 0xff)
            sv := and(shr(16, i), 0xff)
            t := and(i, 0xffff)
        }
    }
}
