// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

/**
 * @title Immutable Helper Library
 * @dev Library for immutable contract initialization.
 */
library ImmutableHelper {
    error ImmutableHelper__InvalidLength(uint256 lengthBid, uint256 lengthAsk);
    error ImmutableHelper__BidAskMismatch(uint256 i, uint256 bidPrice, uint256 askPrice);
    error ImmutableHelper__OnlyIncreasingPrices(uint256 i);
    error ImmutableHelper__InvalidTotalSupply(uint256 totalSupply, uint256 nbIntervals);
    error ImmutableHelper__InvalidWidthScaled(uint256 widthScaled);
    error ImmutableHelper__InvalidDecimals(uint256 baseDecimals, uint256 quoteDecimals);
    error ImmutableHelper__LengthOutOfBounds(uint256 min, uint256 length, uint256 max);
    error ImmutableHelper__PriceTooHigh(uint256 askPrice, uint256 maxPrice);

    uint256 constant MIN_LENGTH = 2;
    uint256 constant MAX_LENGTH = 101;
    uint256 constant MAX_PRICE = 1e36;
    uint256 constant MAX_DECIMALS = 18;

    /**
     * @dev Pack bid and ask prices into a single array.
     * Each price is packed into a single uint256 as follows:
     * - The first 128 bits are the ask price.
     * - The last 128 bits are the bid price.
     * It can be calculated as follows:
     * packedPrice = (askPrice << 128) | bidPrice
     * @param bidPrices Bid prices.
     * @param askPrices Ask prices.
     * @return packedPrices Packed prices.
     */
    function packPrices(uint256[] memory bidPrices, uint256[] memory askPrices)
        internal
        pure
        returns (uint256[] memory)
    {
        uint256 length = bidPrices.length;
        if (length != askPrices.length || length < MIN_LENGTH || length > MAX_LENGTH) {
            revert ImmutableHelper__InvalidLength(length, askPrices.length);
        }

        uint256[] memory packedPrices = new uint256[](length);

        uint256 lastAskPrice;
        uint256 lastBidPrice;

        unchecked {
            for (uint256 i; i < length; ++i) {
                uint256 askPrice = askPrices[i];
                uint256 bidPrice = bidPrices[i];

                if (bidPrice > askPrice) revert ImmutableHelper__BidAskMismatch(i, bidPrice, askPrice);

                if (i != 0 && (askPrice <= lastAskPrice || bidPrice <= lastBidPrice)) {
                    revert ImmutableHelper__OnlyIncreasingPrices(i);
                }

                packedPrices[i] = (askPrice << 128) | bidPrice;

                lastAskPrice = askPrice;
                lastBidPrice = bidPrice;
            }
        }

        if (lastAskPrice > MAX_PRICE) revert ImmutableHelper__PriceTooHigh(lastAskPrice, MAX_PRICE);

        return packedPrices;
    }

    /**
     * @dev Get immutable arguments for the contract initialization.
     * @param factory Factory address.
     * @param baseToken Base token address.
     * @param quoteToken Quote token address.
     * @param totalSupply Total supply of the market.
     * @param packedPrices Packed prices. Use `packPrices` to pack bid and ask prices.
     * @return args Immutable arguments.
     */
    function getImmutableArgs(
        address factory,
        address baseToken,
        address quoteToken,
        uint256 totalSupply,
        uint256[] memory packedPrices
    ) internal view returns (bytes memory) {
        unchecked {
            uint256 length = packedPrices.length;
            if (length < MIN_LENGTH || length > MAX_LENGTH) {
                revert ImmutableHelper__LengthOutOfBounds(MIN_LENGTH, length, MAX_LENGTH);
            }

            uint256 nbIntervals = length - 1;

            (uint256 basePrecision, uint256 quotePrecision) = getTokensPrecision(baseToken, quoteToken);

            if (
                totalSupply / nbIntervals < basePrecision || totalSupply > type(uint128).max
                    || (totalSupply / nbIntervals) * nbIntervals != totalSupply
            ) {
                revert ImmutableHelper__InvalidTotalSupply(totalSupply, nbIntervals);
            }

            uint256 widthScaled = (totalSupply / nbIntervals) * 1e18 / basePrecision;

            if (widthScaled > type(uint128).max) revert ImmutableHelper__InvalidWidthScaled(widthScaled);

            bytes memory args = abi.encodePacked(
                factory,
                baseToken,
                quoteToken,
                uint64(basePrecision),
                uint64(quotePrecision),
                uint128(totalSupply),
                uint128(widthScaled),
                uint8(length),
                packedPrices
            );

            return args;
        }
    }

    /**
     * @dev Get the precision of the tokens.
     * @param baseToken Base token address.
     * @param quoteToken Quote token address.
     * @return basePrecision Precision of the base token.
     * @return quotePrecision Precision of the quote token.
     */
    function getTokensPrecision(address baseToken, address quoteToken)
        internal
        view
        returns (uint256 basePrecision, uint256 quotePrecision)
    {
        uint256 baseDecimals = IERC20Metadata(baseToken).decimals();
        uint256 quoteDecimals = IERC20Metadata(quoteToken).decimals();

        if (baseDecimals > MAX_DECIMALS || quoteDecimals > MAX_DECIMALS) {
            revert ImmutableHelper__InvalidDecimals(baseDecimals, quoteDecimals);
        }

        basePrecision = 10 ** baseDecimals;
        quotePrecision = 10 ** quoteDecimals;

        return (basePrecision, quotePrecision);
    }
}
