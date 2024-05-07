// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";

import "../src/PricePoints.sol";

contract PricePointsTest is Test {
    PricePoints _curve;

    uint256[] _pricePoints = [1e18, 2e18, 4e18, 8e18, 16e18, 32e18];

    uint256 _totalSupply;
    uint256 _basePrecision;
    uint256 _quotePrecision;

    function setUp() public {}

    function test_getQuoteAmount() public {
        uint256 decimalsBase = 9;
        uint256 decimalsQuote = 6;
        uint256 totalSupply = 500_000_000 * 10 ** decimalsBase;

        _deployCurve(_pricePoints, totalSupply, decimalsBase, decimalsQuote);

        {
            uint256 supply = 0;
            uint256 base = 10_000_000 * _basePrecision;

            (uint256 actualBaseAmount, uint256 quoteAmount) = _curve.getQuoteAmount(supply, base, false);
            (uint256 baseAmount, uint256 actualQuoteAmount) = _curve.getBaseAmount(supply, quoteAmount, false);

            assertEq(actualBaseAmount, baseAmount, "test_getQuoteAmount::1");
            assertEq(actualQuoteAmount, quoteAmount, "test_getQuoteAmount::2");
        }

        {
            uint256 supply = 100_000_000 * _basePrecision;
            uint256 base = 10_000_000 * _basePrecision;

            (uint256 actualBaseAmount, uint256 quoteAmount) = _curve.getQuoteAmount(supply, base, false);
            (uint256 baseAmount, uint256 actualQuoteAmount) = _curve.getBaseAmount(supply, quoteAmount, false);

            assertEq(actualBaseAmount, baseAmount, "test_getQuoteAmount::3");
            assertEq(actualQuoteAmount, quoteAmount, "test_getQuoteAmount::4");
        }

        {
            uint256 supply = 150_000_000 * _basePrecision;
            uint256 base = 10_000_000 * _basePrecision;

            (uint256 actualBaseAmount, uint256 quoteAmount) = _curve.getQuoteAmount(supply, base, false);
            (uint256 baseAmount, uint256 actualQuoteAmount) = _curve.getBaseAmount(supply, quoteAmount, false);

            assertEq(actualBaseAmount, baseAmount, "test_getQuoteAmount::5");
            assertEq(actualQuoteAmount, quoteAmount, "test_getQuoteAmount::6");
        }

        {
            uint256 supply = 150_000_000 * _basePrecision;
            uint256 base = 50_000_000 * _basePrecision;

            (uint256 actualBaseAmount, uint256 quoteAmount) = _curve.getQuoteAmount(supply, base, false);
            (uint256 baseAmount, uint256 actualQuoteAmount) = _curve.getBaseAmount(supply, quoteAmount, false);

            assertEq(actualBaseAmount, baseAmount, "test_getQuoteAmount::7");
            assertEq(actualQuoteAmount, quoteAmount, "test_getQuoteAmount::8");
        }

        {
            uint256 supply = 200_000_000 * _basePrecision;
            uint256 base = 50_000_000 * _basePrecision;

            (uint256 actualBaseAmount, uint256 quoteAmount) = _curve.getQuoteAmount(supply, base, false);
            (uint256 baseAmount, uint256 actualQuoteAmount) = _curve.getBaseAmount(supply, quoteAmount, false);

            assertEq(actualBaseAmount, baseAmount, "test_getQuoteAmount::9");
            assertEq(actualQuoteAmount, quoteAmount, "test_getQuoteAmount::10");
        }

        {
            uint256 supply = 150_000_000 * _basePrecision;
            uint256 base = 100_000_000 * _basePrecision;

            (uint256 actualBaseAmount, uint256 quoteAmount) = _curve.getQuoteAmount(supply, base, false);
            (uint256 baseAmount, uint256 actualQuoteAmount) = _curve.getBaseAmount(supply, quoteAmount, false);

            assertEq(actualBaseAmount, baseAmount, "test_getQuoteAmount::11");
            assertEq(actualQuoteAmount, quoteAmount, "test_getQuoteAmount::12");
        }

        {
            uint256 supply = 0;
            uint256 base = 500_000_000 * _basePrecision;

            (uint256 actualBaseAmount, uint256 quoteAmount) = _curve.getQuoteAmount(supply, base, false);
            (uint256 baseAmount, uint256 actualQuoteAmount) = _curve.getBaseAmount(supply, quoteAmount, false);

            assertEq(actualBaseAmount, baseAmount, "test_getQuoteAmount::13");
            assertEq(actualQuoteAmount, quoteAmount, "test_getQuoteAmount::14");
        }

        {
            uint256 supply = 0;
            uint256 base = 500_000_000 * _basePrecision + 1;

            (uint256 actualBaseAmount, uint256 quoteAmount) = _curve.getQuoteAmount(supply, base, false);
            (uint256 baseAmount, uint256 actualQuoteAmount) = _curve.getBaseAmount(supply, quoteAmount + 1, false);

            assertEq(actualBaseAmount, baseAmount, "test_getQuoteAmount::15");
            assertEq(actualQuoteAmount, quoteAmount, "test_getQuoteAmount::16");
        }
    }

    function test_Fuzz_getQuoteAmount(
        uint256 totalSupply,
        uint256 supply,
        uint256 base,
        uint256 decimalsBase,
        uint256 decimalsQuote
    ) public {
        _deployCurve(_pricePoints, totalSupply, decimalsBase, decimalsQuote);

        supply = bound(supply, 0, _totalSupply);
        base = bound(base, 0, _totalSupply - supply);

        {
            (uint256 actualBaseAmount, uint256 quoteAmount) = _curve.getQuoteAmount(supply, base, false);
            (uint256 baseAmount,) = _curve.getBaseAmount(supply, quoteAmount, false);

            assertGe(actualBaseAmount, baseAmount, "test_fuzz_getQuoteAmount::1");
            assertGe(base, actualBaseAmount, "test_fuzz_getQuoteAmount::2");
        }

        {
            (uint256 actualBaseAmount, uint256 quoteAmount) = _curve.getQuoteAmount(supply, base, true);
            (uint256 baseAmount,) = _curve.getBaseAmount(supply, quoteAmount, true);

            assertLe(actualBaseAmount, baseAmount, "test_fuzz_getQuoteAmount::3");
            assertGe(base, actualBaseAmount, "test_fuzz_getQuoteAmount::4");
        }
    }

    function test_Fuzz_getBaseAmount(
        uint256 totalSupply,
        uint256 supply,
        uint256 quote,
        uint256 decimalsBase,
        uint256 decimalsQuote
    ) public {
        _deployCurve(_pricePoints, totalSupply, decimalsBase, decimalsQuote);

        supply = bound(supply, 0, _totalSupply);

        (, uint256 maxQuote) = _curve.getBaseAmount(supply, _totalSupply - supply, true);
        quote = bound(quote, 0, maxQuote);

        {
            (uint256 baseAmount, uint256 actualQuoteAmount) = _curve.getBaseAmount(supply, quote, false);
            (, uint256 quoteAmount) = _curve.getQuoteAmount(supply, baseAmount, false);

            assertGe(actualQuoteAmount, quoteAmount, "test_fuzz_getBaseAmount::1");
            assertGe(quote, actualQuoteAmount, "test_fuzz_getBaseAmount::2");
        }

        {
            (uint256 baseAmount, uint256 actualQuoteAmount) = _curve.getBaseAmount(supply, quote, true);
            (, uint256 quoteAmount) = _curve.getQuoteAmount(supply, baseAmount, true);

            assertLe(actualQuoteAmount, quoteAmount, "test_fuzz_getBaseAmount::3");
            assertGe(quote, actualQuoteAmount, "test_fuzz_getBaseAmount::4");
        }
    }

    function _deployCurve(
        uint256[] memory pricePoints,
        uint256 totalSupply,
        uint256 decimalsBase,
        uint256 decimalsQuote
    ) internal {
        uint256 nb = pricePoints.length - 1;

        decimalsBase = bound(decimalsBase, 6, 18);
        decimalsQuote = bound(decimalsQuote, 6, 18);
        pricePoints;
        totalSupply = bound(totalSupply, 10 ** decimalsBase + (10 ** decimalsBase % nb), type(uint128).max);
        totalSupply = (totalSupply / nb) * nb;

        _curve = new PricePoints(pricePoints, totalSupply, decimalsBase, decimalsQuote);

        _pricePoints = pricePoints;
        _totalSupply = totalSupply;
        _basePrecision = 10 ** decimalsBase;
        _quotePrecision = 10 ** decimalsQuote;
    }
}
