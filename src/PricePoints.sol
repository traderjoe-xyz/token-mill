// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Math} from "../src/libraries/Math.sol";

abstract contract PricePoints {
    error PricePoints__TotalSupplyExceeded();

    function getDeltaQuoteAmount(uint256 supply, int256 deltaBaseAmount)
        public
        view
        returns (int256 actualDeltaBaseAmount, int256 deltaQuoteAmount)
    {
        if (deltaBaseAmount == 0) return (0, 0);

        (uint256 circSupply, uint256 base) = deltaBaseAmount > 0
            ? (supply - uint256(deltaBaseAmount), uint256(deltaBaseAmount))
            : (supply, uint256(-deltaBaseAmount));

        (uint256 baseAmount, uint256 quoteAmount) = _getQuoteAmount(circSupply, base, deltaBaseAmount < 0);

        return deltaBaseAmount > 0
            ? (int256(baseAmount), -int256(quoteAmount))
            : (-int256(baseAmount), int256(quoteAmount));
    }

    function getDeltaBaseAmount(uint256 supply, int256 deltaQuoteAmount)
        public
        view
        returns (int256 deltaBaseAmount, int256 actualDeltaQuoteAmount)
    {
        if (deltaQuoteAmount == 0) return (0, 0);

        if (deltaQuoteAmount > 0) {
            (uint256 baseAmount, uint256 quoteAmount) = _getBaseAmountOut(supply, uint256(deltaQuoteAmount));
            return (-int256(baseAmount), int256(quoteAmount));
        } else {
            (uint256 baseAmount, uint256 quoteAmount) = _getBaseAmountIn(supply, uint256(-deltaQuoteAmount));
            return (int256(baseAmount), -int256(quoteAmount));
        }
    }

    function _getQuoteAmount(uint256 supply, uint256 baseAmount, bool roundUp)
        internal
        view
        returns (uint256 actualBaseAmount, uint256 quoteAmount)
    {
        if (supply > _totalSupply()) revert PricePoints__TotalSupplyExceeded();

        uint256 length = _pricePointsLength();

        uint256 basePrecision = _basePrecision();
        uint256 widthScaled = _widthScaled();

        supply = supply * 1e18 / basePrecision;
        actualBaseAmount = baseAmount;

        baseAmount = baseAmount * 1e18 / basePrecision;

        uint256 i = supply / widthScaled;
        supply = supply % widthScaled;

        uint256 p0 = _pricePoints(i, roundUp);

        while (baseAmount > 0 && ++i < length) {
            uint256 p1 = _pricePoints(i, roundUp);

            uint256 deltaBase = Math.min(baseAmount, widthScaled - supply);
            uint256 deltaQuote = Math.mulDiv(
                deltaBase, (p1 - p0) * (deltaBase + 2 * supply) + 2 * p0 * widthScaled, 2e18 * widthScaled, roundUp
            );

            quoteAmount += deltaQuote;
            baseAmount -= deltaBase;

            supply = 0;
            p0 = p1;
        }

        return (
            actualBaseAmount - Math.div((baseAmount) * basePrecision, 1e18, !roundUp),
            Math.div(quoteAmount * _quotePrecision(), 1e18, roundUp)
        );
    }

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
            quoteAmount - Math.div(remainingQuote * quotePrecision, 1e18, true)
        );
    }

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
            quoteAmount - Math.div(remainingQuote * quotePrecision, 1e18, false)
        );
    }

    function _getDeltaBaseOut(uint256 p0, uint256 p1, uint256 widthScaled, uint256 base, uint256 remainingQuote)
        internal
        pure
        returns (uint256 deltaBase, uint256 deltaQuote)
    {
        uint256 dp = p1 - p0;

        uint256 currentQuote = Math.mulDiv(base, dp * base + 2 * p0 * widthScaled, 2e18 * widthScaled, false);
        uint256 nextQuote = Math.div((p0 + p1) * widthScaled, 2e18, false);

        uint256 maxQuote = nextQuote - currentQuote;

        if (remainingQuote > maxQuote) {
            deltaQuote = maxQuote;
            deltaBase = widthScaled - base;
        } else {
            deltaQuote = remainingQuote;
            uint256 sqrtDiscriminant = _getSqrtDiscriminant(dp, p0, widthScaled, currentQuote + deltaQuote, false);

            uint256 rl = sqrtDiscriminant;
            uint256 rr = p0 * widthScaled + base * dp;

            deltaBase = rl > rr ? Math.div(rl - rr, dp, false) : 0;
        }
    }

    function _getDeltaBaseIn(uint256 p0, uint256 p1, uint256 widthScaled, uint256 base, uint256 remainingQuote)
        internal
        pure
        returns (uint256 deltaBase, uint256 deltaQuote)
    {
        uint256 dp = p1 - p0;
        uint256 currentQuote = Math.mulDiv(base, dp * base + 2 * p0 * widthScaled, 2e18 * widthScaled, false);

        if (remainingQuote > currentQuote) {
            deltaQuote = currentQuote;
            deltaBase = base;
        } else {
            deltaQuote = remainingQuote;

            uint256 sqrtDiscriminant = _getSqrtDiscriminant(dp, p0, widthScaled, currentQuote - deltaQuote, false);

            uint256 rl = p0 * widthScaled + base * dp;
            uint256 rr = sqrtDiscriminant;

            deltaBase = rl > rr ? Math.div(rl - rr, dp, true) : 0;
        }
    }

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

    function _totalSupply() internal view virtual returns (uint256);

    function _widthScaled() internal view virtual returns (uint256);

    function _basePrecision() internal view virtual returns (uint256);

    function _quotePrecision() internal view virtual returns (uint256);

    function _pricePointsLength() internal view virtual returns (uint256);

    function _pricePoints(uint256 i, bool bid) internal view virtual returns (uint256);
}
