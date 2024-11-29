// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title Immutable Create
 * @dev Library for deploying contracts with immutable arguments.
 */
library ImmutableCreate {
    error ImmutableCreate__DeploymentFailed();
    error ImmutableCreate__MaxLengthExceeded();

    /**
     * @dev Create a new contract with the specified runtime code and immutable arguments.
     * It is very important that the contract doesn't have any constructor as it will be ignored.
     * If the contract needs to be initialized, it should be done using an `initialize` function.
     * @param runtimecode Runtime code of the contract.
     * @param immutableArgs Immutable arguments of the contract.
     * @return c Address of the deployed contract.
     */
    function create(bytes memory runtimecode, bytes memory immutableArgs) internal returns (address c) {
        uint256 runtimecodeLength = runtimecode.length;
        if (runtimecodeLength + immutableArgs.length > 0xfffd) revert ImmutableCreate__MaxLengthExceeded();

        bytes memory code = bytes.concat(runtimecode, immutableArgs);

        uint256 codeLength = code.length;

        assembly ("memory-safe") {
            let memEndSlot := add(add(code, codeLength), 0x20)
            let memEndValue := mload(memEndSlot)

            let size := add(codeLength, 0x0d) // 11 bytes for the creation code and 2 bytes for the offset of the immutable args

            let creationCode := or(0x610000600081600b8239f3, shl(0x40, add(codeLength, 0x02)))

            mstore(code, creationCode)
            mstore(memEndSlot, shl(0xf0, runtimecodeLength))

            c := create(0, add(code, 0x15), size)

            mstore(memEndSlot, memEndValue) // restore the memory
        }

        if (c == address(0)) revert ImmutableCreate__DeploymentFailed();
    }

    /**
     * @dev Create a new contract with the specified runtime code, immutable arguments, and salt.
     * It is very important that the contract doesn't have any constructor as it will be ignored.
     * If the contract needs to be initialized, it should be done using an `initialize` function.
     * @param runtimecode Runtime code of the contract.
     * @param immutableArgs Immutable arguments of the contract.
     * @param salt Salt for the contract creation.
     * @return c Address of the deployed contract.
     */
    function create2(bytes memory runtimecode, bytes memory immutableArgs, bytes32 salt) internal returns (address c) {
        uint256 runtimecodeLength = runtimecode.length;
        if (runtimecodeLength + immutableArgs.length > 0xfffd) revert ImmutableCreate__MaxLengthExceeded();

        bytes memory code = bytes.concat(runtimecode, immutableArgs);

        uint256 codeLength = code.length;

        assembly ("memory-safe") {
            let memEndSlot := add(add(code, codeLength), 0x20)
            let memEndValue := mload(memEndSlot)

            let size := add(codeLength, 0x0d) // 11 bytes for the creation code and 2 bytes for the offset of the immutable args

            let creationCode := or(0x610000600081600b8239f3, shl(0x40, add(codeLength, 0x02)))

            mstore(code, creationCode)
            mstore(memEndSlot, shl(0xf0, runtimecodeLength))

            c := create2(0, add(code, 0x15), size, salt)

            mstore(memEndSlot, memEndValue) // restore the memory
        }

        if (c == address(0)) revert ImmutableCreate__DeploymentFailed();
    }
}
