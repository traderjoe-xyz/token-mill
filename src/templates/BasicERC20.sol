// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {BaseERC20} from "./BaseERC20.sol";

contract BasicERC20 is BaseERC20 {
    error BasicERC20__InvalidArgsLength();

    uint8 _decimals;

    constructor(address factory_) BaseERC20(factory_) {}

    function _initialize(bytes calldata args) internal override {
        if (args.length < 32) revert BasicERC20__InvalidArgsLength();

        _decimals = abi.decode(args, (uint8));
    }

    function decimals() public view override returns (uint8) {
        return _decimals;
    }
}
