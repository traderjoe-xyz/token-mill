// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../src/libraries/Math.sol";

contract PricePoints {
    uint256 private immutable _totalSupply;
    uint256 private immutable _widthScaled;
    uint256[] private _pricePoints; // todo make immutable

    uint256 private immutable _basePrecision;
    uint256 private immutable _quotePrecision;

    constructor(uint256[] memory pricePoints, uint256 totalSupply, uint256 decimalsBase, uint256 decimalsQuote) {
        uint256 length = pricePoints.length;

        require(length >= 2 && length <= 100, "PricePoints::constructor: INVALID_LENGTH");
        require(
            totalSupply >= 10 ** decimalsBase * (length - 1) && totalSupply <= type(uint128).max,
            "PricePoints::constructor: INVALID_SUPPLY"
        );
        require(decimalsBase <= 18, "PricePoints::constructor: INVALID_BASE_DECIMALS");
        require(decimalsQuote <= 18, "PricePoints::constructor: INVALID_QUOTE_DECIMALS");

        uint256 last = pricePoints[0];
        for (uint256 i = 1; i < length; i++) {
            uint256 current = pricePoints[i];
            require(current > last, "PricePoints::constructor: UNORDERED_PRICES");
            last = current;
        }
        require(last <= 1e36, "PricePoints::constructor: MAX_PRICE_EXCEEDED");

        uint256 nb = length - 1;
        uint256 width = totalSupply / nb;
        uint256 basePrecision = 10 ** decimalsBase;
        uint256 quotePrecision = 10 ** decimalsQuote;

        require(width * 1e18 / basePrecision < type(uint128).max, "PricePoints::constructor: WIDTH_OVERFLOW");

        _totalSupply = width * nb;
        _widthScaled = width * 1e18 / basePrecision;
        _pricePoints = pricePoints;
        _basePrecision = basePrecision;
        _quotePrecision = quotePrecision;
    }

    function getDeltaQuoteAmount(uint256 supply, int256 deltaBaseAmount)
        public
        view
        returns (int256 actualDeltaBaseAmount, int256 deltaQuoteAmount)
    {
        if (deltaBaseAmount == 0) return (0, 0);

        (uint256 circSupply, uint256 base) = deltaBaseAmount > 0
            ? (supply - uint256(deltaBaseAmount), uint256(deltaBaseAmount))
            : (supply, uint256(-deltaBaseAmount));

        (uint256 baseAmount, uint256 quoteAmount) = getQuoteAmount(circSupply, base, deltaBaseAmount < 0);

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
            (uint256 baseAmount, uint256 quoteAmount) = getBaseAmountOut(supply, uint256(deltaQuoteAmount));
            return (-int256(baseAmount), int256(quoteAmount));
        } else {
            (uint256 baseAmount, uint256 quoteAmount) = getBaseAmountIn(supply, uint256(-deltaQuoteAmount));
            return (int256(baseAmount), -int256(quoteAmount));
        }
    }

    function getQuoteAmount(uint256 supply, uint256 baseAmount, bool roundUp)
        public
        view
        returns (uint256 actualBaseAmount, uint256 quoteAmount)
    {
        uint256 length = _pricePoints.length;
        require(supply <= _totalSupply, "PricePoints::getAmount: SUPPLY_EXCEEDED");

        supply = supply * 1e18 / _basePrecision;
        uint256 remainingScaled = baseAmount * 1e18 / _basePrecision;

        uint256 i = supply / _widthScaled;
        uint256 x = supply % _widthScaled;

        uint256 p0 = _pricePoints[i];

        while (remainingScaled > 0 && ++i < length) {
            uint256 p1 = _pricePoints[i];

            uint256 dx = Math.min(remainingScaled, _widthScaled - x);
            uint256 dy = Math.mulDiv(dx, (p1 - p0) * (dx + 2 * x) + 2 * p0 * _widthScaled, 2e18 * _widthScaled, roundUp);

            quoteAmount += dy;
            remainingScaled -= dx;

            x = 0;
            p0 = p1;
        }

        return (
            baseAmount - Math.div((remainingScaled) * _basePrecision, 1e18, !roundUp),
            Math.div(quoteAmount * _quotePrecision, 1e18, roundUp)
        );
    }

    function getBaseAmountOut(uint256 supply, uint256 quoteAmount)
        public
        view
        returns (uint256 baseAmount, uint256 actualQuoteAmount)
    {
        uint256 length = _pricePoints.length;
        require(supply <= _totalSupply, "PricePoints::getAmount: SUPPLY_EXCEEDED");

        supply = supply * 1e18 / _basePrecision;
        uint256 remainingScaled = quoteAmount * 1e18 / _quotePrecision;

        uint256 i = supply / _widthScaled;
        uint256 x = supply % _widthScaled;

        uint256 p0 = _pricePoints[i];

        while (remainingScaled > 0 && ++i < length) {
            uint256 p1 = _pricePoints[i];

            (uint256 dx, uint256 dy) = _getDeltaBaseOut(p0, p1, x, remainingScaled);

            baseAmount += dx;
            remainingScaled -= dy;

            x = 0;
            p0 = p1;
        }

        return (
            Math.div(baseAmount * _basePrecision, 1e18, false),
            quoteAmount - Math.div(remainingScaled * _quotePrecision, 1e18, true)
        );
    }

    function getBaseAmountIn(uint256 supply, uint256 quoteAmount)
        public
        view
        returns (uint256 baseAmount, uint256 actualQuoteAmount)
    {
        require(supply <= _totalSupply, "PricePoints::getAmount: SUPPLY_EXCEEDED");

        supply = supply * 1e18 / _basePrecision;
        uint256 remainingScaled = quoteAmount * 1e18 / _quotePrecision;

        uint256 i = supply / _widthScaled;
        uint256 x = supply % _widthScaled;

        if (x == 0) x = _widthScaled;
        else ++i;

        uint256 p1 = _pricePoints[i];

        while (remainingScaled > 0 && i > 0) {
            uint256 p0 = _pricePoints[--i];

            (uint256 dx, uint256 dy) = _getDeltaBaseIn(p0, p1, x, remainingScaled);

            baseAmount += dx;
            remainingScaled -= dy;

            x = _widthScaled;
            p1 = p0;
        }

        return (
            Math.div(baseAmount * _basePrecision, 1e18, true),
            quoteAmount - Math.div(remainingScaled * _quotePrecision, 1e18, false)
        );
    }

    function _getDeltaBaseOut(uint256 p0, uint256 p1, uint256 x, uint256 remainingScaled)
        private
        view
        returns (uint256 dx, uint256 dy)
    {
        uint256 dp = p1 - p0;

        uint256 y = Math.mulDiv(x, dp * x + 2 * p0 * _widthScaled, 2e18 * _widthScaled, false);
        uint256 nextY = Math.div((p0 + p1) * _widthScaled, 2e18, false);

        uint256 maxdy = nextY - y;

        if (remainingScaled > maxdy) {
            dy = maxdy;
            dx = _widthScaled - x;
        } else {
            dy = remainingScaled;
            uint256 sqrtDiscriminant = _getSqrtDiscriminant(dp, p0, y + dy, false);

            uint256 termA = p0 * _widthScaled + x * dp;
            uint256 termB = sqrtDiscriminant;

            dx = termB > termA ? Math.div(termB - termA, dp, false) : 0;
        }
    }

    function _getDeltaBaseIn(uint256 p0, uint256 p1, uint256 x, uint256 remainingScaled)
        private
        view
        returns (uint256 dx, uint256 dy)
    {
        uint256 dp = p1 - p0;
        uint256 y = Math.mulDiv(x, dp * x + 2 * p0 * _widthScaled, 2e18 * _widthScaled, false);

        if (remainingScaled > y) {
            dy = y;
            dx = x;
        } else {
            dy = remainingScaled;

            uint256 sqrtDiscriminant = _getSqrtDiscriminant(dp, p0, y - dy, false);

            uint256 termA = p0 * _widthScaled + x * dp;
            uint256 termB = sqrtDiscriminant;

            dx = termB < termA ? Math.div(termA - termB, dp, true) : 0;
        }
    }

    function _getSqrtDiscriminant(uint256 dp, uint256 p0, uint256 y, bool roundUp)
        private
        view
        returns (uint256 sqrtDiscriminant)
    {
        (uint256 dl0, uint256 dl1) = Math.mul512(_widthScaled * dp, y * 2e18);
        (uint256 dr0, uint256 dr1) = Math.mul512(p0 * _widthScaled, p0 * _widthScaled);

        (uint256 d0, uint256 d1) = Math.add512(dl0, dl1, dr0, dr1);

        return Math.sqrt512(d0, d1, roundUp);
    }
}
