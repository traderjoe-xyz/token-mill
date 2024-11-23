// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";

import "../../src/TMMarket.sol";
import "../../src/libraries/ImmutableCreate.sol";
import "../../src/libraries/ImmutableHelper.sol";

contract PricePointsTest is Test {
    MarketTestContract _market;

    uint256[] _pricePoints = [1e18, 2e18, 4e18, 8e18, 16e18, 32e18];

    uint256 _totalSupply;
    uint256 _basePrecision;
    uint256 _quotePrecision;

    function setUp() public {}

    function test_GetAmount() public {
        uint256 decimalsBase = 9;
        uint256 decimalsQuote = 6;
        uint256 totalSupply = 500_000_000 * 10 ** decimalsBase;

        _deployCurve(_pricePoints, totalSupply, decimalsBase, decimalsQuote);

        {
            uint256 circSupply = 0;
            uint256 base = 10_000_000 * _basePrecision;

            (uint256 actualBaseAmount, uint256 quoteAmount) = _market.getQuoteAmount(circSupply, base, false);
            (uint256 baseAmount, uint256 actualQuoteAmount) = _market.getBaseAmountOut(circSupply, quoteAmount);

            assertEq(actualBaseAmount, baseAmount, "test_GetAmount::1");
            assertEq(actualQuoteAmount, quoteAmount, "test_GetAmount::2");
            assertEq(baseAmount, base, "test_GetAmount::3");
            assertEq(quoteAmount, 10.5e6 * _quotePrecision, "test_GetAmount::4");
        }

        {
            uint256 circSupply = 100_000_000 * _basePrecision;
            uint256 base = 10_000_000 * _basePrecision;

            (uint256 actualBaseAmount, uint256 quoteAmount) = _market.getQuoteAmount(circSupply, base, false);
            (uint256 baseAmount, uint256 actualQuoteAmount) = _market.getBaseAmountOut(circSupply, quoteAmount);

            assertEq(actualBaseAmount, baseAmount, "test_GetAmount::5");
            assertEq(actualQuoteAmount, quoteAmount, "test_GetAmount::6");
            assertEq(baseAmount, base, "test_GetAmount::7");
            assertEq(quoteAmount, 21e6 * _quotePrecision, "test_GetAmount::8");
        }

        {
            uint256 circSupply = 150_000_000 * _basePrecision;
            uint256 base = 10_000_000 * _basePrecision;

            (uint256 actualBaseAmount, uint256 quoteAmount) = _market.getQuoteAmount(circSupply, base, false);
            (uint256 baseAmount, uint256 actualQuoteAmount) = _market.getBaseAmountOut(circSupply, quoteAmount);

            assertEq(actualBaseAmount, baseAmount, "test_GetAmount::9");
            assertEq(actualQuoteAmount, quoteAmount, "test_GetAmount::10");
            assertEq(baseAmount, base, "test_GetAmount::11");
            assertEq(quoteAmount, 31e6 * _quotePrecision, "test_GetAmount::12");
        }

        {
            uint256 circSupply = 150_000_000 * _basePrecision;
            uint256 base = 50_000_000 * _basePrecision;

            (uint256 actualBaseAmount, uint256 quoteAmount) = _market.getQuoteAmount(circSupply, base, false);
            (uint256 baseAmount, uint256 actualQuoteAmount) = _market.getBaseAmountOut(circSupply, quoteAmount);

            assertEq(actualBaseAmount, baseAmount, "test_GetAmount::13");
            assertEq(actualQuoteAmount, quoteAmount, "test_GetAmount::14");
            assertEq(baseAmount, base, "test_GetAmount::15");
            assertEq(quoteAmount, 175e6 * _quotePrecision, "test_GetAmount::16");
        }

        {
            uint256 circSupply = 200_000_000 * _basePrecision;
            uint256 base = 50_000_000 * _basePrecision;

            (uint256 actualBaseAmount, uint256 quoteAmount) = _market.getQuoteAmount(circSupply, base, false);
            (uint256 baseAmount, uint256 actualQuoteAmount) = _market.getBaseAmountOut(circSupply, quoteAmount);

            assertEq(actualBaseAmount, baseAmount, "test_GetAmount::17");
            assertEq(actualQuoteAmount, quoteAmount, "test_GetAmount::18");
            assertEq(baseAmount, base, "test_GetAmount::19");
            assertEq(quoteAmount, 250e6 * _quotePrecision, "test_GetAmount::20");
        }

        {
            uint256 circSupply = 150_000_000 * _basePrecision;
            uint256 base = 100_000_000 * _basePrecision;

            (uint256 actualBaseAmount, uint256 quoteAmount) = _market.getQuoteAmount(circSupply, base, false);
            (uint256 baseAmount, uint256 actualQuoteAmount) = _market.getBaseAmountOut(circSupply, quoteAmount);

            assertEq(actualBaseAmount, baseAmount, "test_GetAmount::21");
            assertEq(actualQuoteAmount, quoteAmount, "test_GetAmount::22");
            assertEq(baseAmount, base, "test_GetAmount::23");
            assertEq(quoteAmount, 425e6 * _quotePrecision, "test_GetAmount::24");
        }

        {
            uint256 circSupply = 0;
            uint256 base = 500_000_000 * _basePrecision;

            (uint256 actualBaseAmount, uint256 quoteAmount) = _market.getQuoteAmount(circSupply, base, false);
            (uint256 baseAmount, uint256 actualQuoteAmount) = _market.getBaseAmountOut(circSupply, quoteAmount);

            assertEq(actualBaseAmount, baseAmount, "test_GetAmount::25");
            assertEq(actualQuoteAmount, quoteAmount, "test_GetAmount::26");
            assertEq(baseAmount, base, "test_GetAmount::27");
            assertEq(quoteAmount, 4650e6 * _quotePrecision, "test_GetAmount::28");
        }

        {
            uint256 circSupply = 0;
            uint256 base = 500_000_000 * _basePrecision + 1;

            (uint256 actualBaseAmount, uint256 quoteAmount) = _market.getQuoteAmount(circSupply, base, false);
            (uint256 baseAmount, uint256 actualQuoteAmount) = _market.getBaseAmountOut(circSupply, quoteAmount + 1);

            assertEq(actualBaseAmount, baseAmount, "test_GetAmount::29");
            assertEq(actualQuoteAmount, quoteAmount, "test_GetAmount::30");
            assertEq(baseAmount, base - 1, "test_GetAmount::31");
            assertEq(quoteAmount, 4650e6 * _quotePrecision, "test_GetAmount::32");
        }
    }

    function test_GetDeltaAmount() public {
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

            assertEq(actualDeltaBaseAmount, -deltaBaseAmount, "test_GetDeltaAmount::1");
            assertEq(-actualDeltaQuoteAmount, deltaQuoteAmount, "test_GetDeltaAmount::2");
        }

        {
            uint256 circSupply = 10_000_000 * _basePrecision;
            int256 deltaBase = 10_000_000 * int256(_basePrecision);

            (int256 actualDeltaBaseAmount, int256 deltaQuoteAmount) = _market.getDeltaQuoteAmount(circSupply, deltaBase);
            (int256 deltaBaseAmount, int256 actualDeltaQuoteAmount) =
                _market.getDeltaBaseAmount(circSupply - uint256(deltaBase), -deltaQuoteAmount);

            assertEq(actualDeltaBaseAmount, -deltaBaseAmount, "test_GetDeltaAmount::3");
            assertEq(-actualDeltaQuoteAmount, deltaQuoteAmount, "test_GetDeltaAmount::4");
        }

        {
            uint256 circSupply = 100_000_000 * _basePrecision;
            int256 deltaBase = -10_000_000 * int256(_basePrecision);

            (int256 actualDeltaBaseAmount, int256 deltaQuoteAmount) = _market.getDeltaQuoteAmount(circSupply, deltaBase);
            (int256 deltaBaseAmount, int256 actualDeltaQuoteAmount) =
                _market.getDeltaBaseAmount(circSupply + uint256(-deltaBase), -deltaQuoteAmount);

            assertEq(actualDeltaBaseAmount, -deltaBaseAmount, "test_GetDeltaAmount::5");
            assertEq(-actualDeltaQuoteAmount, deltaQuoteAmount, "test_GetDeltaAmount::6");
        }

        {
            uint256 circSupply = 110_000_000 * _basePrecision;
            int256 deltaBase = 10_000_000 * int256(_basePrecision);

            (int256 actualDeltaBaseAmount, int256 deltaQuoteAmount) = _market.getDeltaQuoteAmount(circSupply, deltaBase);
            (int256 deltaBaseAmount, int256 actualDeltaQuoteAmount) =
                _market.getDeltaBaseAmount(circSupply - uint256(deltaBase), -deltaQuoteAmount);

            assertEq(actualDeltaBaseAmount, -deltaBaseAmount, "test_GetDeltaAmount::7");
            assertEq(-actualDeltaQuoteAmount, deltaQuoteAmount, "test_GetDeltaAmount::8");
        }

        {
            uint256 circSupply = 90_000_000 * _basePrecision;
            int256 deltaBase = -10_000_000 * int256(_basePrecision);

            (int256 actualDeltaBaseAmount, int256 deltaQuoteAmount) = _market.getDeltaQuoteAmount(circSupply, deltaBase);
            (int256 deltaBaseAmount, int256 actualDeltaQuoteAmount) =
                _market.getDeltaBaseAmount(circSupply + uint256(-deltaBase), -deltaQuoteAmount);

            assertEq(actualDeltaBaseAmount, -deltaBaseAmount, "test_GetDeltaAmount::9");
            assertEq(-actualDeltaQuoteAmount, deltaQuoteAmount, "test_GetDeltaAmount::10");
        }

        {
            uint256 circSupply = 100_000_000 * _basePrecision;
            int256 deltaBase = 10_000_000 * int256(_basePrecision);

            (int256 actualDeltaBaseAmount, int256 deltaQuoteAmount) = _market.getDeltaQuoteAmount(circSupply, deltaBase);
            (int256 deltaBaseAmount, int256 actualDeltaQuoteAmount) =
                _market.getDeltaBaseAmount(circSupply - uint256(deltaBase), -deltaQuoteAmount);

            assertEq(actualDeltaBaseAmount, -deltaBaseAmount, "test_GetDeltaAmount::11");
            assertEq(-actualDeltaQuoteAmount, deltaQuoteAmount, "test_GetDeltaAmount::12");
        }

        {
            uint256 circSupply = 150_000_000 * _basePrecision;
            int256 deltaBase = -10_000_000 * int256(_basePrecision);

            (int256 actualDeltaBaseAmount, int256 deltaQuoteAmount) = _market.getDeltaQuoteAmount(circSupply, deltaBase);
            (int256 deltaBaseAmount, int256 actualDeltaQuoteAmount) =
                _market.getDeltaBaseAmount(circSupply + uint256(-deltaBase), -deltaQuoteAmount);

            assertEq(actualDeltaBaseAmount, -deltaBaseAmount, "test_GetDeltaAmount::13");
            assertEq(-actualDeltaQuoteAmount, deltaQuoteAmount, "test_GetDeltaAmount::14");
        }

        {
            uint256 circSupply = 160_000_000 * _basePrecision;
            int256 deltaBase = 10_000_000 * int256(_basePrecision);

            (int256 actualDeltaBaseAmount, int256 deltaQuoteAmount) = _market.getDeltaQuoteAmount(circSupply, deltaBase);
            (int256 deltaBaseAmount, int256 actualDeltaQuoteAmount) =
                _market.getDeltaBaseAmount(circSupply - uint256(deltaBase), -deltaQuoteAmount);

            assertEq(actualDeltaBaseAmount, -deltaBaseAmount, "test_GetDeltaAmount::15");
            assertEq(-actualDeltaQuoteAmount, deltaQuoteAmount, "test_GetDeltaAmount::16");
        }

        {
            uint256 circSupply = 150_000_000 * _basePrecision;
            int256 deltaBase = -50_000_000 * int256(_basePrecision);

            (int256 actualDeltaBaseAmount, int256 deltaQuoteAmount) = _market.getDeltaQuoteAmount(circSupply, deltaBase);
            (int256 deltaBaseAmount, int256 actualDeltaQuoteAmount) =
                _market.getDeltaBaseAmount(circSupply + uint256(-deltaBase), -deltaQuoteAmount);

            assertEq(actualDeltaBaseAmount, -deltaBaseAmount, "test_GetDeltaAmount::17");
            assertEq(-actualDeltaQuoteAmount, deltaQuoteAmount, "test_GetDeltaAmount::18");
        }

        {
            uint256 circSupply = 200_000_000 * _basePrecision;
            int256 deltaBase = 50_000_000 * int256(_basePrecision);

            (int256 actualDeltaBaseAmount, int256 deltaQuoteAmount) = _market.getDeltaQuoteAmount(circSupply, deltaBase);
            (int256 deltaBaseAmount, int256 actualDeltaQuoteAmount) =
                _market.getDeltaBaseAmount(circSupply - uint256(deltaBase), -deltaQuoteAmount);

            assertEq(actualDeltaBaseAmount, -deltaBaseAmount, "test_GetDeltaAmount::19");
            assertEq(-actualDeltaQuoteAmount, deltaQuoteAmount, "test_GetDeltaAmount::20");
        }

        {
            uint256 circSupply = 150_000_000 * _basePrecision;
            int256 deltaBase = -100_000_000 * int256(_basePrecision);

            (int256 actualDeltaBaseAmount, int256 deltaQuoteAmount) = _market.getDeltaQuoteAmount(circSupply, deltaBase);
            (int256 deltaBaseAmount, int256 actualDeltaQuoteAmount) =
                _market.getDeltaBaseAmount(circSupply + uint256(-deltaBase), -deltaQuoteAmount);

            assertEq(actualDeltaBaseAmount, -deltaBaseAmount, "test_GetDeltaAmount::21");
            assertEq(-actualDeltaQuoteAmount, deltaQuoteAmount, "test_GetDeltaAmount::22");
        }

        {
            uint256 circSupply = 250_000_000 * _basePrecision;
            int256 deltaBase = 100_000_000 * int256(_basePrecision);

            (int256 actualDeltaBaseAmount, int256 deltaQuoteAmount) = _market.getDeltaQuoteAmount(circSupply, deltaBase);
            (int256 deltaBaseAmount, int256 actualDeltaQuoteAmount) =
                _market.getDeltaBaseAmount(circSupply - uint256(deltaBase), -deltaQuoteAmount);

            assertEq(actualDeltaBaseAmount, -deltaBaseAmount, "test_GetDeltaAmount::23");
            assertEq(-actualDeltaQuoteAmount, deltaQuoteAmount, "test_GetDeltaAmount::24");
        }

        {
            uint256 circSupply = 250_000_000 * _basePrecision;
            int256 deltaBase = -100_000_000 * int256(_basePrecision);

            (int256 actualDeltaBaseAmount, int256 deltaQuoteAmount) = _market.getDeltaQuoteAmount(circSupply, deltaBase);
            (int256 deltaBaseAmount, int256 actualDeltaQuoteAmount) =
                _market.getDeltaBaseAmount(circSupply + uint256(-deltaBase), -deltaQuoteAmount);

            assertEq(actualDeltaBaseAmount, -deltaBaseAmount, "test_GetDeltaAmount::25");
            assertEq(-actualDeltaQuoteAmount, deltaQuoteAmount, "test_GetDeltaAmount::26");
        }

        {
            uint256 circSupply = 150_000_000 * _basePrecision;
            int256 deltaBase = 100_000_000 * int256(_basePrecision);

            (int256 actualDeltaBaseAmount, int256 deltaQuoteAmount) = _market.getDeltaQuoteAmount(circSupply, deltaBase);
            (int256 deltaBaseAmount, int256 actualDeltaQuoteAmount) =
                _market.getDeltaBaseAmount(circSupply - uint256(deltaBase), -deltaQuoteAmount);

            assertEq(actualDeltaBaseAmount, -deltaBaseAmount, "test_GetDeltaAmount::27");
            assertEq(-actualDeltaQuoteAmount, deltaQuoteAmount, "test_GetDeltaAmount::28");
        }

        {
            uint256 circSupply = 0;
            int256 deltaBase = -500_000_000 * int256(_basePrecision);

            (int256 actualDeltaBaseAmount, int256 deltaQuoteAmount) = _market.getDeltaQuoteAmount(circSupply, deltaBase);
            (int256 deltaBaseAmount, int256 actualDeltaQuoteAmount) =
                _market.getDeltaBaseAmount(circSupply + uint256(-deltaBase), -deltaQuoteAmount);

            assertEq(actualDeltaBaseAmount, -deltaBaseAmount, "test_GetDeltaAmount::29");
            assertEq(-actualDeltaQuoteAmount, deltaQuoteAmount, "test_GetDeltaAmount::30");
        }

        {
            uint256 circSupply = 500_000_000 * _basePrecision;
            int256 deltaBase = 500_000_000 * int256(_basePrecision);

            (int256 actualDeltaBaseAmount, int256 deltaQuoteAmount) = _market.getDeltaQuoteAmount(circSupply, deltaBase);
            (int256 deltaBaseAmount, int256 actualDeltaQuoteAmount) =
                _market.getDeltaBaseAmount(circSupply - uint256(deltaBase), -deltaQuoteAmount);

            assertEq(actualDeltaBaseAmount, -deltaBaseAmount, "test_GetDeltaAmount::31");
            assertEq(-actualDeltaQuoteAmount, deltaQuoteAmount, "test_GetDeltaAmount::32");
        }

        {
            uint256 circSupply = 0;
            int256 deltaBase = -int256(500_000_000 * _basePrecision);

            (int256 actualDeltaBaseAmount, int256 deltaQuoteAmount) =
                _market.getDeltaQuoteAmount(circSupply, deltaBase - 1);
            (int256 deltaBaseAmount, int256 actualDeltaQuoteAmount) =
                _market.getDeltaBaseAmount(circSupply + uint256(-deltaBase), -(deltaQuoteAmount + 1));

            assertEq(actualDeltaBaseAmount, -deltaBaseAmount, "test_GetDeltaAmount::33");
            assertEq(-actualDeltaQuoteAmount, deltaQuoteAmount, "test_GetDeltaAmount::34");
        }

        {
            uint256 circSupply = 500_000_000 * _basePrecision;
            int256 deltaBase = int256(500_000_000 * _basePrecision);

            (int256 actualDeltaBaseAmount, int256 deltaQuoteAmount) = _market.getDeltaQuoteAmount(circSupply, deltaBase);
            (int256 deltaBaseAmount, int256 actualDeltaQuoteAmount) =
                _market.getDeltaBaseAmount(circSupply - uint256(deltaBase), -(deltaQuoteAmount) + 1);

            assertEq(actualDeltaBaseAmount, -deltaBaseAmount, "test_GetDeltaAmount::35");
            assertEq(-actualDeltaQuoteAmount, deltaQuoteAmount, "test_GetDeltaAmount::36");
        }
    }

    function test_Fuzz_GetQuoteAmount(
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

            assertGe(actualBaseAmount, baseAmount, "test_Fuzz_GetQuoteAmount::1");
            assertGe(base, actualBaseAmount, "test_Fuzz_GetQuoteAmount::2");
        }

        {
            (uint256 actualBaseAmount, uint256 quoteAmount) = _market.getQuoteAmount(circSupply, base, true);
            (uint256 baseAmount,) = _market.getBaseAmountIn(circSupply + actualBaseAmount, quoteAmount);

            assertLe(actualBaseAmount, baseAmount, "test_Fuzz_GetQuoteAmount::3");
            assertGe(base, actualBaseAmount, "test_Fuzz_GetQuoteAmount::4");
        }
    }

    function test_Fuzz_GetBaseAmount(
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

            assertGe(actualQuoteAmount, quoteAmount, "test_Fuzz_GetBaseAmount::1");
            assertGe(quote, actualQuoteAmount, "test_Fuzz_GetBaseAmount::2");
        }

        {
            (uint256 baseAmount, uint256 actualQuoteAmount) = _market.getBaseAmountIn(circSupply, quote);
            (, uint256 quoteAmount) = _market.getQuoteAmount(circSupply - baseAmount, baseAmount, true);

            assertLe(actualQuoteAmount, quoteAmount, "test_Fuzz_GetBaseAmount::3");
            assertGe(quote, actualQuoteAmount, "test_Fuzz_GetBaseAmount::4");
        }
    }

    function test_Fuzz_GetDeltaQuoteAmount(
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
            assertEq(actualDeltaBaseAmount, 0, "test_Fuzz_GetDeltaQuoteAmount::1");
            assertEq(deltaQuoteAmount, 0, "test_Fuzz_GetDeltaQuoteAmount::2");
            assertEq(deltaBaseAmount, 0, "test_Fuzz_GetDeltaQuoteAmount::3");
            assertEq(actualDeltaQuoteAmount, 0, "test_Fuzz_GetDeltaQuoteAmount::4");
        } else if (deltaBase > 0) {
            assertGe(actualDeltaBaseAmount, 0, "test_Fuzz_GetDeltaQuoteAmount::5");
            assertLe(deltaQuoteAmount, 0, "test_Fuzz_GetDeltaQuoteAmount::6");
            assertLe(deltaBaseAmount, 0, "test_Fuzz_GetDeltaQuoteAmount::7");
            assertGe(actualDeltaQuoteAmount, 0, "test_Fuzz_GetDeltaQuoteAmount::8");

            assertGe(deltaBase, actualDeltaBaseAmount, "test_Fuzz_GetDeltaQuoteAmount::9");
            assertGe(actualDeltaBaseAmount, -deltaBaseAmount, "test_Fuzz_GetDeltaQuoteAmount::10");
        } else {
            assertLe(actualDeltaBaseAmount, 0, "test_Fuzz_GetDeltaQuoteAmount::11");
            assertGe(deltaQuoteAmount, 0, "test_Fuzz_GetDeltaQuoteAmount::12");
            assertGe(deltaBaseAmount, 0, "test_Fuzz_GetDeltaQuoteAmount::13");
            assertLe(actualDeltaQuoteAmount, 0, "test_Fuzz_GetDeltaQuoteAmount::14");

            assertGe(-deltaBase, -actualDeltaBaseAmount, "test_Fuzz_GetDeltaQuoteAmount::15");
            assertLe(-actualDeltaBaseAmount, deltaBaseAmount, "test_Fuzz_GetDeltaQuoteAmount::16");
        }
    }

    function test_Fuzz_GetDeltaBaseAmount(
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
            assertEq(deltaBaseAmount, 0, "test_Fuzz_GetDeltaBaseAmount::1");
            assertEq(actualDeltaQuoteAmount, 0, "test_Fuzz_GetDeltaBaseAmount::2");
            assertEq(actualDeltaBaseAmount, 0, "test_Fuzz_GetDeltaBaseAmount::3");
            assertEq(deltaQuoteAmount, 0, "test_Fuzz_GetDeltaBaseAmount::4");
        } else if (deltaQuote > 0) {
            assertLe(deltaBaseAmount, 0, "test_Fuzz_GetDeltaBaseAmount::5");
            assertGe(actualDeltaQuoteAmount, 0, "test_Fuzz_GetDeltaBaseAmount::6");
            assertGe(actualDeltaBaseAmount, 0, "test_Fuzz_GetDeltaBaseAmount::7");
            assertLe(deltaQuoteAmount, 0, "test_Fuzz_GetDeltaBaseAmount::8");

            assertGe(deltaQuote, actualDeltaQuoteAmount, "test_Fuzz_GetDeltaBaseAmount::9");
            assertGe(actualDeltaQuoteAmount, -deltaQuoteAmount, "test_Fuzz_GetDeltaBaseAmount::10");
        } else {
            assertGe(deltaBaseAmount, 0, "test_Fuzz_GetDeltaBaseAmount::11");
            assertLe(actualDeltaQuoteAmount, 0, "test_Fuzz_GetDeltaBaseAmount::12");
            assertLe(actualDeltaBaseAmount, 0, "test_Fuzz_GetDeltaBaseAmount::13");
            assertGe(deltaQuoteAmount, 0, "test_Fuzz_GetDeltaBaseAmount::14");

            assertGe(-deltaQuote, -actualDeltaQuoteAmount, "test_Fuzz_GetDeltaBaseAmount::15");
            assertLe(-actualDeltaQuoteAmount, deltaQuoteAmount, "test_Fuzz_GetDeltaBaseAmount::16");
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

    function test_Fuzz_GetDeltaQuoteAmountSplitFirstSwap(
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

            assertEq(actualDeltaBaseAmount0, deltaBase0, "test_Fuzz_GetDeltaQuoteAmountSplitFirstSwap::1");
            assertEq(actualDeltaBaseAmount1, deltaBase1, "test_Fuzz_GetDeltaQuoteAmountSplitFirstSwap::2");
            assertEq(
                actualDeltaQuoteAmount01,
                -(deltaQuoteAmount0 + deltaQuoteAmount1),
                "test_Fuzz_GetDeltaQuoteAmountSplitFirstSwap::3"
            );

            assertLe(deltaQuoteAmount0, 0, "test_Fuzz_GetDeltaQuoteAmountSplitFirstSwap::4");
            assertLe(deltaQuoteAmount1, 0, "test_Fuzz_GetDeltaQuoteAmountSplitFirstSwap::5");
            assertLe(deltaBaseAmount01, 0, "test_Fuzz_GetDeltaQuoteAmountSplitFirstSwap::6");

            assertLe(-deltaBaseAmount01, deltaBase0 + deltaBase1, "test_Fuzz_GetDeltaQuoteAmountSplitFirstSwap::7");
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

            assertEq(actualDeltaBaseAmount0, deltaBase0, "test_Fuzz_GetDeltaQuoteAmountSplitFirstSwap::8");
            assertEq(actualDeltaBaseAmount1, deltaBase1, "test_Fuzz_GetDeltaQuoteAmountSplitFirstSwap::9");
            assertLe(
                -actualDeltaQuoteAmount01,
                (deltaQuoteAmount0 + deltaQuoteAmount1),
                "test_Fuzz_GetDeltaQuoteAmountSplitFirstSwap::10"
            ); // Not always eq due to rounding

            assertGe(deltaQuoteAmount0, 0, "test_Fuzz_GetDeltaQuoteAmountSplitFirstSwap::11");
            assertGe(deltaQuoteAmount1, 0, "test_Fuzz_GetDeltaQuoteAmountSplitFirstSwap::12");
            assertGe(deltaBaseAmount01, 0, "test_Fuzz_GetDeltaQuoteAmountSplitFirstSwap::13");

            assertGe(deltaBaseAmount01, -(deltaBase0 + deltaBase1), "test_Fuzz_GetDeltaQuoteAmountSplitFirstSwap::14");
        }
    }

    function test_Fuzz_GetDeltaQuoteAmountSplitSecondSwap(
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

            assertEq(actualDeltaBaseAmount0, deltaBase0, "test_Fuzz_GetDeltaQuoteAmountSplitSecondSwap::1");
            assertEq(actualDeltaQuoteAmount1, -deltaQuoteAmount1, "test_Fuzz_GetDeltaQuoteAmountSplitSecondSwap::2");
            assertEq(actualDeltaQuoteAmount2, -deltaQuoteAmount2, "test_Fuzz_GetDeltaQuoteAmountSplitSecondSwap::3");

            assertLe(deltaQuoteAmount0, 0, "test_Fuzz_GetDeltaQuoteAmountSplitSecondSwap::4");
            assertLe(deltaBaseAmount1, 0, "test_Fuzz_GetDeltaQuoteAmountSplitSecondSwap::5");
            assertLe(deltaBaseAmount2, 0, "test_Fuzz_GetDeltaQuoteAmountSplitSecondSwap::6");

            assertLe(
                -(deltaBaseAmount1 + deltaBaseAmount2), deltaBase0, "test_Fuzz_GetDeltaQuoteAmountSplitSecondSwap::7"
            );
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

            assertEq(actualDeltaBaseAmount0, deltaBase0, "test_Fuzz_GetDeltaQuoteAmountSplitSecondSwap::8");
            assertLe(-actualDeltaQuoteAmount1, deltaQuoteAmount1, "test_Fuzz_GetDeltaQuoteAmountSplitSecondSwap::9");
            assertLe(-actualDeltaQuoteAmount2, deltaQuoteAmount2, "test_Fuzz_GetDeltaQuoteAmountSplitSecondSwap::10");

            assertGe(deltaQuoteAmount0, 0, "test_Fuzz_GetDeltaQuoteAmountSplitSecondSwap::11");
            assertGe(deltaBaseAmount1, 0, "test_Fuzz_GetDeltaQuoteAmountSplitSecondSwap::12");
            assertGe(deltaBaseAmount2, 0, "test_Fuzz_GetDeltaQuoteAmountSplitSecondSwap::13");

            assertGe(
                (deltaBaseAmount1 + deltaBaseAmount2), -deltaBase0, "test_Fuzz_GetDeltaQuoteAmountSplitSecondSwap::14"
            );
        }
    }

    function test_Fuzz_GetDeltaBaseAmountSplitFirstSwap(
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

            assertEq(actualDeltaQuoteAmount0, deltaQuote0, "test_Fuzz_GetDeltaBaseAmountSplitFirstSwap::1");
            assertEq(actualDeltaQuoteAmount1, deltaQuote1, "test_Fuzz_GetDeltaBaseAmountSplitFirstSwap::2");
            assertEq(
                actualDeltaBaseAmount01,
                -(deltaBaseAmount0 + deltaBaseAmount1),
                "test_Fuzz_GetDeltaBaseAmountSplitFirstSwap::3"
            );

            assertLe(deltaBaseAmount0, 0, "test_Fuzz_GetDeltaBaseAmountSplitFirstSwap::4");
            assertLe(deltaBaseAmount1, 0, "test_Fuzz_GetDeltaBaseAmountSplitFirstSwap::5");
            assertLe(deltaQuoteAmount01, 0, "test_Fuzz_GetDeltaBaseAmountSplitFirstSwap::6");

            assertLe(-deltaQuoteAmount01, deltaQuote0 + deltaQuote1, "test_Fuzz_GetDeltaBaseAmountSplitFirstSwap::7");
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

            assertEq(actualDeltaQuoteAmount0, deltaQuote0, "test_Fuzz_GetDeltaBaseAmountSplitFirstSwap::8");
            assertLe(-actualDeltaQuoteAmount1, -deltaQuote1, "test_Fuzz_GetDeltaBaseAmountSplitFirstSwap::9");
            assertLe(
                actualDeltaBaseAmount01,
                -(deltaBaseAmount0 + deltaBaseAmount1),
                "test_Fuzz_GetDeltaBaseAmountSplitFirstSwap::10"
            ); // Not always eq due to rounding

            assertGe(deltaBaseAmount0, 0, "test_Fuzz_GetDeltaBaseAmountSplitFirstSwap::11");
            assertGe(deltaBaseAmount1, 0, "test_Fuzz_GetDeltaBaseAmountSplitFirstSwap::12");
            assertGe(deltaQuoteAmount01, 0, "test_Fuzz_GetDeltaBaseAmountSplitFirstSwap::13");

            assertGe(
                deltaQuoteAmount01,
                -(actualDeltaQuoteAmount0 + actualDeltaQuoteAmount1),
                "test_Fuzz_GetDeltaBaseAmountSplitFirstSwap::14"
            );
        }
    }

    function test_Fuzz_GetDeltaBaseAmountSplitSecondSwap(
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

            assertEq(actualDeltaQuoteAmount0, deltaQuote0, "test_Fuzz_GetDeltaBaseAmountSplitSecondSwap::1");
            assertEq(actualDeltaBaseAmount1, -deltaBaseAmount1, "test_Fuzz_GetDeltaBaseAmountSplitSecondSwap::2");
            assertEq(actualDeltaBaseAmount2, -deltaBaseAmount2, "test_Fuzz_GetDeltaBaseAmountSplitSecondSwap::3");

            assertLe(deltaBaseAmount0, 0, "test_Fuzz_GetDeltaBaseAmountSplitSecondSwap::4");
            assertLe(deltaQuoteAmount1, 0, "test_Fuzz_GetDeltaBaseAmountSplitSecondSwap::5");
            assertLe(deltaQuoteAmount2, 0, "test_Fuzz_GetDeltaBaseAmountSplitSecondSwap::6");

            assertLe(
                -(deltaQuoteAmount1 + deltaQuoteAmount2), deltaQuote0, "test_Fuzz_GetDeltaBaseAmountSplitSecondSwap::7"
            );
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

            assertEq(actualDeltaQuoteAmount0, deltaQuote0, "test_Fuzz_GetDeltaBaseAmountSplitSecondSwap::8");
            // Not always eq due to rounding
            assertLe(-actualDeltaBaseAmount1, deltaBaseAmount1, "test_Fuzz_GetDeltaBaseAmountSplitSecondSwap::9");
            assertLe(-actualDeltaBaseAmount2, deltaBaseAmount2, "test_Fuzz_GetDeltaBaseAmountSplitSecondSwap::10");

            assertGe(deltaBaseAmount0, 0, "test_Fuzz_GetDeltaBaseAmountSplitSecondSwap::11");
            assertGe(deltaQuoteAmount1, 0, "test_Fuzz_GetDeltaBaseAmountSplitSecondSwap::12");
            assertGe(deltaQuoteAmount2, 0, "test_Fuzz_GetDeltaBaseAmountSplitSecondSwap::13");

            assertGe(
                -(deltaBaseAmount1 + deltaBaseAmount2),
                actualDeltaBaseAmount1 + actualDeltaBaseAmount2,
                "test_Fuzz_GetDeltaBaseAmountSplitSecondSwap::14"
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
            assembly ("memory-safe") {
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

        uint256[] memory packedPrices = ImmutableHelper.packPrices(pricePoints, pricePoints);

        bytes memory immutableArgs =
            ImmutableHelper.getImmutableArgs(address(this), baseToken, quoteToken, totalSupply, packedPrices);

        console.log(totalSupply, pricePoints.length);
        _market = MarketTestContract(ImmutableCreate.create2(type(MarketTestContract).runtimeCode, immutableArgs, 0));

        assertEq(_market.getAddress(0), address(this), "_deployCurve::1");
        assertEq(_market.getAddress(20), baseToken, "_deployCurve::2");
        assertEq(_market.getAddress(40), quoteToken, "_deployCurve::3");
        assertEq(_market.get(60, 64), 10 ** decimalsBase, "_deployCurve::4");
        assertEq(_market.get(68, 64), 10 ** decimalsQuote, "_deployCurve::5");
        assertEq(_market.get(76, 128), totalSupply, "_deployCurve::6");
        assertEq(_market.get(92, 128), (totalSupply / nb) * 1e18 / 10 ** decimalsBase, "_deployCurve::7");
        assertEq(_market.get(108, 8), pricePoints.length, "_deployCurve::8");

        for (uint256 i = 0; i < pricePoints.length; i++) {
            assertEq(_market.get(109 + i * 0x20, 128), pricePoints[i], "_deployCurve::9");
            assertEq(_market.get(125 + i * 0x20, 128), pricePoints[i], "_deployCurve::10");
        }

        _pricePoints = pricePoints;
        _totalSupply = totalSupply;
        _basePrecision = 10 ** decimalsBase;
        _quotePrecision = 10 ** decimalsQuote;
    }
}

contract MarketTestContract is TMMarket {
    function getAddress(uint256 i) public pure returns (address) {
        return _getAddress(i);
    }

    function get(uint256 i, uint8 size) public pure returns (uint256) {
        return _getUint(i, size);
    }

    function getQuoteAmount(uint256 supply, uint256 baseAmount, bool roundUp) public view returns (uint256, uint256) {
        return _getQuoteAmount(supply, baseAmount, roundUp, roundUp);
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
