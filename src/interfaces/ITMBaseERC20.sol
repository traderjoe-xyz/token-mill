// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title Base Token Interface
 * @dev Interface followed by all tokens created by the factory.
 */
interface ITMBaseERC20 is IERC20 {
    function initialize(string memory name, string memory symbol, bytes calldata args) external;

    function factory() external view returns (address);

    function factoryMint(address to, uint256 amount) external;
}
