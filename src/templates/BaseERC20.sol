// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";

import {IBaseToken} from "../interfaces/IBaseToken.sol";

abstract contract BaseERC20 is ERC20Upgradeable, IBaseToken {
    error BaseERC20__OnlyFactory();

    address private immutable _factory;

    constructor(address factory_) {
        _factory = factory_;
    }

    function initialize(string memory name_, string memory symbol_, bytes calldata args)
        external
        override
        initializer
    {
        __ERC20_init(name_, symbol_);

        _initialize(args);
    }

    function factory() public view override returns (address) {
        return _factory;
    }

    function factoryMint(address to, uint256 amount) external {
        if (msg.sender != _factory) revert BaseERC20__OnlyFactory();
        _mint(to, amount);
    }

    function _initialize(bytes calldata args) internal virtual;
}
