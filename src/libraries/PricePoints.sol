// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Math} from "./Math.sol";
import {IPricePoints} from "../interfaces/IPricePoints.sol";

/**
 * @title Price Points Abstract Contract
 * @dev Abstract contract that provides helper functions to calculate prices and amounts.
 * This contract is used to calculate how much of one token can be bought/sold for another token following
 * a price curve defined by price points.
 * The curve is defined by a series of price points. Between each price point, the price is linearly interpolated.
 * The price points are defined by the price of the base token in the quote token in 1e18, without decimals.
 * For example, if the price of 1 base token (12 decimals) is 1 quote tokens (6 decimals), the price point is 1e18.
 * Each segment of the curve will contain `width = totalSupply / (pricePoints.length - 1)` base tokens.
 * When the segment is fully bought/sold, the prices will move to the next/previous price points.
 */
abstract contract PricePoints is IPricePoints {
    /**
     * @dev Returns the amount of quote tokens that should be sent (< 0) or received (> 0) for the specified base amount.
     * @param supply The current supply of the base token.
     * @param deltaBaseAmount The amount of base tokens to be sent (< 0) or received (> 0).
     * @return actualDeltaBaseAmount The actual amount of base tokens to be sent (< 0) or received (> 0).
     * @return deltaQuoteAmount The amount of quote tokens to be sent (< 0) or received (> 0).
     */
    function getDeltaQuoteAmount(uint256 supply, int256 deltaBaseAmount)
        public
        view
        override
        returns (int256 actualDeltaBaseAmount, int256 deltaQuoteAmount)
    {
        if (deltaBaseAmount == 0) return (0, 0);

        bool exactOut = deltaBaseAmount < 0;

        (uint256 circSupply, uint256 base) = exactOut
            ? (supply, uint256(-deltaBaseAmount))
            : (supply - uint256(deltaBaseAmount), uint256(deltaBaseAmount));

        (uint256 baseAmount, uint256 quoteAmount) = _getQuoteAmount(circSupply, base, exactOut, exactOut);

        if ((baseAmount | quoteAmount) > uint256(type(int256).max)) revert PricePoints__OverflowInt256();

        return deltaBaseAmount > 0
            ? (int256(baseAmount), -int256(quoteAmount))
            : (-int256(baseAmount), int256(quoteAmount));
    }

    /**
     * @dev Returns the amount of base tokens that should be sent (< 0) or received (> 0) for the specified quote amount.
     * @param supply The current supply of the base token.
     * @param deltaQuoteAmount The amount of quote tokens to be sent (< 0) or received (> 0).
     * @return deltaBaseAmount The amount of base tokens to be sent (< 0) or received (> 0).
     * @return actualDeltaQuoteAmount The actual amount of quote tokens to be sent (< 0) or received (> 0).
     */
    function getDeltaBaseAmount(uint256 supply, int256 deltaQuoteAmount)
        public
        view
        override
        returns (int256 deltaBaseAmount, int256 actualDeltaQuoteAmount)
    {
        if (deltaQuoteAmount == 0) return (0, 0);

        uint256 baseAmount;
        uint256 quoteAmount;
        if (deltaQuoteAmount > 0) {
            (baseAmount, quoteAmount) = _getBaseAmountOut(supply, uint256(deltaQuoteAmount));
            (deltaBaseAmount, actualDeltaQuoteAmount) = (-int256(baseAmount), int256(quoteAmount));
        } else {
            (baseAmount, quoteAmount) = _getBaseAmountIn(supply, uint256(-deltaQuoteAmount));
            (deltaBaseAmount, actualDeltaQuoteAmount) = (int256(baseAmount), -int256(quoteAmount));
        }

        if ((baseAmount | quoteAmount) > uint256(type(int256).max)) revert PricePoints__OverflowInt256();
    }

    /**
     * @dev Returns the amount of base tokens and quote tokens that should be sent (exactOut) or received (!exactOut)
     * @param supply The current supply of the base token.
     * @param baseAmount The amount of base tokens to be sent (exactOut) or received (!exactOut).
     * @param exactOut Whether the base amount is expected to be sent (true) or received (false).
     * @param roundUp Whether to round up the quote amount.
     * @return actualBaseAmount The actual amount of base tokens to be sent (exactOut) or received (!exactOut).
     * @return quoteAmount The amount of quote tokens to be sent (exactOut) or received (!exactOut).
     */
    function _getQuoteAmount(uint256 supply, uint256 baseAmount, bool exactOut, bool roundUp)
        internal
        view
        returns (uint256 actualBaseAmount, uint256 quoteAmount)
    {
        if (supply > _totalSupply()) revert PricePoints__TotalSupplyExceeded();

        uint256 length = _pricePointsLength();

        uint256 basePrecision = _basePrecision();
        uint256 widthScaled = _widthScaled();

        uint256 scaledSupply = supply * 1e18 / basePrecision;
        actualBaseAmount = baseAmount;

        baseAmount = baseAmount * 1e18 / basePrecision;

        uint256 i = scaledSupply / widthScaled;
        scaledSupply = scaledSupply % widthScaled;

        uint256 p0 = _pricePoints(i, exactOut);

        while (baseAmount > 0 && ++i < length) {
            uint256 p1 = _pricePoints(i, exactOut);

            uint256 deltaBase = Math.min(baseAmount, widthScaled - scaledSupply);
            uint256 deltaQuote = Math.mulDiv(
                deltaBase,
                (p1 - p0) * (deltaBase + 2 * scaledSupply) + 2 * p0 * widthScaled,
                2e18 * widthScaled,
                roundUp
            );

            quoteAmount += deltaQuote;
            baseAmount -= deltaBase;

            scaledSupply = 0;
            p0 = p1;
        }

        return (
            actualBaseAmount - Math.div((baseAmount) * basePrecision, 1e18, roundUp),
            Math.div(quoteAmount * _quotePrecision(), 1e18, roundUp)
        );
    }

    /**
     * @dev Returns the amount of base tokens that should be sent and the quote amount that should be received for the
     * specified quote amount.
     * @param supply The current supply of the base token.
     * @param quoteAmount The amount of quote tokens to be received.
     * @return baseAmount The amount of base tokens to be sent.
     * @return actualQuoteAmount The actual amount of quote tokens to be received.
     */
    function _getBaseAmountOut(uint256 supply, uint256 quoteAmount)
        internal
        view
        returns (uint256 baseAmount, uint256 actualQuoteAmount)
    {
        if (supply > _totalSupply()) revert PricePoints__TotalSupplyExceeded();

        uint256 length = _pricePointsLength();

        uint256 basePrecision = _basePrecision();
        uint256 quotePrecision = _quotePrecision();

        uint256 widthScaled = _widthScaled();

        uint256 supplyScaled = supply * 1e18 / basePrecision;
        uint256 remainingQuote = quoteAmount * 1e18 / quotePrecision;

        uint256 i = supplyScaled / widthScaled;
        uint256 base = supplyScaled % widthScaled;

        uint256 p0 = _pricePoints(i, true);

        while (remainingQuote > 0 && ++i < length) {
            uint256 p1 = _pricePoints(i, true);

            (uint256 deltaBase, uint256 deltaQuote) = _getDeltaBaseOut(p0, p1, widthScaled, base, remainingQuote);

            baseAmount += deltaBase;
            remainingQuote -= deltaQuote;

            base = 0;
            p0 = p1;
        }

        return (
            Math.div(baseAmount * basePrecision, 1e18, false),
            quoteAmount - Math.div(remainingQuote * quotePrecision, 1e18, false)
        );
    }

    /**
     * @dev Returns the amount of base tokens that should be received and the quote amount that should be sent for the
     * specified quote amount.
     * @param supply The current supply of the base token.
     * @param quoteAmount The amount of quote tokens to be sent.
     * @return baseAmount The amount of base tokens to be received.
     * @return actualQuoteAmount The actual amount of quote tokens to be sent.
     */
    function _getBaseAmountIn(uint256 supply, uint256 quoteAmount)
        internal
        view
        returns (uint256 baseAmount, uint256 actualQuoteAmount)
    {
        if (supply > _totalSupply()) revert PricePoints__TotalSupplyExceeded();

        uint256 basePrecision = _basePrecision();
        uint256 quotePrecision = _quotePrecision();

        uint256 widthScaled = _widthScaled();

        uint256 supplyScaled = supply * 1e18 / basePrecision;
        uint256 remainingQuote = quoteAmount * 1e18 / quotePrecision;

        uint256 i = supplyScaled / widthScaled;
        uint256 base = supplyScaled % widthScaled;

        if (base == 0) base = widthScaled;
        else ++i;

        uint256 p1 = _pricePoints(i, false);

        while (remainingQuote > 0 && i > 0) {
            uint256 p0 = _pricePoints(--i, false);

            (uint256 deltaBase, uint256 deltaQuote) = _getDeltaBaseIn(p0, p1, widthScaled, base, remainingQuote);

            baseAmount += deltaBase;
            remainingQuote -= deltaQuote;

            base = widthScaled;
            p1 = p0;
        }

        return (
            Math.div(baseAmount * basePrecision, 1e18, true),
            quoteAmount - Math.div(remainingQuote * quotePrecision, 1e18, true)
        );
    }

    /**
     * @dev Returns the delta base and quote amounts for the specified price points and remaining quote amount.
     * @param p0 The price of the base token in the quote token at the current price point.
     * @param p1 The price of the base token in the quote token at the next price point.
     * @param widthScaled The width of the segment in scaled base tokens.
     * @param base The amount of base tokens already purchased in the current segment.
     * @param remainingQuote The remaining quote tokens.
     * @return deltaBase The amount of base tokens to be sent (< 0) or received (> 0).
     * @return deltaQuote The amount of quote tokens to be sent (< 0) or received (> 0).
     */
    function _getDeltaBaseOut(uint256 p0, uint256 p1, uint256 widthScaled, uint256 base, uint256 remainingQuote)
        internal
        pure
        returns (uint256 deltaBase, uint256 deltaQuote)
    {
        uint256 dp = p1 - p0;

        uint256 currentQuote = Math.mulDiv(base, dp * base + 2 * p0 * widthScaled, 2e18 * widthScaled, false);
        uint256 nextQuote = Math.div((p0 + p1) * widthScaled, 2e18, true);

        uint256 maxQuote = nextQuote - currentQuote;

        if (remainingQuote >= maxQuote) {
            deltaQuote = maxQuote;
            deltaBase = widthScaled - base;
        } else {
            deltaQuote = remainingQuote;
            uint256 sqrtDiscriminant = _getSqrtDiscriminant(dp, p0, widthScaled, currentQuote + deltaQuote, false);

            uint256 rl = sqrtDiscriminant;
            uint256 rr = p0 * widthScaled + base * dp;

            deltaBase = Math.div(rl - rr, dp, false);
        }
    }

    /**
     * @dev Returns the delta base and quote amounts for the specified price points and remaining quote amount.
     * @param p0 The price of the base token in the quote token at the current price point.
     * @param p1 The price of the base token in the quote token at the next price point.
     * @param widthScaled The width of the segment in scaled base tokens.
     * @param base The amount of base tokens already purchased in the current segment.
     * @param remainingQuote The remaining quote tokens.
     * @return deltaBase The amount of base tokens to be sent (< 0) or received (> 0).
     * @return deltaQuote The amount of quote tokens to be sent (< 0) or received (> 0).
     */
    function _getDeltaBaseIn(uint256 p0, uint256 p1, uint256 widthScaled, uint256 base, uint256 remainingQuote)
        internal
        pure
        returns (uint256 deltaBase, uint256 deltaQuote)
    {
        uint256 dp = p1 - p0;
        uint256 currentQuote = Math.mulDiv(base, dp * base + 2 * p0 * widthScaled, 2e18 * widthScaled, false);

        if (remainingQuote >= currentQuote) {
            deltaQuote = currentQuote;
            deltaBase = base;
        } else {
            deltaQuote = remainingQuote;

            uint256 sqrtDiscriminant = _getSqrtDiscriminant(dp, p0, widthScaled, currentQuote - deltaQuote, false);

            uint256 rl = p0 * widthScaled + base * dp;
            uint256 rr = sqrtDiscriminant;

            deltaBase = Math.div(rl - rr, dp, true);
        }
    }

    /**
     * @dev Returns the square root of the discriminant for the specified price points and remaining quote amount.
     * @param dp The difference between the price of the base token in the quote token at the next price point and the
     * current price point.
     * @param p0 The price of the base token in the quote token at the current price point.
     * @param widthScaled The width of the segment in scaled base tokens.
     * @param currentQuote The current quote amount.
     * @param roundUp Whether to round up the result.
     * @return sqrtDiscriminant The square root of the discriminant.
     */
    function _getSqrtDiscriminant(uint256 dp, uint256 p0, uint256 widthScaled, uint256 currentQuote, bool roundUp)
        internal
        pure
        returns (uint256 sqrtDiscriminant)
    {
        (uint256 dl0, uint256 dl1) = Math.mul512(widthScaled * dp, currentQuote * 2e18);
        (uint256 dr0, uint256 dr1) = Math.mul512(p0 * widthScaled, p0 * widthScaled);

        (uint256 d0, uint256 d1) = Math.add512(dl0, dl1, dr0, dr1);

        return Math.sqrt512(d0, d1, roundUp);
    }

    /**
     * @dev Returns the total supply of the base token.
     */
    function _totalSupply() internal view virtual returns (uint256);

    /**
     * @dev Returns the width of the segment in scaled base tokens.
     */
    function _widthScaled() internal view virtual returns (uint256);

    /**
     * @dev Returns the precision of the base token.
     */
    function _basePrecision() internal view virtual returns (uint256);

    /**
     * @dev Returns the precision of the quote token.
     */
    function _quotePrecision() internal view virtual returns (uint256);

    /**
     * @dev Returns the number of price points.
     */
    function _pricePointsLength() internal view virtual returns (uint256);

    /**
     * @dev Returns the price points using the immutable arguments.
     * This function doesn't check that the index is within bounds. It should be done by the parent function.
     * @param i The index of the price point.
     * @param askPrice Whether to get the ask price (true), ie, the price at which the user can sell the base token,
     * or the bid price (false), ie, the price at which the user can buy the base token.
     * @return The price of the base token in the quote token at the specified index.
     */
    function _pricePoints(uint256 i, bool askPrice) internal view virtual returns (uint256);
}
