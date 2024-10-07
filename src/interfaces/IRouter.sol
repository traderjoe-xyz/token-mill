// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./ITMFactory.sol";

interface IRouter {
    error Router__OnlyWNative();
    error Router__InvalidMarket();
    error Router__InvalidRecipient();
    error Router__InsufficientOutputAmount();
    error Router__NativeTransferFailed();
    error Router__InvalidAmounts();
    error Router__ExceedsMaxInputAmount();
    error Router__InvalidId();
    error Router__ExceedsDeadline();
    error Router__InsufficientLiquidity();
    error Router__Simulation(uint256 amount);
    error Router__Simulations(uint256[] amounts);
    error Router__NoVestingParams();
    error Router__InvalidVestingPercents();
    error Router__InvalidVestingTotalPercents();
    error Router__TooManyQuoteTokenSent();

    struct VestingParameters {
        address beneficiary;
        uint256 percent;
        uint80 start;
        uint80 cliffDuration;
        uint80 endDuration;
    }

    function getFactory(uint256 v, uint256 sv) external view returns (address);

    function getStakingContract() external view returns (address);

    function getWNative() external view returns (address);

    function createTMMarketAndVestings(
        ITMFactory.MarketCreationParameters calldata params,
        VestingParameters[] calldata vestingParams,
        address referrer,
        uint256 amountQuoteIn,
        uint256 minAmountBaseOut
    ) external payable returns (address base, address market, uint256 amountBaseOut);

    function swapExactIn(
        bytes memory route,
        address to,
        uint256 amountIn,
        uint256 amountOutMin,
        uint256 deadline,
        address referrer
    ) external payable returns (uint256, uint256);

    function swapExactInSupportingFeeOnTransferTokens(
        bytes memory route,
        address to,
        uint256 amountIn,
        uint256 amountOutMin,
        uint256 deadline,
        address referrer
    ) external payable returns (uint256, uint256);

    function swapExactOut(
        bytes memory route,
        address to,
        uint256 amountOut,
        uint256 amountInMax,
        uint256 deadline,
        address referrer
    ) external payable returns (uint256, uint256);

    function simulate(bytes[] calldata routes, uint256 amount, bool exactIn) external payable;

    function simulateSingle(bytes calldata route, uint256 amount, bool exactIn) external payable;
}
