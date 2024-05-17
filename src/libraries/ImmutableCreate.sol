// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

library ImmutableCreate {
    error ImmutableContract__DeploymentFailed();
    error ImmutableContract__MaxLengthExceeded();

    function create2(bytes memory runtimecode, bytes memory immutableArgs, bytes32 salt) internal returns (address c) {
        bytes memory code = bytes.concat(runtimecode, immutableArgs);

        uint256 runtimecodeLength = runtimecode.length;
        uint256 codeLength = code.length;

        if (codeLength > 0xfffd) revert ImmutableContract__MaxLengthExceeded();

        assembly {
            let memEnd := mload(add(code, codeLength))

            let size := add(codeLength, 0x0c) // 10 bytes for the creation code and 2 bytes for the offset of the immutable args

            let creationCode := or(0x6100003d81600a3d39f3, shl(0x38, add(codeLength, 0x02)))

            mstore(code, creationCode)
            mstore(add(add(code, codeLength), 0x20), shl(0xf0, runtimecodeLength))

            c := create2(0, add(code, 0x16), size, salt)

            mstore(add(code, codeLength), memEnd) // restore the memory
        }

        if (c == address(0)) revert ImmutableContract__DeploymentFailed();
    }
}
