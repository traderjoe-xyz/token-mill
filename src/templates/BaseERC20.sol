// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";

import {IBaseToken} from "../interfaces/IBaseToken.sol";

/**
 * @title Base ERC20 Contract
 * @dev Base ERC20 contract following the IBaseToken interface.
 */
abstract contract BaseERC20 is ERC20Upgradeable, IBaseToken {
    error BaseERC20__OnlyFactory();

    address private immutable _factory;

    /**
     * @dev Initializes the contract.
     * @param factory_ The address of the factory contract.
     */
    constructor(address factory_) {
        _factory = factory_;
    }

    /**
     * @dev Initializes the contract.
     * @param name_ The name of the token.
     * @param symbol_ The symbol of the token.
     * @param args The arguments to be passed to the contract.
     */
    function initialize(string memory name_, string memory symbol_, bytes calldata args)
        external
        override
        initializer
    {
        __ERC20_init(name_, symbol_);

        _initialize(args);
    }

    /**
     * @dev Returns the address of the factory contract.
     */
    function factory() public view override returns (address) {
        return _factory;
    }

    /**
     * @dev Mints tokens to the specified address.
     * @param to The address to which the tokens will be minted.
     * @param amount The amount of tokens to be minted.
     */
    function factoryMint(address to, uint256 amount) external {
        if (msg.sender != _factory) revert BaseERC20__OnlyFactory();
        _mint(to, amount);
    }

    /**
     * @dev Initializes the contract.
     * @param args The arguments to be passed to the contract.
     */
    function _initialize(bytes calldata args) internal virtual {}
}
