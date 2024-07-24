// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {TMBaseERC20} from "./TMBaseERC20.sol";

/**
 * @title Token Mill ERC20 Contract
 * @dev Basic ERC20 contract following the ITMBaseERC20 interface with custom number of decimals.
 */
contract TMERC20 is TMBaseERC20 {
    error TMERC20__InvalidArgsLength();

    uint8 _decimals;

    /**
     * @dev Initializes the contract.
     * @param factory_ The address of the factory contract.
     */
    constructor(address factory_) TMBaseERC20(factory_) {}

    /**
     * @dev Initializes the contract.
     * @param args The arguments to be passed to the contract containing at least the number of decimals.
     */
    function _initialize(bytes calldata args) internal override {
        if (args.length < 32) revert TMERC20__InvalidArgsLength();

        _decimals = abi.decode(args, (uint8));
    }

    /**
     * @dev Returns the number of decimals of the token.
     */
    function decimals() public view override returns (uint8) {
        return _decimals;
    }
}
