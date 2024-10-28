// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";

import {ITMBaseERC20} from "../interfaces/ITMBaseERC20.sol";

/**
 * @title Token Mill Base ERC20 Contract
 * @dev Token Mill Base ERC20 contract following the ITMBaseERC20 interface.
 * This contract makes sure that all Token Mill's ERC20 contracts are compliant with the Factory contract.
 */
abstract contract TMBaseERC20 is ERC20Upgradeable, ITMBaseERC20 {
    error TMBaseERC20__OnlyFactory();

    address private immutable _factory;

    /**
     * @dev Initializes the contract.
     * @param factory_ The address of the factory contract.
     */
    constructor(address factory_) {
        _disableInitializers();

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
        if (msg.sender != _factory) revert TMBaseERC20__OnlyFactory();
        _mint(to, amount);
    }

    /**
     * @dev Initializes the contract.
     * @param args The arguments to be passed to the contract.
     */
    function _initialize(bytes calldata args) internal virtual {}
}
