// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title Wrapped Native Interface
 * @dev Interface of the wrapped native token.
 */
interface IWNative is IERC20 {
    function deposit() external payable;

    function withdraw(uint256 amount) external;
}
