// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

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
    error Router__InsufficientReceivedBase();
    error Router__InvalidCreateTMMarketAndVestingInputs();
    error Router__InvalidVestingAllocation();

    struct TMMarketCreationAndPurchaseArgs {
        uint96 tokenType;
        string name;
        string symbol;
        address quoteToken;
        uint256 totalSupply;
        uint256[] bidPrices;
        uint256[] askPrices;
        bytes args;
        uint128 quoteTokenAmountIn;
        uint256 baseTokenAmountOutMin;
    }

    struct VestingArgs {
        address beneficiary;
        uint16 percentageAmountBps;
        uint80 start;
        uint80 cliffDuration;
        uint80 vestingDuration;
    }

    function getFactory(uint256 v, uint256 sv) external view returns (address);

    function getWNative() external view returns (address);

    function swapExactIn(bytes memory route, address to, uint256 amountIn, uint256 amountOutMin, uint256 deadline)
        external
        payable
        returns (uint256, uint256);

    function swapExactInSupportingFeeOnTransferTokens(
        bytes memory route,
        address to,
        uint256 amountIn,
        uint256 amountOutMin,
        uint256 deadline
    ) external payable returns (uint256, uint256);

    function swapExactOut(bytes memory route, address to, uint256 amountOut, uint256 amountInMax, uint256 deadline)
        external
        payable
        returns (uint256, uint256);

    function simulate(bytes[] calldata routes, uint256 amount, bool exactIn) external payable;

    function simulateSingle(bytes calldata route, uint256 amount, bool exactIn) external payable;

    function createTMMarketAndVesting(
        TMMarketCreationAndPurchaseArgs memory args,
        address vestingContract,
        VestingArgs[] memory vestings
    ) external returns (address baseToken, address market, uint256 baseAmountReceived);
}
