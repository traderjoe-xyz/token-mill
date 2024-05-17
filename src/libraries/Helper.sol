// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

library Helper {
    error PricePoints__InvalidLength();
    error PricePoints__BidAskMismatch();
    error PricePoints__OnlyIncreasingPrices();
    error PricePoints__PriceTooHigh();

    uint256 constant MAX_PRICE = 1e36;

    function packPrices(uint256[] memory bidPrices, uint256[] memory askPrices)
        internal
        pure
        returns (uint256[] memory)
    {
        uint256 length = bidPrices.length;
        if (length != askPrices.length || length < 2 || length > 100) revert PricePoints__InvalidLength();

        uint256[] memory packed = new uint256[](length);

        uint256 lastAskPrice;
        uint256 lastBidPrice;

        for (uint256 i; i < length; ++i) {
            uint256 askPrice = askPrices[i];
            uint256 bidPrice = bidPrices[i];

            if (bidPrice > askPrice) revert PricePoints__BidAskMismatch();
            if (askPrice > MAX_PRICE) revert PricePoints__PriceTooHigh();

            if (i != 0 && (askPrice <= lastAskPrice || bidPrice <= lastBidPrice)) {
                revert PricePoints__OnlyIncreasingPrices();
            }

            packed[i] = (askPrice << 128) | bidPrice;

            lastAskPrice = askPrice;
            lastBidPrice = bidPrice;
        }

        return packed;
    }
}
