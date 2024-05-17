// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IPricePoints} from "./IPricePoints.sol";

interface ITMMarket is IPricePoints {
    error Market__ZeroAmount();
    error Market__InsufficientAmount();
    error Market__InvalidSwapCallback();
    error Market__ReentrantCall();
    error Market__InvalidRecipient();
    error Market__OnlyFactory();
    error Market__InvalidCaller();

    event Swap(address indexed sender, address indexed recipient, int256 deltaBaseAmount, int256 deltaQuoteAmount);
    event FeesClaimed(address indexed caller, address indexed recipient, uint256 fees);

    function getBaseToken() external pure returns (address);

    function getQuoteToken() external pure returns (address);

    function getCirculatingSupply() external view returns (uint256);

    function getTotalSupply() external pure returns (uint256);

    function getPriceAt(uint256 circulatingSupply, bool bid) external pure returns (uint256);

    function getPricePoints(bool bid) external pure returns (uint256[] memory);

    function getPendingFees() external view returns (uint256 protocolFees, uint256 creatorFees);

    function swap(address recipient, int256 deltaAmount, bool fillBid, bytes calldata data)
        external
        returns (int256 deltaBaseAmount, int256 deltaQuoteAmount);

    function claimFees(address caller, address recipient) external returns (uint256 fees);
}
