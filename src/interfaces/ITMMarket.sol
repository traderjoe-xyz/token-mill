// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IPricePoints} from "./IPricePoints.sol";

/**
 * @title Market Interface
 * @dev Interface of the market contract.
 */
interface ITMMarket is IPricePoints {
    error TMMarket__ZeroAmount();
    error TMMarket__InsufficientAmount();
    error TMMarket__InvalidSwapCallback();
    error TMMarket__ReentrantCall();
    error TMMarket__InvalidRecipient();
    error TMMarket__OnlyFactory();
    error TMMarket__ReserveOverflow();

    event Swap(address indexed sender, address indexed recipient, int256 deltaBaseAmount, int256 deltaQuoteAmount);
    event FeesClaimed(address indexed caller, address indexed recipient, uint256 fees);

    function initialize() external;

    function getBaseToken() external pure returns (address);

    function getQuoteToken() external pure returns (address);

    function getCirculatingSupply() external view returns (uint256);

    function getTotalSupply() external pure returns (uint256);

    function getPriceAt(uint256 circulatingSupply, bool bid) external pure returns (uint256);

    function getPricePoints(bool bid) external pure returns (uint256[] memory);

    function getPendingFees() external view returns (uint256 protocolFees, uint256 creatorFees);

    function getDeltaAmounts(int256 deltaAmount, bool fillBid)
        external
        view
        returns (int256 deltaBaseAmount, int256 deltaQuoteAmount);

    function getReserves() external view returns (uint256 baseReserve, uint256 quoteReserve);

    function swap(address recipient, int256 deltaAmount, bool fillBid, bytes calldata data)
        external
        returns (int256 deltaBaseAmount, int256 deltaQuoteAmount);

    function claimFees(address caller, address recipient, bool isCreator, bool isProtocol)
        external
        returns (uint256 fees);
}
