// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title Packed Route Library
 * @dev Library for handling packed routes.
 * The packed route is a bytes array where:
 * - The first 20 bytes are the first token.
 * - The next 4 bytes are the id of the first pair.
 * - The next 20 bytes are the second token.
 * - The next 4 bytes are the id of the second pair.
 * - ...
 * - The last 20 bytes are the last token.
 * The packed route can be calculated as follows:
 * packedRoute = abi.encodePacked(token1, id1_2, token2, id2_3, ..., tokenN-1, idN-1_N, tokenN)
 * The id is a uint32 where:
 * - The first 8 bits are the major version.
 * - The next 8 bits are the minor version.
 * - The last 16 bits are the type.
 */
library PackedRoute {
    error PackedRoute__InvalidId();
    error PackedRoute__InvalidRoute();

    /**
     * @dev Get the length of a packed route. Will return the number of tokens in the route.
     * @param route Packed route.
     * @return l Length of the route.
     */
    function length(bytes memory route) internal pure returns (uint256 l) {
        l = route.length;
        if (l < 44 || l % 24 != 20) revert PackedRoute__InvalidRoute();

        assembly ("memory-safe") {
            l := add(div(l, 24), 1)
        }
    }

    /**
     * @dev Get the first token of a packed route.
     * @param route Packed route.
     * @return token First token of the route.
     */
    function first(bytes memory route) internal pure returns (address token) {
        uint256 l = route.length;
        if (l < 44 || l % 24 != 20) revert PackedRoute__InvalidRoute();

        assembly ("memory-safe") {
            token := shr(96, mload(add(route, 32)))
        }
    }

    /**
     * @dev Get the last token of a packed route.
     * @param route Packed route.
     * @return token Last token of the route.
     */
    function last(bytes memory route) internal pure returns (address token) {
        uint256 l = route.length;
        if (l < 44 || l % 24 != 20) revert PackedRoute__InvalidRoute();

        assembly ("memory-safe") {
            token := shr(96, mload(add(route, add(l, 12))))
        }
    }

    /**
     * @dev Get the token at the specified index of a packed route.
     * This function doesn't check that the index is within bounds. It should be done by the parent function.
     * @param route Packed route.
     * @param index Index of the token.
     * @return token Token at the specified index.
     */
    function at(bytes memory route, uint256 index) internal pure returns (address token) {
        assembly ("memory-safe") {
            token := shr(96, mload(add(route, add(32, mul(index, 24)))))
        }
    }

    /**
     * @dev Get the id at the specified index of a packed route.
     * This function doesn't check that the index is within bounds. It should be done by the parent function.
     * @param route Packed route.
     * @param index Index of the id.
     * @return i Id at the specified index.
     */
    function id(bytes memory route, uint256 index) internal pure returns (uint256 i) {
        assembly ("memory-safe") {
            i := shr(224, mload(add(route, add(52, mul(index, 24)))))
        }
    }

    /**
     * @dev Encode an id into a packed id.
     * The packed id is a uint32 where:
     * - The first 8 bits are the major version.
     * - The next 8 bits are the minor version.
     * - The last 16 bits are the type.
     * The packed id can be calculated as follows:
     * packedId = (v << 24) | (sv << 16) | t
     * @param v The major version.
     * @param sv The minor version.
     * @param t The type.
     * @return i Packed id.
     */
    function encodeId(uint256 v, uint256 sv, uint256 t) internal pure returns (uint32 i) {
        if (v > type(uint8).max || sv > type(uint8).max || t > type(uint16).max) revert PackedRoute__InvalidId();

        assembly ("memory-safe") {
            i := or(or(shl(24, v), shl(16, sv)), t)
        }
    }

    /**
     * @dev Decode a packed id into its components.
     * The packed id is a uint32 where:
     * - The first 8 bits are the major version.
     * - The next 8 bits are the minor version.
     * - The last 16 bits are the type.
     * @param i Packed id.
     * @return v Major version.
     * @return sv Minor version.
     * @return t Type.
     */
    function decodeId(uint256 i) internal pure returns (uint256 v, uint256 sv, uint256 t) {
        if (i > type(uint32).max) revert PackedRoute__InvalidId();

        assembly ("memory-safe") {
            v := and(shr(24, i), 0xff)
            sv := and(shr(16, i), 0xff)
            t := and(i, 0xffff)
        }
    }
}
