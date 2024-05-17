// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

library Helper {
    error PricePoints__InvalidLength();
    error PricePoints__BidAskMismatch();
    error PricePoints__OnlyIncreasingPrices();
    error PricePoints__PriceTooHigh();
    error PricePoints__InvalidDecimals();
    error PricePoints__InvalidTotalSupply();

    uint256 constant MIN_LENGTH = 2;
    uint256 constant MAX_LENGTH = 100;
    uint256 constant MAX_PRICE = 1e36;
    uint256 constant MAX_DECIMALS = 18;

    function packPrices(uint256[] memory bidPrices, uint256[] memory askPrices)
        internal
        pure
        returns (uint256[] memory)
    {
        uint256 length = bidPrices.length;
        if (length != askPrices.length || length < MIN_LENGTH || length > MAX_LENGTH) {
            revert PricePoints__InvalidLength();
        }

        uint256[] memory packed = new uint256[](length);

        uint256 lastAskPrice;
        uint256 lastBidPrice;

        for (uint256 i; i < length; ++i) {
            uint256 askPrice = askPrices[i];
            uint256 bidPrice = bidPrices[i];

            if (bidPrice > askPrice) revert PricePoints__BidAskMismatch();

            if (i != 0 && (askPrice <= lastAskPrice || bidPrice <= lastBidPrice)) {
                revert PricePoints__OnlyIncreasingPrices();
            }

            packed[i] = (askPrice << 128) | bidPrice;

            lastAskPrice = askPrice;
            lastBidPrice = bidPrice;
        }

        if (lastAskPrice > MAX_PRICE) revert PricePoints__PriceTooHigh();

        return packed;
    }

    function getImmutableArgs(
        address baseToken,
        address quoteToken,
        uint256 totalSupply,
        uint256[] memory bidPrices,
        uint256[] memory askPrices
    ) internal view returns (bytes memory) {
        uint256[] memory packed = packPrices(bidPrices, askPrices);

        uint256 length = packed.length;
        uint256 nbIntervals = length - 1;

        (uint256 basePrecision, uint256 quotePrecision) = getTokensPrecision(baseToken, quoteToken);

        uint256 width = totalSupply / nbIntervals;
        uint256 widthScaled = width * 1e18 / basePrecision;

        if (widthScaled < basePrecision || totalSupply > type(uint128).max || width * nbIntervals != totalSupply) {
            revert PricePoints__InvalidTotalSupply();
        }

        bytes memory args = abi.encodePacked(
            baseToken,
            quoteToken,
            uint64(basePrecision),
            uint64(quotePrecision),
            uint128(totalSupply),
            uint128(widthScaled),
            uint16(length),
            packed
        );

        return args;
    }

    function getTokensPrecision(address baseToken, address quoteToken)
        internal
        view
        returns (uint256 basePrecision, uint256 quotePrecision)
    {
        uint256 baseDecimals = IERC20Metadata(baseToken).decimals();
        uint256 quoteDecimals = IERC20Metadata(quoteToken).decimals();

        if (baseDecimals > MAX_DECIMALS || quoteDecimals > MAX_DECIMALS) revert PricePoints__InvalidDecimals();

        basePrecision = 10 ** baseDecimals;
        quotePrecision = 10 ** quoteDecimals;

        return (basePrecision, quotePrecision);
    }
}
