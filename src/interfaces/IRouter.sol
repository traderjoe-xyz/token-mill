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
}
