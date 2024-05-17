// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";

import "../src/Market.sol";
import "../src/libraries/ImmutableCreate.sol";
import "../src/libraries/Helper.sol";

contract PricePointsTest is Test {
    MarketTestContract _market;

    uint256[] _pricePoints = [1e18, 2e18, 4e18, 8e18, 16e18, 32e18];

    uint256 _totalSupply;
    uint256 _basePrecision;
    uint256 _quotePrecision;

    function setUp() public {}

    function test_getAmount() public {
        uint256 decimalsBase = 9;
        uint256 decimalsQuote = 6;
        uint256 totalSupply = 500_000_000 * 10 ** decimalsBase;

        _deployCurve(_pricePoints, totalSupply, decimalsBase, decimalsQuote);

        {
            uint256 circSupply = 0;
            uint256 base = 10_000_000 * _basePrecision;

            (uint256 actualBaseAmount, uint256 quoteAmount) = _market.getQuoteAmount(circSupply, base, false);
            (uint256 baseAmount, uint256 actualQuoteAmount) = _market.getBaseAmountOut(circSupply, quoteAmount);

            assertEq(actualBaseAmount, baseAmount, "test_getAmount::1");
            assertEq(actualQuoteAmount, quoteAmount, "test_getAmount::2");
        }

        {
            uint256 circSupply = 100_000_000 * _basePrecision;
            uint256 base = 10_000_000 * _basePrecision;

            (uint256 actualBaseAmount, uint256 quoteAmount) = _market.getQuoteAmount(circSupply, base, false);
            (uint256 baseAmount, uint256 actualQuoteAmount) = _market.getBaseAmountOut(circSupply, quoteAmount);

            assertEq(actualBaseAmount, baseAmount, "test_getAmount::3");
            assertEq(actualQuoteAmount, quoteAmount, "test_getAmount::4");
        }

        {
            uint256 circSupply = 150_000_000 * _basePrecision;
            uint256 base = 10_000_000 * _basePrecision;

            (uint256 actualBaseAmount, uint256 quoteAmount) = _market.getQuoteAmount(circSupply, base, false);
            (uint256 baseAmount, uint256 actualQuoteAmount) = _market.getBaseAmountOut(circSupply, quoteAmount);

            assertEq(actualBaseAmount, baseAmount, "test_getAmount::5");
            assertEq(actualQuoteAmount, quoteAmount, "test_getAmount::6");
        }

        {
            uint256 circSupply = 150_000_000 * _basePrecision;
            uint256 base = 50_000_000 * _basePrecision;

            (uint256 actualBaseAmount, uint256 quoteAmount) = _market.getQuoteAmount(circSupply, base, false);
            (uint256 baseAmount, uint256 actualQuoteAmount) = _market.getBaseAmountOut(circSupply, quoteAmount);

            assertEq(actualBaseAmount, baseAmount, "test_getAmount::7");
            assertEq(actualQuoteAmount, quoteAmount, "test_getAmount::8");
        }

        {
            uint256 circSupply = 200_000_000 * _basePrecision;
            uint256 base = 50_000_000 * _basePrecision;

            (uint256 actualBaseAmount, uint256 quoteAmount) = _market.getQuoteAmount(circSupply, base, false);
            (uint256 baseAmount, uint256 actualQuoteAmount) = _market.getBaseAmountOut(circSupply, quoteAmount);

            assertEq(actualBaseAmount, baseAmount, "test_getAmount::9");
            assertEq(actualQuoteAmount, quoteAmount, "test_getAmount::10");
        }

        {
            uint256 circSupply = 150_000_000 * _basePrecision;
            uint256 base = 100_000_000 * _basePrecision;

            (uint256 actualBaseAmount, uint256 quoteAmount) = _market.getQuoteAmount(circSupply, base, false);
            (uint256 baseAmount, uint256 actualQuoteAmount) = _market.getBaseAmountOut(circSupply, quoteAmount);

            assertEq(actualBaseAmount, baseAmount, "test_getAmount::11");
            assertEq(actualQuoteAmount, quoteAmount, "test_getAmount::12");
        }

        {
            uint256 circSupply = 0;
            uint256 base = 500_000_000 * _basePrecision;

            (uint256 actualBaseAmount, uint256 quoteAmount) = _market.getQuoteAmount(circSupply, base, false);
            (uint256 baseAmount, uint256 actualQuoteAmount) = _market.getBaseAmountOut(circSupply, quoteAmount);

            assertEq(actualBaseAmount, baseAmount, "test_getAmount::13");
            assertEq(actualQuoteAmount, quoteAmount, "test_getAmount::14");
        }

        {
            uint256 circSupply = 0;
            uint256 base = 500_000_000 * _basePrecision + 1;

            (uint256 actualBaseAmount, uint256 quoteAmount) = _market.getQuoteAmount(circSupply, base, false);
            (uint256 baseAmount, uint256 actualQuoteAmount) = _market.getBaseAmountOut(circSupply, quoteAmount + 1);

            assertEq(actualBaseAmount, baseAmount, "test_getAmount::15");
            assertEq(actualQuoteAmount, quoteAmount, "test_getAmount::16");
        }
    }

    function test_getDeltaAmount() public {
        uint256 decimalsBase = 9;
        uint256 decimalsQuote = 6;
        uint256 totalSupply = 500_000_000 * 10 ** decimalsBase;

        _deployCurve(_pricePoints, totalSupply, decimalsBase, decimalsQuote);

        {
            uint256 circSupply = 0;
            int256 deltaBase = -10_000_000 * int256(_basePrecision);

            (int256 actualDeltaBaseAmount, int256 deltaQuoteAmount) = _market.getDeltaQuoteAmount(circSupply, deltaBase);
            (int256 deltaBaseAmount, int256 actualDeltaQuoteAmount) =
                _market.getDeltaBaseAmount(circSupply + uint256(-deltaBase), -deltaQuoteAmount);

            assertEq(actualDeltaBaseAmount, -deltaBaseAmount, "test_getDeltaAmount::1");
            assertEq(-actualDeltaQuoteAmount, deltaQuoteAmount, "test_getDeltaAmount::2");
        }

        {
            uint256 circSupply = 10_000_000 * _basePrecision;
            int256 deltaBase = 10_000_000 * int256(_basePrecision);

            (int256 actualDeltaBaseAmount, int256 deltaQuoteAmount) = _market.getDeltaQuoteAmount(circSupply, deltaBase);
            (int256 deltaBaseAmount, int256 actualDeltaQuoteAmount) =
                _market.getDeltaBaseAmount(circSupply - uint256(deltaBase), -deltaQuoteAmount);

            assertEq(actualDeltaBaseAmount, -deltaBaseAmount, "test_getDeltaAmount::3");
            assertEq(-actualDeltaQuoteAmount, deltaQuoteAmount, "test_getDeltaAmount::4");
        }

        {
            uint256 circSupply = 100_000_000 * _basePrecision;
            int256 deltaBase = -10_000_000 * int256(_basePrecision);

            (int256 actualDeltaBaseAmount, int256 deltaQuoteAmount) = _market.getDeltaQuoteAmount(circSupply, deltaBase);
            (int256 deltaBaseAmount, int256 actualDeltaQuoteAmount) =
                _market.getDeltaBaseAmount(circSupply + uint256(-deltaBase), -deltaQuoteAmount);

            assertEq(actualDeltaBaseAmount, -deltaBaseAmount, "test_getDeltaAmount::5");
            assertEq(-actualDeltaQuoteAmount, deltaQuoteAmount, "test_getDeltaAmount::6");
        }

        {
            uint256 circSupply = 110_000_000 * _basePrecision;
            int256 deltaBase = 10_000_000 * int256(_basePrecision);

            (int256 actualDeltaBaseAmount, int256 deltaQuoteAmount) = _market.getDeltaQuoteAmount(circSupply, deltaBase);
            (int256 deltaBaseAmount, int256 actualDeltaQuoteAmount) =
                _market.getDeltaBaseAmount(circSupply - uint256(deltaBase), -deltaQuoteAmount);

            assertEq(actualDeltaBaseAmount, -deltaBaseAmount, "test_getDeltaAmount::7");
            assertEq(-actualDeltaQuoteAmount, deltaQuoteAmount, "test_getDeltaAmount::8");
        }

        {
            uint256 circSupply = 90_000_000 * _basePrecision;
            int256 deltaBase = -10_000_000 * int256(_basePrecision);

            (int256 actualDeltaBaseAmount, int256 deltaQuoteAmount) = _market.getDeltaQuoteAmount(circSupply, deltaBase);
            (int256 deltaBaseAmount, int256 actualDeltaQuoteAmount) =
                _market.getDeltaBaseAmount(circSupply + uint256(-deltaBase), -deltaQuoteAmount);

            assertEq(actualDeltaBaseAmount, -deltaBaseAmount, "test_getDeltaAmount::9");
            assertEq(-actualDeltaQuoteAmount, deltaQuoteAmount, "test_getDeltaAmount::10");
        }

        {
            uint256 circSupply = 100_000_000 * _basePrecision;
            int256 deltaBase = 10_000_000 * int256(_basePrecision);

            (int256 actualDeltaBaseAmount, int256 deltaQuoteAmount) = _market.getDeltaQuoteAmount(circSupply, deltaBase);
            (int256 deltaBaseAmount, int256 actualDeltaQuoteAmount) =
                _market.getDeltaBaseAmount(circSupply - uint256(deltaBase), -deltaQuoteAmount);

            assertEq(actualDeltaBaseAmount, -deltaBaseAmount, "test_getDeltaAmount::11");
            assertEq(-actualDeltaQuoteAmount, deltaQuoteAmount, "test_getDeltaAmount::12");
        }

        {
            uint256 circSupply = 150_000_000 * _basePrecision;
            int256 deltaBase = -10_000_000 * int256(_basePrecision);

            (int256 actualDeltaBaseAmount, int256 deltaQuoteAmount) = _market.getDeltaQuoteAmount(circSupply, deltaBase);
            (int256 deltaBaseAmount, int256 actualDeltaQuoteAmount) =
                _market.getDeltaBaseAmount(circSupply + uint256(-deltaBase), -deltaQuoteAmount);

            assertEq(actualDeltaBaseAmount, -deltaBaseAmount, "test_getDeltaAmount::13");
            assertEq(-actualDeltaQuoteAmount, deltaQuoteAmount, "test_getDeltaAmount::14");
        }

        {
            uint256 circSupply = 160_000_000 * _basePrecision;
            int256 deltaBase = 10_000_000 * int256(_basePrecision);

            (int256 actualDeltaBaseAmount, int256 deltaQuoteAmount) = _market.getDeltaQuoteAmount(circSupply, deltaBase);
            (int256 deltaBaseAmount, int256 actualDeltaQuoteAmount) =
                _market.getDeltaBaseAmount(circSupply - uint256(deltaBase), -deltaQuoteAmount);

            assertEq(actualDeltaBaseAmount, -deltaBaseAmount, "test_getDeltaAmount::15");
            assertEq(-actualDeltaQuoteAmount, deltaQuoteAmount, "test_getDeltaAmount::16");
        }

        {
            uint256 circSupply = 150_000_000 * _basePrecision;
            int256 deltaBase = -50_000_000 * int256(_basePrecision);

            (int256 actualDeltaBaseAmount, int256 deltaQuoteAmount) = _market.getDeltaQuoteAmount(circSupply, deltaBase);
            (int256 deltaBaseAmount, int256 actualDeltaQuoteAmount) =
                _market.getDeltaBaseAmount(circSupply + uint256(-deltaBase), -deltaQuoteAmount);

            assertEq(actualDeltaBaseAmount, -deltaBaseAmount, "test_getDeltaAmount::17");
            assertEq(-actualDeltaQuoteAmount, deltaQuoteAmount, "test_getDeltaAmount::18");
        }

        {
            uint256 circSupply = 200_000_000 * _basePrecision;
            int256 deltaBase = 50_000_000 * int256(_basePrecision);

            (int256 actualDeltaBaseAmount, int256 deltaQuoteAmount) = _market.getDeltaQuoteAmount(circSupply, deltaBase);
            (int256 deltaBaseAmount, int256 actualDeltaQuoteAmount) =
                _market.getDeltaBaseAmount(circSupply - uint256(deltaBase), -deltaQuoteAmount);

            assertEq(actualDeltaBaseAmount, -deltaBaseAmount, "test_getDeltaAmount::19");
            assertEq(-actualDeltaQuoteAmount, deltaQuoteAmount, "test_getDeltaAmount::20");
        }

        {
            uint256 circSupply = 150_000_000 * _basePrecision;
            int256 deltaBase = -100_000_000 * int256(_basePrecision);

            (int256 actualDeltaBaseAmount, int256 deltaQuoteAmount) = _market.getDeltaQuoteAmount(circSupply, deltaBase);
            (int256 deltaBaseAmount, int256 actualDeltaQuoteAmount) =
                _market.getDeltaBaseAmount(circSupply + uint256(-deltaBase), -deltaQuoteAmount);

            assertEq(actualDeltaBaseAmount, -deltaBaseAmount, "test_getDeltaAmount::21");
            assertEq(-actualDeltaQuoteAmount, deltaQuoteAmount, "test_getDeltaAmount::22");
        }

        {
            uint256 circSupply = 250_000_000 * _basePrecision;
            int256 deltaBase = 100_000_000 * int256(_basePrecision);

            (int256 actualDeltaBaseAmount, int256 deltaQuoteAmount) = _market.getDeltaQuoteAmount(circSupply, deltaBase);
            (int256 deltaBaseAmount, int256 actualDeltaQuoteAmount) =
                _market.getDeltaBaseAmount(circSupply - uint256(deltaBase), -deltaQuoteAmount);

            assertEq(actualDeltaBaseAmount, -deltaBaseAmount, "test_getDeltaAmount::23");
            assertEq(-actualDeltaQuoteAmount, deltaQuoteAmount, "test_getDeltaAmount::24");
        }

        {
            uint256 circSupply = 250_000_000 * _basePrecision;
            int256 deltaBase = -100_000_000 * int256(_basePrecision);

            (int256 actualDeltaBaseAmount, int256 deltaQuoteAmount) = _market.getDeltaQuoteAmount(circSupply, deltaBase);
            (int256 deltaBaseAmount, int256 actualDeltaQuoteAmount) =
                _market.getDeltaBaseAmount(circSupply + uint256(-deltaBase), -deltaQuoteAmount);

            assertEq(actualDeltaBaseAmount, -deltaBaseAmount, "test_getDeltaAmount::25");
            assertEq(-actualDeltaQuoteAmount, deltaQuoteAmount, "test_getDeltaAmount::26");
        }

        {
            uint256 circSupply = 150_000_000 * _basePrecision;
            int256 deltaBase = 100_000_000 * int256(_basePrecision);

            (int256 actualDeltaBaseAmount, int256 deltaQuoteAmount) = _market.getDeltaQuoteAmount(circSupply, deltaBase);
            (int256 deltaBaseAmount, int256 actualDeltaQuoteAmount) =
                _market.getDeltaBaseAmount(circSupply - uint256(deltaBase), -deltaQuoteAmount);

            assertEq(actualDeltaBaseAmount, -deltaBaseAmount, "test_getDeltaAmount::27");
            assertEq(-actualDeltaQuoteAmount, deltaQuoteAmount, "test_getDeltaAmount::28");
        }

        {
            uint256 circSupply = 0;
            int256 deltaBase = -500_000_000 * int256(_basePrecision);

            (int256 actualDeltaBaseAmount, int256 deltaQuoteAmount) = _market.getDeltaQuoteAmount(circSupply, deltaBase);
            (int256 deltaBaseAmount, int256 actualDeltaQuoteAmount) =
                _market.getDeltaBaseAmount(circSupply + uint256(-deltaBase), -deltaQuoteAmount);

            assertEq(actualDeltaBaseAmount, -deltaBaseAmount, "test_getDeltaAmount::29");
            assertEq(-actualDeltaQuoteAmount, deltaQuoteAmount, "test_getDeltaAmount::30");
        }

        {
            uint256 circSupply = 500_000_000 * _basePrecision;
            int256 deltaBase = 500_000_000 * int256(_basePrecision);

            (int256 actualDeltaBaseAmount, int256 deltaQuoteAmount) = _market.getDeltaQuoteAmount(circSupply, deltaBase);
            (int256 deltaBaseAmount, int256 actualDeltaQuoteAmount) =
                _market.getDeltaBaseAmount(circSupply - uint256(deltaBase), -deltaQuoteAmount);

            assertEq(actualDeltaBaseAmount, -deltaBaseAmount, "test_getDeltaAmount::31");
            assertEq(-actualDeltaQuoteAmount, deltaQuoteAmount, "test_getDeltaAmount::32");
        }

        {
            uint256 circSupply = 0;
            int256 deltaBase = -int256(500_000_000 * _basePrecision);

            (int256 actualDeltaBaseAmount, int256 deltaQuoteAmount) =
                _market.getDeltaQuoteAmount(circSupply, deltaBase - 1);
            (int256 deltaBaseAmount, int256 actualDeltaQuoteAmount) =
                _market.getDeltaBaseAmount(circSupply + uint256(-deltaBase), -(deltaQuoteAmount + 1));

            assertEq(actualDeltaBaseAmount, -deltaBaseAmount, "test_getDeltaAmount::33");
            assertEq(-actualDeltaQuoteAmount, deltaQuoteAmount, "test_getDeltaAmount::34");
        }

        {
            uint256 circSupply = 500_000_000 * _basePrecision;
            int256 deltaBase = int256(500_000_000 * _basePrecision);

            (int256 actualDeltaBaseAmount, int256 deltaQuoteAmount) = _market.getDeltaQuoteAmount(circSupply, deltaBase);
            (int256 deltaBaseAmount, int256 actualDeltaQuoteAmount) =
                _market.getDeltaBaseAmount(circSupply - uint256(deltaBase), -(deltaQuoteAmount) + 1);

            assertEq(actualDeltaBaseAmount, -deltaBaseAmount, "test_getDeltaAmount::35");
            assertEq(-actualDeltaQuoteAmount, deltaQuoteAmount, "test_getDeltaAmount::36");
        }
    }

    function test_Fuzz_getQuoteAmount(
        uint256 totalSupply,
        uint256[] memory pricePoints,
        uint256 circSupply,
        uint256 base,
        uint256 decimalsBase,
        uint256 decimalsQuote
    ) public {
        _deployCurve(pricePoints, totalSupply, decimalsBase, decimalsQuote);

        circSupply = bound(circSupply, 0, _totalSupply);
        base = bound(base, 0, _totalSupply - circSupply);

        {
            (uint256 actualBaseAmount, uint256 quoteAmount) = _market.getQuoteAmount(circSupply, base, false);
            (uint256 baseAmount,) = _market.getBaseAmountOut(circSupply, quoteAmount);

            assertGe(actualBaseAmount, baseAmount, "test_Fuzz_getQuoteAmount::1");
            assertGe(base, actualBaseAmount, "test_Fuzz_getQuoteAmount::2");
        }

        {
            (uint256 actualBaseAmount, uint256 quoteAmount) = _market.getQuoteAmount(circSupply, base, true);
            (uint256 baseAmount,) = _market.getBaseAmountIn(circSupply + actualBaseAmount, quoteAmount);

            assertLe(actualBaseAmount, baseAmount, "test_Fuzz_getQuoteAmount::3");
            assertGe(base, actualBaseAmount, "test_Fuzz_getQuoteAmount::4");
        }
    }

    function test_Fuzz_getBaseAmount(
        uint256 totalSupply,
        uint256[] memory pricePoints,
        uint256 circSupply,
        uint256 quote,
        uint256 decimalsBase,
        uint256 decimalsQuote
    ) public {
        _deployCurve(pricePoints, totalSupply, decimalsBase, decimalsQuote);

        circSupply = bound(circSupply, 0, _totalSupply);

        (, uint256 maxQuote) = _market.getQuoteAmount(circSupply, _totalSupply - circSupply, true);
        quote = bound(quote, 0, maxQuote);

        {
            (uint256 baseAmount, uint256 actualQuoteAmount) = _market.getBaseAmountOut(circSupply, quote);
            (, uint256 quoteAmount) = _market.getQuoteAmount(circSupply, baseAmount, false);

            assertGe(actualQuoteAmount, quoteAmount, "test_Fuzz_getBaseAmount::1");
            assertGe(quote, actualQuoteAmount, "test_Fuzz_getBaseAmount::2");
        }

        {
            (uint256 baseAmount, uint256 actualQuoteAmount) = _market.getBaseAmountIn(circSupply, quote);
            (, uint256 quoteAmount) = _market.getQuoteAmount(circSupply - baseAmount, baseAmount, true);

            assertLe(actualQuoteAmount, quoteAmount, "test_Fuzz_getBaseAmount::3");
            assertGe(quote, actualQuoteAmount, "test_Fuzz_getBaseAmount::4");
        }
    }

    function test_Fuzz_getDeltaQuoteAmount(
        uint256 totalSupply,
        uint256[] memory pricePoints,
        uint256 circSupply,
        int256 deltaBase,
        uint256 decimalsBase,
        uint256 decimalsQuote
    ) public {
        _deployCurve(pricePoints, totalSupply, decimalsBase, decimalsQuote);

        circSupply = bound(circSupply, 0, _totalSupply);
        deltaBase = bound(deltaBase, -int256(_totalSupply - circSupply), int256(circSupply));

        (int256 actualDeltaBaseAmount, int256 deltaQuoteAmount) = _market.getDeltaQuoteAmount(circSupply, deltaBase);
        (int256 deltaBaseAmount, int256 actualDeltaQuoteAmount) =
            _market.getDeltaBaseAmount(uint256(int256(circSupply) - actualDeltaBaseAmount), -deltaQuoteAmount);

        if (deltaBase == 0) {
            assertEq(actualDeltaBaseAmount, 0, "test_Fuzz_getDeltaQuoteAmount::1");
            assertEq(deltaQuoteAmount, 0, "test_Fuzz_getDeltaQuoteAmount::2");
            assertEq(deltaBaseAmount, 0, "test_Fuzz_getDeltaQuoteAmount::3");
            assertEq(actualDeltaQuoteAmount, 0, "test_Fuzz_getDeltaQuoteAmount::4");
        } else if (deltaBase > 0) {
            assertGe(actualDeltaBaseAmount, 0, "test_Fuzz_getDeltaQuoteAmount::5");
            assertLe(deltaQuoteAmount, 0, "test_Fuzz_getDeltaQuoteAmount::6");
            assertLe(deltaBaseAmount, 0, "test_Fuzz_getDeltaQuoteAmount::7");
            assertGe(actualDeltaQuoteAmount, 0, "test_Fuzz_getDeltaQuoteAmount::8");

            assertGe(deltaBase, actualDeltaBaseAmount, "test_Fuzz_getDeltaQuoteAmount::9");
            assertGe(actualDeltaBaseAmount, -deltaBaseAmount, "test_Fuzz_getDeltaQuoteAmount::10");
        } else {
            assertLe(actualDeltaBaseAmount, 0, "test_Fuzz_getDeltaQuoteAmount::11");
            assertGe(deltaQuoteAmount, 0, "test_Fuzz_getDeltaQuoteAmount::12");
            assertGe(deltaBaseAmount, 0, "test_Fuzz_getDeltaQuoteAmount::13");
            assertLe(actualDeltaQuoteAmount, 0, "test_Fuzz_getDeltaQuoteAmount::14");

            assertGe(-deltaBase, -actualDeltaBaseAmount, "test_Fuzz_getDeltaQuoteAmount::15");
            assertLe(-actualDeltaBaseAmount, deltaBaseAmount, "test_Fuzz_getDeltaQuoteAmount::16");
        }
    }

    function test_Fuzz_getDeltaBaseAmount(
        uint256 totalSupply,
        uint256[] memory pricePoints,
        uint256 circSupply,
        int256 deltaQuote,
        uint256 decimalsBase,
        uint256 decimalsQuote
    ) public {
        _deployCurve(pricePoints, totalSupply, decimalsBase, decimalsQuote);

        circSupply = bound(circSupply, 0, _totalSupply);

        (, uint256 maxQuoteIn) = _market.getQuoteAmount(circSupply, _totalSupply - circSupply, true);
        (, uint256 maxQuoteOut) = _market.getQuoteAmount(0, circSupply, true);

        deltaQuote = bound(deltaQuote, -int256(maxQuoteOut), int256(maxQuoteIn));

        (int256 deltaBaseAmount, int256 actualDeltaQuoteAmount) = _market.getDeltaBaseAmount(circSupply, deltaQuote);
        (int256 actualDeltaBaseAmount, int256 deltaQuoteAmount) =
            _market.getDeltaQuoteAmount(uint256(int256(circSupply) - deltaBaseAmount), -deltaBaseAmount);

        if (deltaQuote == 0) {
            assertEq(deltaBaseAmount, 0, "test_Fuzz_getDeltaBaseAmount::1");
            assertEq(actualDeltaQuoteAmount, 0, "test_Fuzz_getDeltaBaseAmount::2");
            assertEq(actualDeltaBaseAmount, 0, "test_Fuzz_getDeltaBaseAmount::3");
            assertEq(deltaQuoteAmount, 0, "test_Fuzz_getDeltaBaseAmount::4");
        } else if (deltaQuote > 0) {
            assertLe(deltaBaseAmount, 0, "test_Fuzz_getDeltaBaseAmount::5");
            assertGe(actualDeltaQuoteAmount, 0, "test_Fuzz_getDeltaBaseAmount::6");
            assertGe(actualDeltaBaseAmount, 0, "test_Fuzz_getDeltaBaseAmount::7");
            assertLe(deltaQuoteAmount, 0, "test_Fuzz_getDeltaBaseAmount::8");

            assertGe(deltaQuote, actualDeltaQuoteAmount, "test_Fuzz_getDeltaBaseAmount::9");
            assertGe(actualDeltaQuoteAmount, -deltaQuoteAmount, "test_Fuzz_getDeltaBaseAmount::10");
        } else {
            assertGe(deltaBaseAmount, 0, "test_Fuzz_getDeltaBaseAmount::11");
            assertLe(actualDeltaQuoteAmount, 0, "test_Fuzz_getDeltaBaseAmount::12");
            assertLe(actualDeltaBaseAmount, 0, "test_Fuzz_getDeltaBaseAmount::13");
            assertGe(deltaQuoteAmount, 0, "test_Fuzz_getDeltaBaseAmount::14");

            assertGe(-deltaQuote, -actualDeltaQuoteAmount, "test_Fuzz_getDeltaBaseAmount::15");
            assertLe(-actualDeltaQuoteAmount, deltaQuoteAmount, "test_Fuzz_getDeltaBaseAmount::16");
        }
    }

    function test_Fuzz_VerifyConvexity(
        uint256 totalSupply,
        uint256[] memory pricePoints,
        uint256 circSupply,
        int256 delta0,
        int256 delta1,
        uint256 decimalsBase,
        uint256 decimalsQuote
    ) public {
        _deployCurve(pricePoints, totalSupply, decimalsBase, decimalsQuote);

        circSupply = bound(circSupply, 0, _totalSupply);

        uint256 maxBaseIn = circSupply;
        uint256 maxBaseOut = _totalSupply - circSupply;

        (, uint256 maxQuoteIn) = _market.getQuoteAmount(circSupply, maxBaseOut, false);
        (, uint256 maxQuoteOut) = _market.getQuoteAmount(0, maxBaseIn, false);

        {
            int256 deltaBase0 = bound(delta0, -int256(maxBaseOut), 0);
            int256 deltaBase1 = bound(delta1, -int256(maxBaseOut) - deltaBase0, 0);

            (, int256 deltaQuote0) = _market.getDeltaQuoteAmount(circSupply, deltaBase0);
            (, int256 deltaQuote1) = _market.getDeltaQuoteAmount(uint256(int256(circSupply) - deltaBase0), deltaBase1);
            (, int256 deltaQuote01) = _market.getDeltaQuoteAmount(circSupply, deltaBase0 + deltaBase1);

            assertLe(deltaQuote01, deltaQuote0 + deltaQuote1, "test_Fuzz_VerifyConvexity::1");
        }

        {
            int256 deltaBase0 = bound(delta0, 0, int256(maxBaseIn));
            int256 deltaBase1 = bound(delta1, 0, int256(maxBaseIn) - deltaBase0);

            (, int256 deltaQuote0) = _market.getDeltaQuoteAmount(circSupply, deltaBase0);
            (, int256 deltaQuote1) = _market.getDeltaQuoteAmount(uint256(int256(circSupply) - deltaBase0), deltaBase1);
            (, int256 deltaQuote01) = _market.getDeltaQuoteAmount(circSupply, deltaBase0 + deltaBase1);

            assertGe(-deltaQuote01, -(deltaQuote0 + deltaQuote1), "test_Fuzz_VerifyConvexity::2");
        }

        {
            int256 deltaQuote0 = bound(delta0, -int256(maxQuoteOut), 0);
            int256 deltaQuote1 = bound(delta1, -int256(maxQuoteOut) - deltaQuote0, 0);

            (int256 deltaBase0,) = _market.getDeltaBaseAmount(circSupply, deltaQuote0);
            (int256 deltaBase1,) = _market.getDeltaBaseAmount(uint256(int256(circSupply) - deltaBase0), deltaQuote1);
            (int256 deltaBase01,) = _market.getDeltaBaseAmount(circSupply, deltaQuote0 + deltaQuote1);

            assertLe(deltaBase01, deltaBase0 + deltaBase1, "test_Fuzz_VerifyConvexity::3");
        }

        {
            int256 deltaQuote0 = bound(delta0, 0, int256(maxQuoteIn));
            int256 deltaQuote1 = bound(delta1, 0, int256(maxQuoteIn) - deltaQuote0);

            (int256 deltaBase0,) = _market.getDeltaBaseAmount(circSupply, deltaQuote0);
            (int256 deltaBase1,) = _market.getDeltaBaseAmount(uint256(int256(circSupply) - deltaBase0), deltaQuote1);
            (int256 deltaBase01,) = _market.getDeltaBaseAmount(circSupply, deltaQuote0 + deltaQuote1);

            assertGe(-deltaBase01, -(deltaBase0 + deltaBase1), "test_Fuzz_VerifyConvexity::4");
        }
    }

    function test_Fuzz_getDeltaQuoteAmountSplitFirstSwap(
        uint256 totalSupply,
        uint256[] memory pricePoints,
        uint256 decimalsBase,
        uint256 decimalsQuote,
        uint256 circSupply,
        int256 delta0,
        int256 delta1
    ) public {
        _deployCurve(pricePoints, totalSupply, decimalsBase, decimalsQuote);

        circSupply = bound(circSupply, 0, _totalSupply);

        // deltaBase >= 0
        {
            int256 deltaBase0 = bound(delta0, 0, int256(circSupply));
            int256 deltaBase1 = bound(delta1, 0, int256(circSupply) - deltaBase0);

            (int256 actualDeltaBaseAmount0, int256 deltaQuoteAmount0) =
                _market.getDeltaQuoteAmount(circSupply, deltaBase0);
            (int256 actualDeltaBaseAmount1, int256 deltaQuoteAmount1) =
                _market.getDeltaQuoteAmount(uint256(int256(circSupply) - actualDeltaBaseAmount0), deltaBase1);

            (int256 deltaBaseAmount01, int256 actualDeltaQuoteAmount01) = _market.getDeltaBaseAmount(
                uint256(int256(circSupply) - actualDeltaBaseAmount0 - actualDeltaBaseAmount1),
                -(deltaQuoteAmount0 + deltaQuoteAmount1)
            );

            assertEq(actualDeltaBaseAmount0, deltaBase0, "test_Fuzz_getDeltaQuoteAmount::1");
            assertEq(actualDeltaBaseAmount1, deltaBase1, "test_Fuzz_getDeltaQuoteAmount::2");
            assertEq(
                actualDeltaQuoteAmount01, -(deltaQuoteAmount0 + deltaQuoteAmount1), "test_Fuzz_getDeltaQuoteAmount::3"
            );

            assertLe(deltaQuoteAmount0, 0, "test_Fuzz_getDeltaQuoteAmount::4");
            assertLe(deltaQuoteAmount1, 0, "test_Fuzz_getDeltaQuoteAmount::5");
            assertLe(deltaBaseAmount01, 0, "test_Fuzz_getDeltaQuoteAmount::6");

            assertLe(-deltaBaseAmount01, deltaBase0 + deltaBase1, "test_Fuzz_getDeltaQuoteAmount::7");
        }

        // deltaBase <= 0
        {
            int256 deltaBase0 = bound(delta0, -int256(_totalSupply - circSupply), 0);
            int256 deltaBase1 = bound(delta1, -int256(_totalSupply - circSupply) - deltaBase0, 0);

            (int256 actualDeltaBaseAmount0, int256 deltaQuoteAmount0) =
                _market.getDeltaQuoteAmount(circSupply, deltaBase0);
            (int256 actualDeltaBaseAmount1, int256 deltaQuoteAmount1) =
                _market.getDeltaQuoteAmount(uint256(int256(circSupply) - actualDeltaBaseAmount0), deltaBase1);

            (int256 deltaBaseAmount01, int256 actualDeltaQuoteAmount01) = _market.getDeltaBaseAmount(
                uint256(int256(circSupply) - actualDeltaBaseAmount0 - actualDeltaBaseAmount1),
                -(deltaQuoteAmount0 + deltaQuoteAmount1)
            );

            assertEq(actualDeltaBaseAmount0, deltaBase0, "test_Fuzz_getDeltaQuoteAmount::8");
            assertEq(actualDeltaBaseAmount1, deltaBase1, "test_Fuzz_getDeltaQuoteAmount::9");
            assertLe(
                -actualDeltaQuoteAmount01, (deltaQuoteAmount0 + deltaQuoteAmount1), "test_Fuzz_getDeltaQuoteAmount::10"
            ); // Not always eq due to rounding

            assertGe(deltaQuoteAmount0, 0, "test_Fuzz_getDeltaQuoteAmount::11");
            assertGe(deltaQuoteAmount1, 0, "test_Fuzz_getDeltaQuoteAmount::12");
            assertGe(deltaBaseAmount01, 0, "test_Fuzz_getDeltaQuoteAmount::13");

            assertGe(deltaBaseAmount01, -(deltaBase0 + deltaBase1), "test_Fuzz_getDeltaQuoteAmount::14");
        }
    }

    function test_Fuzz_getDeltaQuoteAmountSplitSecondSwap(
        uint256 totalSupply,
        uint256[] memory pricePoints,
        uint256 decimalsBase,
        uint256 decimalsQuote,
        uint256 circSupply,
        int256 delta0,
        int256 delta1
    ) public {
        _deployCurve(pricePoints, totalSupply, decimalsBase, decimalsQuote);

        circSupply = bound(circSupply, 0, _totalSupply);

        // deltaBase >= 0
        {
            int256 deltaBase0 = bound(delta0, 0, int256(circSupply));

            (int256 actualDeltaBaseAmount0, int256 deltaQuoteAmount0) =
                _market.getDeltaQuoteAmount(circSupply, deltaBase0);

            int256 deltaQuoteAmount1 = bound(delta1, deltaQuoteAmount0, 0);
            int256 deltaQuoteAmount2 = deltaQuoteAmount0 - deltaQuoteAmount1;

            (int256 deltaBaseAmount1, int256 actualDeltaQuoteAmount1) =
                _market.getDeltaBaseAmount(uint256(int256(circSupply) - actualDeltaBaseAmount0), -deltaQuoteAmount1);
            (int256 deltaBaseAmount2, int256 actualDeltaQuoteAmount2) = _market.getDeltaBaseAmount(
                uint256(int256(circSupply) - actualDeltaBaseAmount0 - deltaBaseAmount1), -deltaQuoteAmount2
            );

            assertEq(actualDeltaBaseAmount0, deltaBase0, "test_Fuzz_getDeltaQuoteAmount::1");
            assertEq(actualDeltaQuoteAmount1, -deltaQuoteAmount1, "test_Fuzz_getDeltaQuoteAmount::2");
            assertEq(actualDeltaQuoteAmount2, -deltaQuoteAmount2, "test_Fuzz_getDeltaQuoteAmount::3");

            assertLe(deltaQuoteAmount0, 0, "test_Fuzz_getDeltaQuoteAmount::4");
            assertLe(deltaBaseAmount1, 0, "test_Fuzz_getDeltaQuoteAmount::5");
            assertLe(deltaBaseAmount2, 0, "test_Fuzz_getDeltaQuoteAmount::6");

            assertLe(-(deltaBaseAmount1 + deltaBaseAmount2), deltaBase0, "test_Fuzz_getDeltaQuoteAmount::7");
        }

        // deltaBase <= 0
        {
            int256 deltaBase0 = bound(delta0, -int256(_totalSupply - circSupply), 0);

            (int256 actualDeltaBaseAmount0, int256 deltaQuoteAmount0) =
                _market.getDeltaQuoteAmount(circSupply, deltaBase0);

            int256 deltaQuoteAmount1 = bound(delta1, 0, deltaQuoteAmount0);
            int256 deltaQuoteAmount2 = deltaQuoteAmount0 - deltaQuoteAmount1;

            (int256 deltaBaseAmount1, int256 actualDeltaQuoteAmount1) =
                _market.getDeltaBaseAmount(uint256(int256(circSupply) - actualDeltaBaseAmount0), -deltaQuoteAmount1);
            (int256 deltaBaseAmount2, int256 actualDeltaQuoteAmount2) = _market.getDeltaBaseAmount(
                uint256(int256(circSupply) - actualDeltaBaseAmount0 - deltaBaseAmount1), -deltaQuoteAmount2
            );

            assertEq(actualDeltaBaseAmount0, deltaBase0, "test_Fuzz_getDeltaQuoteAmount::8");
            assertLe(-actualDeltaQuoteAmount1, deltaQuoteAmount1, "test_Fuzz_getDeltaQuoteAmount::9");
            assertLe(-actualDeltaQuoteAmount2, deltaQuoteAmount2, "test_Fuzz_getDeltaQuoteAmount::10");

            assertGe(deltaQuoteAmount0, 0, "test_Fuzz_getDeltaQuoteAmount::11");
            assertGe(deltaBaseAmount1, 0, "test_Fuzz_getDeltaQuoteAmount::12");
            assertGe(deltaBaseAmount2, 0, "test_Fuzz_getDeltaQuoteAmount::13");

            assertGe((deltaBaseAmount1 + deltaBaseAmount2), -deltaBase0, "test_Fuzz_getDeltaQuoteAmount::14");
        }
    }

    function test_Fuzz_getDeltaBaseAmountSplitFirstSwap(
        uint256 totalSupply,
        uint256[] memory pricePoints,
        uint256 decimalsBase,
        uint256 decimalsQuote,
        uint256 circSupply,
        int256 delta0,
        int256 delta1
    ) public {
        _deployCurve(pricePoints, totalSupply, decimalsBase, decimalsQuote);

        circSupply = bound(circSupply, 0, _totalSupply);

        // deltaQuote >= 0
        {
            (, uint256 maxQuoteIn) = _market.getQuoteAmount(circSupply, _totalSupply - circSupply, false);

            int256 deltaQuote0 = bound(delta0, 0, int256(maxQuoteIn));
            int256 deltaQuote1 = bound(delta1, 0, int256(maxQuoteIn) - deltaQuote0);

            (int256 deltaBaseAmount0, int256 actualDeltaQuoteAmount0) =
                _market.getDeltaBaseAmount(circSupply, deltaQuote0);
            (int256 deltaBaseAmount1, int256 actualDeltaQuoteAmount1) =
                _market.getDeltaBaseAmount(uint256(int256(circSupply) - deltaBaseAmount0), deltaQuote1);

            (int256 actualDeltaBaseAmount01, int256 deltaQuoteAmount01) = _market.getDeltaQuoteAmount(
                uint256(int256(circSupply) - deltaBaseAmount0 - deltaBaseAmount1),
                -(deltaBaseAmount0 + deltaBaseAmount1)
            );

            assertEq(actualDeltaQuoteAmount0, deltaQuote0, "test_Fuzz_getDeltaBaseAmount::1");
            assertEq(actualDeltaQuoteAmount1, deltaQuote1, "test_Fuzz_getDeltaBaseAmount::2");
            assertEq(actualDeltaBaseAmount01, -(deltaBaseAmount0 + deltaBaseAmount1), "test_Fuzz_getDeltaBaseAmount::3");

            assertLe(deltaBaseAmount0, 0, "test_Fuzz_getDeltaBaseAmount::4");
            assertLe(deltaBaseAmount1, 0, "test_Fuzz_getDeltaBaseAmount::5");
            assertLe(deltaQuoteAmount01, 0, "test_Fuzz_getDeltaBaseAmount::6");

            assertLe(-deltaQuoteAmount01, deltaQuote0 + deltaQuote1, "test_Fuzz_getDeltaBaseAmount::7");
        }

        // deltaQuote <= 0
        {
            (, uint256 maxQuoteOut) = _market.getQuoteAmount(0, circSupply, false);

            int256 deltaQuote0 = bound(delta0, -int256(maxQuoteOut), 0);
            int256 deltaQuote1 = bound(delta1, -int256(maxQuoteOut) - deltaQuote0, 0);

            (int256 deltaBaseAmount0, int256 actualDeltaQuoteAmount0) =
                _market.getDeltaBaseAmount(circSupply, deltaQuote0);
            (int256 deltaBaseAmount1, int256 actualDeltaQuoteAmount1) =
                _market.getDeltaBaseAmount(uint256(int256(circSupply) - deltaBaseAmount0), deltaQuote1);

            (int256 actualDeltaBaseAmount01, int256 deltaQuoteAmount01) = _market.getDeltaQuoteAmount(
                uint256(int256(circSupply) - deltaBaseAmount0 - deltaBaseAmount1),
                -(deltaBaseAmount0 + deltaBaseAmount1)
            );

            assertEq(actualDeltaQuoteAmount0, deltaQuote0, "test_Fuzz_getDeltaBaseAmount::8");
            assertLe(-actualDeltaQuoteAmount1, -deltaQuote1, "test_Fuzz_getDeltaBaseAmount::9");
            assertLe(
                actualDeltaBaseAmount01, -(deltaBaseAmount0 + deltaBaseAmount1), "test_Fuzz_getDeltaBaseAmount::10"
            ); // Not always eq due to rounding

            assertGe(deltaBaseAmount0, 0, "test_Fuzz_getDeltaBaseAmount::11");
            assertGe(deltaBaseAmount1, 0, "test_Fuzz_getDeltaBaseAmount::12");
            assertGe(deltaQuoteAmount01, 0, "test_Fuzz_getDeltaBaseAmount::13");

            assertGe(
                deltaQuoteAmount01,
                -(actualDeltaQuoteAmount0 + actualDeltaQuoteAmount1),
                "test_Fuzz_getDeltaBaseAmount::14"
            );
        }
    }

    function test_Fuzz_getDeltaBaseAmountSplitSecondSwap(
        uint256 totalSupply,
        uint256[] memory pricePoints,
        uint256 decimalsBase,
        uint256 decimalsQuote,
        int256 delta0,
        int256 delta1,
        uint256 circSupply
    ) public {
        _deployCurve(pricePoints, totalSupply, decimalsBase, decimalsQuote);

        circSupply = bound(circSupply, 0, _totalSupply);

        // deltaQuote >= 0
        {
            (, uint256 maxQuoteIn) = _market.getQuoteAmount(circSupply, _totalSupply - circSupply, false);

            int256 deltaQuote0 = bound(delta0, 0, int256(maxQuoteIn));

            (int256 deltaBaseAmount0, int256 actualDeltaQuoteAmount0) =
                _market.getDeltaBaseAmount(circSupply, deltaQuote0);

            int256 deltaBaseAmount1 = bound(delta1, deltaBaseAmount0, 0);
            int256 deltaBaseAmount2 = deltaBaseAmount0 - deltaBaseAmount1;

            (int256 actualDeltaBaseAmount1, int256 deltaQuoteAmount1) =
                _market.getDeltaQuoteAmount(uint256(int256(circSupply) - deltaBaseAmount0), -deltaBaseAmount1);
            (int256 actualDeltaBaseAmount2, int256 deltaQuoteAmount2) = _market.getDeltaQuoteAmount(
                uint256(int256(circSupply) - deltaBaseAmount0 - actualDeltaBaseAmount1), -deltaBaseAmount2
            );

            assertEq(actualDeltaQuoteAmount0, deltaQuote0, "test_Fuzz_getDeltaBaseAmount::1");
            assertEq(actualDeltaBaseAmount1, -deltaBaseAmount1, "test_Fuzz_getDeltaBaseAmount::2");
            assertEq(actualDeltaBaseAmount2, -deltaBaseAmount2, "test_Fuzz_getDeltaBaseAmount::3");

            assertLe(deltaBaseAmount0, 0, "test_Fuzz_getDeltaBaseAmount::4");
            assertLe(deltaQuoteAmount1, 0, "test_Fuzz_getDeltaBaseAmount::5");
            assertLe(deltaQuoteAmount2, 0, "test_Fuzz_getDeltaBaseAmount::6");

            assertLe(-(deltaQuoteAmount1 + deltaQuoteAmount2), deltaQuote0, "test_Fuzz_getDeltaBaseAmount::7");
        }

        // deltaQuote <= 0
        {
            (, uint256 maxQuoteOut) = _market.getQuoteAmount(0, circSupply, false);

            int256 deltaQuote0 = bound(delta0, -int256(maxQuoteOut), 0);

            (int256 deltaBaseAmount0, int256 actualDeltaQuoteAmount0) =
                _market.getDeltaBaseAmount(circSupply, deltaQuote0);

            int256 deltaBaseAmount1 = bound(delta1, 0, deltaBaseAmount0);
            int256 deltaBaseAmount2 = deltaBaseAmount0 - deltaBaseAmount1;

            (int256 actualDeltaBaseAmount1, int256 deltaQuoteAmount1) =
                _market.getDeltaQuoteAmount(uint256(int256(circSupply) - deltaBaseAmount0), -deltaBaseAmount1);
            (int256 actualDeltaBaseAmount2, int256 deltaQuoteAmount2) = _market.getDeltaQuoteAmount(
                uint256(int256(circSupply) - deltaBaseAmount0 - actualDeltaBaseAmount1), -deltaBaseAmount2
            );

            assertEq(actualDeltaQuoteAmount0, deltaQuote0, "test_Fuzz_getDeltaBaseAmount::8");
            assertLe(-actualDeltaBaseAmount1, deltaBaseAmount1, "test_Fuzz_getDeltaBaseAmount::9");
            assertLe(-actualDeltaBaseAmount2, deltaBaseAmount2, "test_Fuzz_getDeltaBaseAmount::10"); // Not always eq due to rounding

            assertGe(deltaBaseAmount0, 0, "test_Fuzz_getDeltaBaseAmount::11");
            assertGe(deltaQuoteAmount1, 0, "test_Fuzz_getDeltaBaseAmount::12");
            assertGe(deltaQuoteAmount2, 0, "test_Fuzz_getDeltaBaseAmount::13");

            assertGe(
                -(deltaBaseAmount1 + deltaBaseAmount2),
                actualDeltaBaseAmount1 + actualDeltaBaseAmount2,
                "test_Fuzz_getDeltaBaseAmount::14"
            );
        }
    }

    function _deployCurve(
        uint256[] memory pricePoints,
        uint256 totalSupply,
        uint256 decimalsBase,
        uint256 decimalsQuote
    ) internal {
        decimalsBase = bound(decimalsBase, 0, 18);
        decimalsQuote = bound(decimalsQuote, 0, 18);
        if (pricePoints.length < 2) {
            pricePoints = new uint256[](2);
            pricePoints[0] = uint256(keccak256(abi.encode(totalSupply)));
            pricePoints[1] = uint256(keccak256(abi.encode(pricePoints[0])));
        }

        uint256 nb = pricePoints.length - 1;

        if (nb > 10) {
            assembly {
                mstore(pricePoints, 11)
            }
            nb = 10;
        }

        uint256 last;
        for (uint256 i = 0; i <= nb; i++) {
            uint256 current = pricePoints[i];
            current = bound(current, i == 0 ? 0 : last + 1, 1e36 - (nb - i));

            pricePoints[i] = current;
            last = current;
        }

        totalSupply = bound(totalSupply, nb * 10 ** decimalsBase, type(uint128).max / 10 ** (18 - decimalsBase));
        totalSupply = (totalSupply / nb) * nb;

        address baseToken = address(new Decimals(uint8(decimalsBase)));
        address quoteToken = address(new Decimals(uint8(decimalsQuote)));

        bytes memory immutableArgs =
            Helper.getImmutableArgs(baseToken, quoteToken, totalSupply, pricePoints, pricePoints);

        console.log(totalSupply, pricePoints.length);
        _market = MarketTestContract(ImmutableCreate.create2(type(MarketTestContract).runtimeCode, immutableArgs, 0));

        assertEq(_market.getAddress(0), baseToken, "test_deployCurve::1");
        assertEq(_market.getAddress(20), quoteToken, "test_deployCurve::2");
        assertEq(_market.get(40, 64), 10 ** decimalsBase, "test_deployCurve::3");
        assertEq(_market.get(48, 64), 10 ** decimalsQuote, "test_deployCurve::4");
        assertEq(_market.get(56, 128), totalSupply, "test_deployCurve::5");
        assertEq(_market.get(72, 128), (totalSupply / nb) * 1e18 / 10 ** decimalsBase, "test_deployCurve::6");
        assertEq(_market.get(88, 16), pricePoints.length, "test_deployCurve::7");

        for (uint256 i = 0; i < pricePoints.length; i++) {
            assertEq(_market.get(90 + i * 0x20, 128), pricePoints[i], "test_deployCurve::8");
            assertEq(_market.get(106 + i * 0x20, 128), pricePoints[i], "test_deployCurve::9");
        }

        _pricePoints = pricePoints;
        _totalSupply = totalSupply;
        _basePrecision = 10 ** decimalsBase;
        _quotePrecision = 10 ** decimalsQuote;
    }
}

contract MarketTestContract is Market {
    function getAddress(uint256 i) public pure returns (address) {
        return _getAddress(i);
    }

    function get(uint256 i, uint8 size) public pure returns (uint256) {
        return _getUint(i, size);
    }

    function getQuoteAmount(uint256 supply, uint256 baseAmount, bool roundUp) public view returns (uint256, uint256) {
        return _getQuoteAmount(supply, baseAmount, roundUp);
    }

    function getBaseAmountOut(uint256 supply, uint256 quoteAmount) public view returns (uint256, uint256) {
        return _getBaseAmountOut(supply, quoteAmount);
    }

    function getBaseAmountIn(uint256 supply, uint256 quoteAmount) public view returns (uint256, uint256) {
        return _getBaseAmountIn(supply, quoteAmount);
    }
}

contract Decimals {
    uint8 public immutable decimals;

    constructor(uint8 _decimals) {
        decimals = _decimals;
    }
}
