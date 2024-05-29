// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";

import {IBaseToken} from "../interfaces/IBaseToken.sol";

contract BasicERC20 is ERC20Upgradeable, IBaseToken {
    error BasicERC20__InvalidArgsLength();
    error BasicERC20__OnlyFactory();

    address private immutable _factory;

    uint8 _decimals;

    constructor(address factory_) {
        _factory = factory_;
    }

    function initialize(string memory name, string memory symbol, bytes calldata args) external override initializer {
        if (args.length < 32) revert BasicERC20__InvalidArgsLength();

        __ERC20_init(name, symbol);
        _decimals = abi.decode(args, (uint8));
    }

    function factory() public view override returns (address) {
        return _factory;
    }

    function decimals() public view override returns (uint8) {
        return _decimals;
    }

    function factoryMint(address to, uint256 amount) external {
        if (msg.sender != _factory) revert BasicERC20__OnlyFactory();
        _mint(to, amount);
    }
}
