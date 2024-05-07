// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";

import "../src/libraries/Math.sol";

contract PricePoints {
    uint256 private immutable _totalSupply;
    uint256 private immutable _widthScaled;
    uint256[] private _pricePoints; // todo make immutable

    uint256 private immutable _basePrecision;
    uint256 private immutable _quotePrecision;

    constructor(uint256[] memory pricePoints, uint256 totalSupply, uint256 decimalsBase, uint256 decimalsQuote) {
        uint256 length = pricePoints.length;

        require(length >= 2, "PricePoints::constructor: INVALID_LENGTH");
        require(
            totalSupply >= 10 ** decimalsBase && totalSupply <= type(uint128).max,
            "PricePoints::constructor: INVALID_SUPPLY"
        );
        require(decimalsBase >= 6 && decimalsBase <= 18, "PricePoints::constructor: INVALID_BASE_DECIMALS");
        require(decimalsQuote >= 6 && decimalsQuote <= 18, "PricePoints::constructor: INVALID_QUOTE_DECIMALS");

        uint256 previous = pricePoints[0];
        for (uint256 i = 1; i < length; i++) {
            uint256 current = pricePoints[i];
            require(current >= previous, "PricePoints::constructor: UNORDERED_PRICES");
            previous = current;
        }

        uint256 nb = length - 1;
        uint256 width = totalSupply / nb;
        uint256 basePrecision = 10 ** decimalsBase;
        uint256 quotePrecision = 10 ** decimalsQuote;

        _totalSupply = width * nb;
        _widthScaled = width * 1e18 / basePrecision;
        _pricePoints = pricePoints;
        _basePrecision = basePrecision;
        _quotePrecision = quotePrecision;

        getQuoteAmount(0, totalSupply, true);
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

            x = (x + dx) % _widthScaled; // todo = 0 less gas intensive, check edge cases
            p0 = p1;
        }

        return (
            baseAmount - Math.div((remainingScaled) * _basePrecision, 1e18, roundUp),
            Math.div(quoteAmount * _quotePrecision, 1e18, roundUp)
        );
    }

    function getBaseAmount(uint256 supply, uint256 quoteAmount, bool roundUp)
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

            (uint256 dx, uint256 dy) = _getDeltaQuote(p0, p1, x, remainingScaled, roundUp);

            baseAmount += dx;
            remainingScaled -= dy;

            x = (x + dx) % _widthScaled; // todo = 0 less gas intensive, check edge cases
            p0 = p1;
        }

        return (
            Math.div(baseAmount * _basePrecision, 1e18, roundUp),
            quoteAmount - Math.div(remainingScaled * _quotePrecision, 1e18, roundUp)
        );
    }

    function _getDeltaQuote(uint256 p0, uint256 p1, uint256 x, uint256 remainingScaled, bool roundUp)
        private
        view
        returns (uint256 dx, uint256 dy)
    {
        uint256 dp = p1 - p0;

        uint256 y = Math.mulDiv(x, dp * x + 2 * p0 * _widthScaled, 2e18 * _widthScaled, roundUp);
        uint256 nextY = Math.div((p0 + p1) * _widthScaled, 2e18, roundUp);

        dy = Math.min(remainingScaled, nextY - y);

        uint256 discriminant = Math.mulDiv(2e18, dp * (y + dy), _widthScaled, roundUp) + p0 * p0;
        uint256 sqrtDiscriminant = Math.sqrt(discriminant, roundUp);

        uint256 termA = p0 * _widthScaled + x * dp;
        uint256 termB = sqrtDiscriminant * _widthScaled;

        dx = termB > termA ? Math.div(termB - termA, dp, roundUp) : 0;
    }
}
