// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IPricePoints {
    error PricePoints__TotalSupplyExceeded();

    function getDeltaQuoteAmount(uint256 supply, int256 deltaBaseAmount)
        external
        view
        returns (int256 actualDeltaBaseAmount, int256 deltaQuoteAmount);

    function getDeltaBaseAmount(uint256 supply, int256 deltaQuoteAmount)
        external
        view
        returns (int256 deltaBaseAmount, int256 actualDeltaQuoteAmount);
}
