// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";

contract BasicERC20 is ERC20Upgradeable {
    function initialize(string memory name, string memory symbol, address recipient, uint256 totalSupply)
        external
        initializer
    {
        __ERC20_init(name, symbol);
        _mint(recipient, totalSupply);
    }
}
