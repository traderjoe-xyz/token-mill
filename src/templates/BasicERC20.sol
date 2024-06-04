// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {BaseERC20} from "./BaseERC20.sol";

/**
 * @title Basic ERC20 Contract
 * @dev Basic ERC20 contract following the IBaseToken interface.
 */
contract BasicERC20 is BaseERC20 {
    error BasicERC20__InvalidArgsLength();

    uint8 _decimals;

    /**
     * @dev Initializes the contract.
     * @param factory_ The address of the factory contract.
     */
    constructor(address factory_) BaseERC20(factory_) {}

    /**
     * @dev Initializes the contract.
     * @param args The arguments to be passed to the contract containing at least the number of decimals.
     */
    function _initialize(bytes calldata args) internal override {
        if (args.length < 32) revert BasicERC20__InvalidArgsLength();

        _decimals = abi.decode(args, (uint8));
    }

    /**
     * @dev Returns the number of decimals of the token.
     */
    function decimals() public view override returns (uint8) {
        return _decimals;
    }
}
