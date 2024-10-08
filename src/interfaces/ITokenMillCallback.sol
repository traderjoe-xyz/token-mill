// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title Token Mill Callback Interface
 * @dev Interface of the token mill callback contract.
 * The function is called by the token mill contract after a swap if data is provided.
 */
interface ITokenMillCallback {
    function tokenMillSwapCallback(int256 deltaBaseAmount, int256 deltaQuoteAmount, bytes calldata data)
        external
        returns (bytes32);
}
