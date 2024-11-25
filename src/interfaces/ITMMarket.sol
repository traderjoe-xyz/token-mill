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
    error TMMarket__InvalidFees();
    error TMMarket__AlreadyInitialized();
    error TMMarket__InvalidCirculatingSupply();

    struct Fees {
        uint256 creatorFees;
        uint256 stakingFees;
        uint256 protocolFees;
        uint256 referrerFees;
    }

    event Swap(
        address indexed sender, address indexed recipient, int256 deltaBaseAmount, int256 deltaQuoteAmount, Fees fees
    );
    event FeesClaimed(address indexed token, address indexed caller, uint256 claimedFees);

    function initialize() external;

    function getFactory() external pure returns (address);

    function getBaseToken() external pure returns (address);

    function getQuoteToken() external pure returns (address);

    function getCirculatingSupply() external view returns (uint256);

    function getTotalSupply() external pure returns (uint256);

    function getPriceAt(uint256 circulatingSupply, bool bid) external pure returns (uint256);

    function getPricePoints(bool bid) external pure returns (uint256[] memory);

    function getPendingFees() external view returns (uint256 creatorFees, uint256 stakingFees);

    function getDeltaAmounts(int256 deltaAmount, bool swapB2Q)
        external
        view
        returns (int256 deltaBaseAmount, int256 deltaQuoteAmount, uint256 quoteFees);

    function getReserves() external view returns (uint256 baseReserve, uint256 quoteReserve);

    function swap(address recipient, int256 deltaAmount, bool swapB2Q, bytes calldata data, address referrer)
        external
        returns (int256 deltaBaseAmount, int256 deltaQuoteAmount);

    function claimFees(address caller, address creator, address staking) external returns (uint256 claimedFees);
}
