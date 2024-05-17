// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

abstract contract ImmutableContract {
    function _getAddress(uint256 argOffset) internal pure returns (address value) {
        bytes32 offset = _getOffset();

        assembly {
            codecopy(0, add(offset, argOffset), 0x20)
            value := shr(96, mload(0))
        }
    }

    function _getUint256(uint256 argOffset) internal pure returns (uint256 value) {
        bytes32 offset = _getOffset();

        assembly {
            codecopy(0, add(offset, argOffset), 0x20)
            value := mload(0)
        }
    }

    // size has to be a multiple of 8
    function _getUint(uint256 argOffset, uint8 size) internal pure returns (uint256 value) {
        bytes32 offset = _getOffset();

        assembly {
            codecopy(0, add(offset, argOffset), 0x20)
            value := shr(sub(256, size), mload(0))
        }
    }

    function _getOffset() internal pure returns (bytes32 offset) {
        assembly {
            let loc := sub(codesize(), 0x02)
            codecopy(0x00, loc, 0x20)

            offset := shr(0xf0, mload(0))
        }
    }
}
