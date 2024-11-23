// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title Immutable Contract
 * @dev Abstract contract that provides helper functions to read immutable data.
 */
abstract contract ImmutableContract {
    /**
     * @dev Get the address at the specified offset.
     * This function doesn't check that the argOffset is within bounds. It should be done by the parent function.
     * @param argOffset Offset of the address.
     * @return value Address at the specified offset.
     */
    function _getAddress(uint256 argOffset) internal pure returns (address value) {
        bytes32 offset = _getOffset();

        assembly ("memory-safe") {
            codecopy(0, add(offset, argOffset), 0x20)
            value := shr(96, mload(0))
        }
    }

    /**
     * @dev Get the uint256 at the specified offset.
     * This function doesn't check that the argOffset is within bounds. It should be done by the parent function.
     * @param argOffset Offset of the uint256.
     * @return value uint256 at the specified offset.
     */
    function _getUint256(uint256 argOffset) internal pure returns (uint256 value) {
        bytes32 offset = _getOffset();

        assembly ("memory-safe") {
            codecopy(0, add(offset, argOffset), 0x20)
            value := mload(0)
        }
    }

    /**
     * @dev Get the uint at the specified offset.
     * This function doesn't check that the argOffset is within bounds. It should be done by the parent function.
     * @param argOffset Offset of the uint.
     * @param size Size of the uint.
     * @return value uint at the specified offset.
     */
    function _getUint(uint256 argOffset, uint8 size) internal pure returns (uint256 value) {
        bytes32 offset = _getOffset();

        assembly ("memory-safe") {
            codecopy(0, add(offset, argOffset), 0x20)
            value := shr(sub(256, size), mload(0))
        }
    }

    /**
     * @dev Get the offset of the contract. The offset is where the immutable data starts.
     * @return offset Offset of the contract.
     */
    function _getOffset() internal pure returns (bytes32 offset) {
        assembly ("memory-safe") {
            let loc := sub(codesize(), 0x02)
            codecopy(0x00, loc, 0x20)

            offset := shr(0xf0, mload(0))
        }
    }
}
