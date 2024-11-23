// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";

import {ImmutableContract} from "../../src/libraries/ImmutableContract.sol";
import {ImmutableCreate} from "../../src/libraries/ImmutableCreate.sol";

contract ImmutableContractTest is Test {
    function test_Fuzz_GetImmutableDataCreate(bytes memory data) public {
        bytes memory runtimecode = type(MockImmutableContract).runtimeCode;

        vm.assume((runtimecode.length + data.length) <= (type(uint16).max - 2));

        MockImmutableContract immutableContract = MockImmutableContract(ImmutableCreate.create(runtimecode, data));

        vm.expectRevert(ImmutableCreate.ImmutableCreate__DeploymentFailed.selector);
        this.create{gas: 100_000}(runtimecode, data);

        assertEq(uint256(immutableContract.getOffset()), runtimecode.length, "test_Fuzz_GetImmutableDataCreate::1");

        for (uint256 i; i < data.length; ++i) {
            assertEq(immutableContract.getUint(i, 8), uint8(data[i]), "test_Fuzz_GetImmutableDataCreate::2");
        }

        for (uint256 i; i < data.length / 20; ++i) {
            address value;

            assembly ("memory-safe") {
                value := shr(96, mload(add(data, add(32, mul(i, 20)))))
            }

            assertEq(immutableContract.getAddress(i * 20), value, "test_Fuzz_GetImmutableDataCreate::3");
        }

        for (uint256 i; i < data.length / 32; ++i) {
            uint256 value;

            assembly ("memory-safe") {
                value := mload(add(data, add(32, mul(i, 32))))
            }

            assertEq(immutableContract.getUint256(i * 32), value, "test_Fuzz_GetImmutableDataCreate::4");
        }

        assertEq(immutableContract.getUint(data.length, 16), runtimecode.length, "test_Fuzz_GetImmutableDataCreate::5");

        uint256 badLength = bound(data.length, type(uint16).max - runtimecode.length - 1, type(uint256).max);

        assembly ("memory-safe") {
            mstore(data, badLength)
        }

        vm.expectRevert(ImmutableCreate.ImmutableCreate__MaxLengthExceeded.selector);
        ImmutableCreate.create(runtimecode, data);
    }

    function test_Fuzz_GetImmutableDataCreate2(bytes memory data, bytes32 salt) public {
        bytes memory runtimecode = type(MockImmutableContract).runtimeCode;

        vm.assume((runtimecode.length + data.length) <= (type(uint16).max - 2));

        MockImmutableContract immutableContract =
            MockImmutableContract(ImmutableCreate.create2(runtimecode, data, salt));

        vm.expectRevert(ImmutableCreate.ImmutableCreate__DeploymentFailed.selector);
        this.create2(runtimecode, data, salt);

        assertEq(uint256(immutableContract.getOffset()), runtimecode.length, "test_Fuzz_GetImmutableDataCreate2::1");

        for (uint256 i; i < data.length; ++i) {
            assertEq(immutableContract.getUint(i, 8), uint8(data[i]), "test_Fuzz_GetImmutableDataCreate2::2");
        }

        for (uint256 i; i < data.length / 20; ++i) {
            address value;

            assembly ("memory-safe") {
                value := shr(96, mload(add(data, add(32, mul(i, 20)))))
            }

            assertEq(immutableContract.getAddress(i * 20), value, "test_Fuzz_GetImmutableDataCreate2::3");
        }

        for (uint256 i; i < data.length / 32; ++i) {
            uint256 value;

            assembly ("memory-safe") {
                value := mload(add(data, add(32, mul(i, 32))))
            }

            assertEq(immutableContract.getUint256(i * 32), value, "test_Fuzz_GetImmutableDataCreate2::4");
        }

        assertEq(immutableContract.getUint(data.length, 16), runtimecode.length, "test_Fuzz_GetImmutableDataCreate2::5");

        uint256 badLength = bound(data.length, type(uint16).max - runtimecode.length - 1, type(uint256).max);

        assembly ("memory-safe") {
            mstore(data, badLength)
        }

        vm.expectRevert(ImmutableCreate.ImmutableCreate__MaxLengthExceeded.selector);
        ImmutableCreate.create2(runtimecode, data, 0);
    }

    function create(bytes memory runtimecode, bytes memory immutableArgs) external returns (address) {
        return ImmutableCreate.create(runtimecode, immutableArgs);
    }

    function create2(bytes memory runtimecode, bytes memory immutableArgs, bytes32 salt) external returns (address) {
        return ImmutableCreate.create2(runtimecode, immutableArgs, salt);
    }
}

contract MockImmutableContract is ImmutableContract {
    function getOffset() public pure returns (bytes32) {
        return _getOffset();
    }

    function getAddress(uint256 argOffset) public pure returns (address) {
        return _getAddress(argOffset);
    }

    function getUint256(uint256 argOffset) public pure returns (uint256) {
        return _getUint256(argOffset);
    }

    function getUint(uint256 argOffset, uint8 size) public pure returns (uint256) {
        return _getUint(argOffset, size);
    }
}
