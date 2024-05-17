// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract BasicERC20 is ERC20 {
    error BasicERC20__AlreadyInitialized();

    bool public initialized;

    constructor(string memory name, string memory symbol) ERC20(name, symbol) {}

    function initialize(address recipient, uint256 totalSupply) external {
        if (initialized) revert BasicERC20__AlreadyInitialized();
        initialized = true;

        _mint(recipient, totalSupply);
    }
}
