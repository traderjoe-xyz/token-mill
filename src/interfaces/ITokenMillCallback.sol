// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ITokenMillCallback {
    function tokenMillSwapCallback(int256 deltaBaseAmount, int256 deltaQuoteAmount, bytes calldata data)
        external
        returns (bytes32);
}
