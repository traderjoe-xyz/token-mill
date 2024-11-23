// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./TestHelper.sol";

contract TestRouterMultipleVersion is Test {
    address v1Factory = 0x9Ad6C38BE94206cA50bb0d90783181662f0Cfa10;
    address v2_0Factory = 0x6E77932A92582f504FF6c4BdbCef7Da6c198aEEf;
    address v2_0Router = 0xE3Ffc583dC176575eEA7FD9dF2A7c65F7E23f4C3;
    address v2_1Factory = 0x8e42f2F4101563bF679975178e880FD87d3eFd4e;

    WNative wavax = WNative(0xB31f66AA3C1e785363F0875A1B74E27b85FD66c7);
    IERC20 usdc = IERC20(0xB97EF9Ef8734C71904D8002F8b6Bc66Dd9c48a6E);

    address v1wu = 0xf4003F4efBE8691B60249E6afbD307aBE7758adb;
    uint32 v1wu_id = PackedRoute.encodeId(1, 0, 0);

    address v2_0wu = 0xB5352A39C11a81FE6748993D586EC448A01f08b5;
    uint32 v2_0wu_id = PackedRoute.encodeId(2, 0, 20);

    address v2_1wu = 0xD446eb1660F766d533BeCeEf890Df7A69d26f7d1;
    uint32 v2_1wu_id = PackedRoute.encodeId(2, 1, 20);

    uint256 initialWavaxBalance = 1_000_000e18;
    uint256 initialUsdcBalance = 10_000_000e6;

    ITMFactory public factory;
    Router public router;
    TMERC20 public basicToken;

    address token0;
    address token1;

    address market0w;
    address market1u;

    function setUp() public {
        vm.createSelectFork(StdChains.getChain("avalanche").rpcUrl, 45959572);

        address factoryImp = address(new TMFactory(address(1), address(1)));
        factory = ITMFactory(
            address(
                new TransparentUpgradeableProxy(
                    factoryImp,
                    address(this),
                    abi.encodeCall(TMFactory.initialize, (0.2e4, 0.5e4, address(this), address(this)))
                )
            )
        );

        router = new Router(v1Factory, v2_0Router, v2_1Factory, address(0), address(factory), address(wavax));

        basicToken = new TMERC20(address(factory));

        factory.updateTokenImplementation(1, address(basicToken));

        factory.addQuoteToken(address(usdc));
        factory.addQuoteToken(address(wavax));

        uint256[] memory askPrices = new uint256[](3);
        askPrices[0] = 0e18;
        askPrices[1] = 1e18;
        askPrices[2] = 1000e18;

        uint256[] memory bidPrices = new uint256[](3);
        bidPrices[0] = 0;
        bidPrices[1] = 0.1e18;
        bidPrices[2] = 1000e18;

        ITMFactory.MarketCreationParameters memory params = ITMFactory.MarketCreationParameters(
            1, "Token0", "T0", address(wavax), 500_000_000e18, 0.2e4, 0.6e4, bidPrices, askPrices, abi.encode(18)
        );

        (token0, market0w) = factory.createMarketAndToken(params);

        askPrices[0] = 0.1e18;
        askPrices[1] = 10e18;
        askPrices[2] = 11e18;

        bidPrices[0] = 0.1e18;
        bidPrices[1] = 9e18;
        bidPrices[2] = 11e18;

        params = ITMFactory.MarketCreationParameters(
            1, "Token1", "T1", address(usdc), 100_000_000e18, 0.2e4, 0.6e4, bidPrices, askPrices, abi.encode(18)
        );

        (token1, market1u) = factory.createMarketAndToken(params);

        deal(address(usdc), address(this), initialUsdcBalance);
        deal(address(wavax), address(this), initialWavaxBalance);

        usdc.approve(address(router), initialUsdcBalance);
        wavax.approve(address(router), initialWavaxBalance);

        vm.label(address(factory), "TMFactory");
        vm.label(address(router), "Router");
        vm.label(address(basicToken), "TMERC20 Implementation");
        vm.label(address(v1Factory), "v1Factory");
        vm.label(address(v2_0Factory), "v2_0Factory");
        vm.label(address(v2_0Router), "v2_0Router");
        vm.label(address(v2_1Factory), "v2_1Factory");
        vm.label(address(v1wu), "v1wu");
        vm.label(address(v2_0wu), "v2_0wu");
        vm.label(address(v2_1wu), "v2_1wu");
        vm.label(address(token0), "Token0");
        vm.label(address(token1), "Token1");
        vm.label(address(usdc), "USDC");
        vm.label(address(wavax), "WAVAX");
    }

    receive() external payable {}

    function test_SwapExactInTtoTSingleHopV1() public {
        bytes memory route = abi.encodePacked(wavax, v1wu_id, usdc);

        uint256 v1UsdcBalance = usdc.balanceOf(v1wu);
        uint256 v1WavaxBalance = wavax.balanceOf(v1wu);

        assertEq(wavax.balanceOf(address(this)), initialWavaxBalance, "test_SwapExactInTtoTSingleHopV1::1");
        assertEq(usdc.balanceOf(address(this)), initialUsdcBalance, "test_SwapExactInTtoTSingleHopV1::2");

        uint256 amountIn = 10e18;
        uint256 expectedAmountOut = (v1UsdcBalance * amountIn * 997) / (v1WavaxBalance * 1000 + amountIn * 997);

        (, uint256 amountOut) = router.swapExactIn(route, address(this), amountIn, 0, block.timestamp, address(0));

        assertEq(expectedAmountOut, amountOut, "test_SwapExactInTtoTSingleHopV1::3");

        assertEq(wavax.balanceOf(address(this)), initialWavaxBalance - amountIn, "test_SwapExactInTtoTSingleHopV1::4");
        assertEq(usdc.balanceOf(address(this)), initialUsdcBalance + amountOut, "test_SwapExactInTtoTSingleHopV1::5");
        assertEq(usdc.balanceOf(v1wu), v1UsdcBalance - amountOut, "test_SwapExactInTtoTSingleHopV1::6");
        assertEq(wavax.balanceOf(v1wu), v1WavaxBalance + amountIn, "test_SwapExactInTtoTSingleHopV1::7");
    }

    function test_SwapExactInTtoTSingleHopV2_0() public {
        bytes memory route = abi.encodePacked(wavax, v2_0wu_id, usdc);

        uint256 v2_0UsdcBalance = usdc.balanceOf(v2_0wu);
        uint256 v2_0WavaxBalance = wavax.balanceOf(v2_0wu);

        assertEq(wavax.balanceOf(address(this)), initialWavaxBalance, "test_SwapExactInTtoTSingleHopV2_0::1");
        assertEq(usdc.balanceOf(address(this)), initialUsdcBalance, "test_SwapExactInTtoTSingleHopV2_0::2");

        uint256 amountIn = 1e15;
        (uint256 expectedAmountOut,) = IV2_0Router(v2_0Router).getSwapOut(v2_0wu, amountIn, true);

        (, uint256 amountOut) = router.swapExactIn(route, address(this), amountIn, 0, block.timestamp, address(0));

        assertEq(expectedAmountOut, amountOut, "test_SwapExactInTtoTSingleHopV2_0::3");

        assertEq(wavax.balanceOf(address(this)), initialWavaxBalance - amountIn, "test_SwapExactInTtoTSingleHopV2_0::4");
        assertEq(usdc.balanceOf(address(this)), initialUsdcBalance + amountOut, "test_SwapExactInTtoTSingleHopV2_0::5");
        assertEq(usdc.balanceOf(v2_0wu), v2_0UsdcBalance - amountOut, "test_SwapExactInTtoTSingleHopV2_0::6");
        assertEq(wavax.balanceOf(v2_0wu), v2_0WavaxBalance + amountIn, "test_SwapExactInTtoTSingleHopV2_0::7");
    }

    function test_SwapExactInTtoTSingleHopV2_1() public {
        bytes memory route = abi.encodePacked(wavax, v2_1wu_id, usdc);

        uint256 v2_1UsdcBalance = usdc.balanceOf(v2_1wu);
        uint256 v2_1WavaxBalance = wavax.balanceOf(v2_1wu);

        assertEq(wavax.balanceOf(address(this)), initialWavaxBalance, "test_SwapExactInTtoTSingleHopV2_1::1");
        assertEq(usdc.balanceOf(address(this)), initialUsdcBalance, "test_SwapExactInTtoTSingleHopV2_1::2");

        uint128 amountIn = 10e18;
        (, uint256 expectedAmountOut,) = IV2_1Pair(v2_1wu).getSwapOut(amountIn, true);

        (, uint256 amountOut) = router.swapExactIn(route, address(this), amountIn, 0, block.timestamp, address(0));

        assertEq(expectedAmountOut, amountOut, "test_SwapExactInTtoTSingleHopV2_1::3");

        assertEq(wavax.balanceOf(address(this)), initialWavaxBalance - amountIn, "test_SwapExactInTtoTSingleHopV2_1::4");
        assertEq(usdc.balanceOf(address(this)), initialUsdcBalance + amountOut, "test_SwapExactInTtoTSingleHopV2_1::5");
        assertEq(usdc.balanceOf(v2_1wu), v2_1UsdcBalance - amountOut, "test_SwapExactInTtoTSingleHopV2_1::6");
        assertEq(wavax.balanceOf(v2_1wu), v2_1WavaxBalance + amountIn, "test_SwapExactInTtoTSingleHopV2_1::7");
    }

    function test_SwapExactInTtoTtoTSingleHopV1() public {
        bytes memory route = abi.encodePacked(wavax, v1wu_id, usdc);

        uint256 v1UsdcBalance = usdc.balanceOf(v1wu);
        uint256 v1WavaxBalance = wavax.balanceOf(v1wu);

        uint256 amountIn = 1e18;
        uint256 expectedAmountOut = (v1UsdcBalance * amountIn * 997) / (v1WavaxBalance * 1000 + amountIn * 997);

        (, uint256 amountOut) = router.swapExactIn(route, address(this), amountIn, 0, block.timestamp, address(0));

        assertEq(amountOut, expectedAmountOut, "test_SwapExactInTtoTtoTSingleHopV1::1");
        assertEq(
            wavax.balanceOf(address(this)), initialWavaxBalance - amountIn, "test_SwapExactInTtoTtoTSingleHopV1::2"
        );
        assertEq(usdc.balanceOf(address(this)), initialUsdcBalance + amountOut, "test_SwapExactInTtoTtoTSingleHopV1::3");

        v1UsdcBalance = usdc.balanceOf(v1wu);
        v1WavaxBalance = wavax.balanceOf(v1wu);

        uint256 amountIn2 = amountOut;
        uint256 expectedAmountOut2 = (v1WavaxBalance * amountIn2 * 997) / (v1UsdcBalance * 1000 + amountIn2 * 997);

        route = abi.encodePacked(usdc, v1wu_id, wavax);

        (, uint256 amountOut2) = router.swapExactIn(route, address(this), amountIn2, 0, block.timestamp, address(0));

        assertEq(amountOut2, expectedAmountOut2, "test_SwapExactInTtoTtoTSingleHopV1::4");
        assertEq(
            wavax.balanceOf(address(this)),
            initialWavaxBalance - amountIn + amountOut2,
            "test_SwapExactInTtoTtoTSingleHopV1::5"
        );
        assertEq(
            usdc.balanceOf(address(this)),
            initialUsdcBalance + amountOut - amountIn2,
            "test_SwapExactInTtoTtoTSingleHopV1::6"
        );
    }

    function test_SwapExactInTtoTtoTSingleHopV2_0() public {
        bytes memory route = abi.encodePacked(wavax, v2_0wu_id, usdc);

        uint256 v2_0UsdcBalance = usdc.balanceOf(v2_0wu);
        uint256 v2_0WavaxBalance = wavax.balanceOf(v2_0wu);

        uint256 amountIn = 1e18;
        (uint256 expectedAmountOut,) = IV2_0Router(v2_0Router).getSwapOut(v2_0wu, amountIn, true);

        (, uint256 amountOut) = router.swapExactIn(route, address(this), amountIn, 0, block.timestamp, address(0));

        assertEq(expectedAmountOut, amountOut, "test_SwapExactInTtoTtoTSingleHopV2_0::1");
        assertEq(
            wavax.balanceOf(address(this)), initialWavaxBalance - amountIn, "test_SwapExactInTtoTtoTSingleHopV2_0::2"
        );
        assertEq(
            usdc.balanceOf(address(this)), initialUsdcBalance + amountOut, "test_SwapExactInTtoTtoTSingleHopV2_0::3"
        );

        v2_0UsdcBalance = usdc.balanceOf(v2_0wu);
        v2_0WavaxBalance = wavax.balanceOf(v2_0wu);

        uint256 amountIn2 = amountOut;
        (uint256 expectedAmountOut2,) = IV2_0Router(v2_0Router).getSwapOut(v2_0wu, amountIn2, false);

        route = abi.encodePacked(usdc, v2_0wu_id, wavax);

        (, uint256 amountOut2) = router.swapExactIn(route, address(this), amountIn2, 0, block.timestamp, address(0));

        assertEq(expectedAmountOut2, amountOut2, "test_SwapExactInTtoTtoTSingleHopV2_0::4");
        assertEq(
            wavax.balanceOf(address(this)),
            initialWavaxBalance - amountIn + amountOut2,
            "test_SwapExactInTtoTtoTSingleHopV2_0::5"
        );
        assertEq(
            usdc.balanceOf(address(this)),
            initialUsdcBalance + amountOut - amountIn2,
            "test_SwapExactInTtoTtoTSingleHopV2_0::6"
        );
    }

    function test_SwapExactInTtoTtoTSingleHopV2_1() public {
        bytes memory route = abi.encodePacked(wavax, v2_1wu_id, usdc);

        uint256 v2_1UsdcBalance = usdc.balanceOf(v2_1wu);
        uint256 v2_1WavaxBalance = wavax.balanceOf(v2_1wu);

        uint128 amountIn = 1e18;
        (, uint256 expectedAmountOut,) = IV2_1Pair(v2_1wu).getSwapOut(amountIn, true);

        (, uint256 amountOut) = router.swapExactIn(route, address(this), amountIn, 0, block.timestamp, address(0));

        assertEq(expectedAmountOut, amountOut, "test_SwapExactInTtoTtoTSingleHopV2_1::1");
        assertEq(
            wavax.balanceOf(address(this)), initialWavaxBalance - amountIn, "test_SwapExactInTtoTtoTSingleHopV2_1::2"
        );
        assertEq(
            usdc.balanceOf(address(this)), initialUsdcBalance + amountOut, "test_SwapExactInTtoTtoTSingleHopV2_1::3"
        );

        v2_1UsdcBalance = usdc.balanceOf(v2_1wu);
        v2_1WavaxBalance = wavax.balanceOf(v2_1wu);

        uint128 amountIn2 = uint128(amountOut);
        (, uint256 expectedAmountOut2,) = IV2_1Pair(v2_1wu).getSwapOut(amountIn2, false);

        route = abi.encodePacked(usdc, v2_1wu_id, wavax);

        (, uint256 amountOut2) = router.swapExactIn(route, address(this), amountIn2, 0, block.timestamp, address(0));

        assertEq(expectedAmountOut2, amountOut2, "test_SwapExactInTtoTtoTSingleHopV2_1::4");
        assertEq(
            wavax.balanceOf(address(this)),
            initialWavaxBalance - amountIn + amountOut2,
            "test_SwapExactInTtoTtoTSingleHopV2_1::5"
        );
        assertEq(
            usdc.balanceOf(address(this)),
            initialUsdcBalance + amountOut - amountIn2,
            "test_SwapExactInTtoTtoTSingleHopV2_1::6"
        );
    }

    function test_SwapExactInTtoTtoTMultiHop() public {
        bytes memory route =
            abi.encodePacked(wavax, v1wu_id, usdc, v2_1wu_id, wavax, v2_0wu_id, usdc, uint32(3 << 24), token1);

        uint256 v1UsdcBalance = usdc.balanceOf(v1wu);
        uint256 v1WavaxBalance = wavax.balanceOf(v1wu);

        uint256 amountIn = 1e18;
        uint256 expectedAmountOut = (v1UsdcBalance * amountIn * 997) / (v1WavaxBalance * 1000 + amountIn * 997);
        (, expectedAmountOut,) = IV2_1Pair(v2_1wu).getSwapOut(uint128(expectedAmountOut), false);
        (expectedAmountOut,) = IV2_0Router(v2_0Router).getSwapOut(v2_0wu, expectedAmountOut, true);
        (int256 deltaBase,,) = ITMMarket(market1u).getDeltaAmounts(int256(expectedAmountOut), false);

        expectedAmountOut = uint256(-deltaBase);

        (, uint256 amountOut) = router.swapExactIn(route, address(this), amountIn, 0, block.timestamp, address(0));

        assertEq(amountOut, expectedAmountOut, "test_SwapExactInTtoTtoTMultiHop::1");
        assertEq(wavax.balanceOf(address(this)), initialWavaxBalance - amountIn, "test_SwapExactInTtoTtoTMultiHop::2");
        assertEq(IERC20(token1).balanceOf(address(this)), amountOut, "test_SwapExactInTtoTtoTMultiHop::3");

        IERC20(token1).approve(address(router), amountOut);

        route = abi.encodePacked(token1, uint32(3 << 24), usdc, v2_0wu_id, wavax, v2_1wu_id, usdc, v1wu_id, wavax);

        v1UsdcBalance = usdc.balanceOf(v1wu);
        v1WavaxBalance = wavax.balanceOf(v1wu);

        uint256 amountIn2 = amountOut;
        (, int256 deltaQuote,) = ITMMarket(market1u).getDeltaAmounts(int256(amountIn2), true);
        (uint256 expectedAmountOut2,) = IV2_0Router(v2_0Router).getSwapOut(v2_0wu, uint256(-deltaQuote), false);
        (, expectedAmountOut2,) = IV2_1Pair(v2_1wu).getSwapOut(uint128(expectedAmountOut2), true);
        expectedAmountOut2 =
            (v1WavaxBalance * expectedAmountOut2 * 997) / (v1UsdcBalance * 1000 + expectedAmountOut2 * 997);

        (, uint256 amountOut2) = router.swapExactIn(route, address(this), amountIn2, 0, block.timestamp, address(0));

        assertEq(amountOut2, expectedAmountOut2, "test_SwapExactInTtoTtoTMultiHop::4");
        assertEq(
            wavax.balanceOf(address(this)),
            initialWavaxBalance - amountIn + amountOut2,
            "test_SwapExactInTtoTtoTMultiHop::5"
        );
        assertEq(
            usdc.balanceOf(address(this)),
            initialUsdcBalance + amountOut - amountIn2,
            "test_SwapExactInTtoTtoTMultiHop::6"
        );
    }

    function test_SwapExactOutTtoTSingleHopV1() public {
        bytes memory route = abi.encodePacked(wavax, v1wu_id, usdc);

        uint256 v1UsdcBalance = usdc.balanceOf(v1wu);
        uint256 v1WavaxBalance = wavax.balanceOf(v1wu);

        assertEq(wavax.balanceOf(address(this)), initialWavaxBalance, "test_SwapExactOutTtoTSingleHopV1::1");
        assertEq(usdc.balanceOf(address(this)), initialUsdcBalance, "test_SwapExactOutTtoTSingleHopV1::2");

        uint256 amountOut = 100e6;
        uint256 expectedAmountIn = (v1WavaxBalance * amountOut * 1000 - 1) / ((v1UsdcBalance - amountOut) * 997) + 1;

        (uint256 amountIn,) =
            router.swapExactOut(route, address(this), amountOut, type(uint256).max, block.timestamp, address(0));

        assertEq(expectedAmountIn, amountIn, "test_SwapExactOutTtoTSingleHopV1::3");

        assertEq(wavax.balanceOf(address(this)), initialWavaxBalance - amountIn, "test_SwapExactOutTtoTSingleHopV1::4");
        assertEq(usdc.balanceOf(address(this)), initialUsdcBalance + amountOut, "test_SwapExactOutTtoTSingleHopV1::5");
        assertEq(usdc.balanceOf(v1wu), v1UsdcBalance - amountOut, "test_SwapExactOutTtoTSingleHopV1::6");
        assertEq(wavax.balanceOf(v1wu), v1WavaxBalance + amountIn, "test_SwapExactOutTtoTSingleHopV1::7");
    }

    function test_SwapExactOutTtoTSingleHopV2_0() public {
        bytes memory route = abi.encodePacked(wavax, v2_0wu_id, usdc);

        uint256 v2_0UsdcBalance = usdc.balanceOf(v2_0wu);
        uint256 v2_0WavaxBalance = wavax.balanceOf(v2_0wu);

        assertEq(wavax.balanceOf(address(this)), initialWavaxBalance, "test_SwapExactOutTtoTSingleHopV2_0::1");
        assertEq(usdc.balanceOf(address(this)), initialUsdcBalance, "test_SwapExactOutTtoTSingleHopV2_0::2");

        uint256 amountOut = 100e6;
        (uint256 expectedAmountIn,) = IV2_0Router(v2_0Router).getSwapIn(v2_0wu, amountOut, true);

        (uint256 amountIn,) =
            router.swapExactOut(route, address(this), amountOut, type(uint256).max, block.timestamp, address(0));

        assertEq(expectedAmountIn, amountIn, "test_SwapExactOutTtoTSingleHopV2_0::3");

        assertEq(
            wavax.balanceOf(address(this)), initialWavaxBalance - amountIn, "test_SwapExactOutTtoTSingleHopV2_0::4"
        );
        assertEq(usdc.balanceOf(address(this)), initialUsdcBalance + amountOut, "test_SwapExactOutTtoTSingleHopV2_0::5");
        assertEq(usdc.balanceOf(v2_0wu), v2_0UsdcBalance - amountOut, "test_SwapExactOutTtoTSingleHopV2_0::6");
        assertEq(wavax.balanceOf(v2_0wu), v2_0WavaxBalance + amountIn, "test_SwapExactOutTtoTSingleHopV2_0::7");
    }

    function test_SwapExactOutTtoTSingleHopV2_1() public {
        bytes memory route = abi.encodePacked(wavax, v2_1wu_id, usdc);

        uint256 v2_1UsdcBalance = usdc.balanceOf(v2_1wu);
        uint256 v2_1WavaxBalance = wavax.balanceOf(v2_1wu);

        assertEq(wavax.balanceOf(address(this)), initialWavaxBalance, "test_SwapExactOutTtoTSingleHopV2_1::1");
        assertEq(usdc.balanceOf(address(this)), initialUsdcBalance, "test_SwapExactOutTtoTSingleHopV2_1::2");

        uint128 amountOut = 100e6;
        (uint256 expectedAmountIn,,) = IV2_1Pair(v2_1wu).getSwapIn(amountOut, true);

        (uint256 amountIn,) =
            router.swapExactOut(route, address(this), amountOut, type(uint256).max, block.timestamp, address(0));

        assertEq(expectedAmountIn, amountIn, "test_SwapExactOutTtoTSingleHopV2_1::3");

        assertEq(
            wavax.balanceOf(address(this)), initialWavaxBalance - amountIn, "test_SwapExactOutTtoTSingleHopV2_1::4"
        );
        assertEq(usdc.balanceOf(address(this)), initialUsdcBalance + amountOut, "test_SwapExactOutTtoTSingleHopV2_1::5");
        assertEq(usdc.balanceOf(v2_1wu), v2_1UsdcBalance - amountOut, "test_SwapExactOutTtoTSingleHopV2_1::6");
        assertEq(wavax.balanceOf(v2_1wu), v2_1WavaxBalance + amountIn, "test_SwapExactOutTtoTSingleHopV2_1::7");
    }

    function test_SwapExactOutTtoTtoTSingleHopV1() public {
        bytes memory route = abi.encodePacked(wavax, v1wu_id, usdc);

        uint256 v1UsdcBalance = usdc.balanceOf(v1wu);
        uint256 v1WavaxBalance = wavax.balanceOf(v1wu);

        uint256 amountOut = 100e6;
        uint256 expectedAmountIn = (v1WavaxBalance * amountOut * 1000 - 1) / ((v1UsdcBalance - amountOut) * 997) + 1;

        (uint256 amountIn,) =
            router.swapExactOut(route, address(this), amountOut, type(uint256).max, block.timestamp, address(0));

        assertEq(amountIn, expectedAmountIn, "test_SwapExactOutTtoTtoTSingleHopV1::1");
        assertEq(
            wavax.balanceOf(address(this)), initialWavaxBalance - amountIn, "test_SwapExactOutTtoTtoTSingleHopV1::2"
        );
        assertEq(
            usdc.balanceOf(address(this)), initialUsdcBalance + amountOut, "test_SwapExactOutTtoTtoTSingleHopV1::3"
        );

        v1UsdcBalance = usdc.balanceOf(v1wu);
        v1WavaxBalance = wavax.balanceOf(v1wu);

        uint256 expectedAmountIn2 = (v1UsdcBalance * amountIn * 1000 - 1) / ((v1WavaxBalance - amountIn) * 997) + 1;
        uint256 expectedAmountOut2 =
            (v1WavaxBalance * expectedAmountIn2 * 997) / (v1UsdcBalance * 1000 + expectedAmountIn2 * 997);

        assertGe(expectedAmountOut2, amountIn, "test_SwapExactOutTtoTtoTSingleHopV1::4");

        route = abi.encodePacked(usdc, v1wu_id, wavax);

        (uint256 amountIn2, uint256 amountOut2) = router.swapExactOut(
            route, address(this), expectedAmountOut2, type(uint256).max, block.timestamp, address(0)
        );

        assertEq(amountIn2, expectedAmountIn2, "test_SwapExactOutTtoTtoTSingleHopV1::5");
        assertEq(amountOut2, expectedAmountOut2, "test_SwapExactOutTtoTtoTSingleHopV1::6");
        assertEq(
            wavax.balanceOf(address(this)),
            initialWavaxBalance - amountIn + amountOut2,
            "test_SwapExactOutTtoTtoTSingleHopV1::7"
        );
        assertEq(
            usdc.balanceOf(address(this)),
            initialUsdcBalance + amountOut - amountIn2,
            "test_SwapExactOutTtoTtoTSingleHopV1::8"
        );
    }

    function test_SwapExactOutTtoTtoTSingleHopV2_0() public {
        bytes memory route = abi.encodePacked(wavax, v2_0wu_id, usdc);

        uint256 v2_0UsdcBalance = usdc.balanceOf(v2_0wu);
        uint256 v2_0WavaxBalance = wavax.balanceOf(v2_0wu);

        uint256 amountOut = 100e6;
        (uint256 expectedAmountIn,) = IV2_0Router(v2_0Router).getSwapIn(v2_0wu, amountOut, true);

        (uint256 amountIn,) =
            router.swapExactOut(route, address(this), amountOut, type(uint256).max, block.timestamp, address(0));

        assertEq(expectedAmountIn, amountIn, "test_SwapExactOutTtoTtoTSingleHopV2_0::1");
        assertEq(
            wavax.balanceOf(address(this)), initialWavaxBalance - amountIn, "test_SwapExactOutTtoTtoTSingleHopV2_0::2"
        );
        assertEq(
            usdc.balanceOf(address(this)), initialUsdcBalance + amountOut, "test_SwapExactOutTtoTtoTSingleHopV2_0::3"
        );

        v2_0UsdcBalance = usdc.balanceOf(v2_0wu);
        v2_0WavaxBalance = wavax.balanceOf(v2_0wu);

        uint256 expectedAmountOut2 = amountIn / 2;
        (uint256 expectedAmountIn2,) = IV2_0Router(v2_0Router).getSwapIn(v2_0wu, expectedAmountOut2, false);

        route = abi.encodePacked(usdc, v2_0wu_id, wavax);

        (uint256 amountIn2, uint256 amountOut2) = router.swapExactOut(
            route, address(this), expectedAmountOut2, type(uint256).max, block.timestamp, address(0)
        );

        assertEq(expectedAmountIn2, amountIn2, "test_SwapExactOutTtoTtoTSingleHopV2_0::4");
        assertGe(amountOut2, expectedAmountOut2, "test_SwapExactOutTtoTtoTSingleHopV2_0::5");
        assertEq(
            wavax.balanceOf(address(this)),
            initialWavaxBalance - amountIn + amountOut2,
            "test_SwapExactOutTtoTtoTSingleHopV2_0::6"
        );
        assertEq(
            usdc.balanceOf(address(this)),
            initialUsdcBalance + amountOut - amountIn2,
            "test_SwapExactOutTtoTtoTSingleHopV2_0::7"
        );
    }

    function test_SwapExactOutTtoTtoTSingleHopV2_1() public {
        bytes memory route = abi.encodePacked(wavax, v2_1wu_id, usdc);

        uint256 v2_1UsdcBalance = usdc.balanceOf(v2_1wu);
        uint256 v2_1WavaxBalance = wavax.balanceOf(v2_1wu);

        uint128 amountOut = 100e6;
        (uint256 expectedAmountIn,,) = IV2_1Pair(v2_1wu).getSwapIn(amountOut, true);

        (uint256 amountIn,) =
            router.swapExactOut(route, address(this), amountOut, type(uint256).max, block.timestamp, address(0));

        assertEq(expectedAmountIn, amountIn, "test_SwapExactOutTtoTtoTSingleHopV2_1::1");
        assertEq(
            wavax.balanceOf(address(this)), initialWavaxBalance - amountIn, "test_SwapExactOutTtoTtoTSingleHopV2_1::2"
        );
        assertEq(
            usdc.balanceOf(address(this)), initialUsdcBalance + amountOut, "test_SwapExactOutTtoTtoTSingleHopV2_1::3"
        );

        v2_1UsdcBalance = usdc.balanceOf(v2_1wu);
        v2_1WavaxBalance = wavax.balanceOf(v2_1wu);

        uint128 expectedAmountOut2 = uint128(amountIn);
        (uint256 expectedAmountIn2,,) = IV2_1Pair(v2_1wu).getSwapIn(expectedAmountOut2, false);

        route = abi.encodePacked(usdc, v2_1wu_id, wavax);

        (uint256 amountIn2, uint256 amountOut2) = router.swapExactOut(
            route, address(this), expectedAmountOut2, type(uint256).max, block.timestamp, address(0)
        );

        assertEq(expectedAmountIn2, amountIn2, "test_SwapExactOutTtoTtoTSingleHopV2_1::4");
        assertGe(amountOut2, expectedAmountOut2, "test_SwapExactOutTtoTtoTSingleHopV2_1::5");
        assertEq(
            wavax.balanceOf(address(this)),
            initialWavaxBalance - amountIn + amountOut2,
            "test_SwapExactOutTtoTtoTSingleHopV2_1::6"
        );
        assertEq(
            usdc.balanceOf(address(this)),
            initialUsdcBalance + amountOut - amountIn2,
            "test_SwapExactOutTtoTtoTSingleHopV2_1::7"
        );
    }

    function test_SwapExactOutTtoTtoTMultiHop() public {
        bytes memory route =
            abi.encodePacked(wavax, v1wu_id, usdc, v2_1wu_id, wavax, v2_0wu_id, usdc, uint32(3 << 24), token1);

        uint256 v1UsdcBalance = usdc.balanceOf(v1wu);
        uint256 v1WavaxBalance = wavax.balanceOf(v1wu);

        uint256 expectedAmountOut = 100e18;
        (, int256 deltaQuote,) = ITMMarket(market1u).getDeltaAmounts(-int256(expectedAmountOut), false);
        (uint256 expectedAmountIn,) = IV2_0Router(v2_0Router).getSwapIn(v2_0wu, uint256(deltaQuote), true);
        (expectedAmountIn,,) = IV2_1Pair(v2_1wu).getSwapIn(uint128(expectedAmountIn), false);
        expectedAmountIn =
            (v1WavaxBalance * expectedAmountIn * 1000 - 1) / ((v1UsdcBalance - expectedAmountIn) * 997) + 1;

        (uint256 amountIn, uint256 amountOut) =
            router.swapExactOut(route, address(this), expectedAmountOut, type(uint256).max, block.timestamp, address(0));

        assertEq(amountIn, expectedAmountIn, "test_SwapExactOutTtoTtoTMultiHop::1");
        assertEq(amountOut, expectedAmountOut, "test_SwapExactOutTtoTtoTMultiHop::2");
        assertEq(wavax.balanceOf(address(this)), initialWavaxBalance - amountIn, "test_SwapExactOutTtoTtoTMultiHop::3");
        assertEq(IERC20(token1).balanceOf(address(this)), amountOut, "test_SwapExactOutTtoTtoTMultiHop::4");

        IERC20(token1).approve(address(router), amountOut);

        route = abi.encodePacked(token1, uint32(3 << 24), usdc, v2_0wu_id, wavax, v2_1wu_id, usdc, v1wu_id, wavax);

        v1UsdcBalance = usdc.balanceOf(v1wu);
        v1WavaxBalance = wavax.balanceOf(v1wu);

        uint256 expectedAmountOut2 = amountIn / 2;
        uint256 expectedAmountIn2 =
            (v1UsdcBalance * expectedAmountOut2 * 1000 - 1) / ((v1WavaxBalance - expectedAmountOut2) * 997) + 1;
        (expectedAmountIn2,,) = IV2_1Pair(v2_1wu).getSwapIn(uint128(expectedAmountIn2), true);
        (expectedAmountIn2,) = IV2_0Router(v2_0Router).getSwapIn(v2_0wu, expectedAmountIn2, false);
        (int256 deltaBase,,) = ITMMarket(market1u).getDeltaAmounts(-int256(expectedAmountIn2), true);
        expectedAmountIn2 = uint256(deltaBase);

        (uint256 amountIn2, uint256 amountOut2) = router.swapExactOut(
            route, address(this), expectedAmountOut2, type(uint256).max, block.timestamp, address(0)
        );

        assertGe(expectedAmountIn2, amountIn2, "test_SwapExactOutTtoTtoTMultiHop::5");
        assertGe(amountOut2, expectedAmountOut2, "test_SwapExactOutTtoTtoTMultiHop::6");
        assertEq(
            wavax.balanceOf(address(this)),
            initialWavaxBalance - amountIn + amountOut2,
            "test_SwapExactOutTtoTtoTMultiHop::7"
        );
        assertEq(IERC20(token1).balanceOf(address(this)), amountOut - amountIn2, "test_SwapExactOutTtoTtoTMultiHop::8");
    }

    function test_Fuzz_GetFactory(uint256 sv) public {
        address v2_2Factory = makeAddr("v2_2Factory");

        router = new Router(v1Factory, v2_0Router, v2_1Factory, v2_2Factory, address(factory), address(wavax));

        assertEq(router.getFactory(1, 0), address(v1Factory), "test_Fuzz_GetFactory::1");
        assertEq(router.getFactory(2, 0), address(v2_0Factory), "test_Fuzz_GetFactory::2");
        assertEq(router.getFactory(2, 1), address(v2_1Factory), "test_Fuzz_GetFactory::3");
        assertEq(router.getFactory(2, 2), v2_2Factory, "test_Fuzz_GetFactory::4");
        assertEq(router.getFactory(3, 0), address(factory), "test_Fuzz_GetFactory::5");

        assertEq(router.getFactory(0, sv), address(0), "test_Fuzz_GetFactory::6");
        assertEq(router.getFactory(1, bound(sv, 1, type(uint256).max)), address(0), "test_Fuzz_GetFactory::7");
        assertEq(router.getFactory(2, bound(sv, 3, type(uint256).max)), address(0), "test_Fuzz_GetFactory::8");
        assertEq(router.getFactory(3, bound(sv, 1, 2)), address(0), "test_Fuzz_GetFactory::9");
        assertEq(router.getFactory(bound(sv, 4, type(uint256).max), sv), address(0), "test_Fuzz_GetFactory::10");
    }

    function test_GetWNative() public view {
        assertEq(router.getWNative(), address(wavax), "test_GetWNative::1");
    }

    function test_SimulateSwapExactIn() public {
        bytes memory route0 = abi.encodePacked(wavax, v2_0wu_id, usdc);
        bytes memory route1 = abi.encodePacked(wavax, v2_1wu_id, usdc);

        bytes[] memory routes = new bytes[](2);

        routes[0] = route0;
        routes[1] = route1;

        uint256 amountIn = 10e18;

        (, bytes memory d) =
            address(router).call(abi.encodeWithSelector(IRouter.simulate.selector, routes, amountIn, true));

        assertEq(bytes4(d), IRouter.Router__Simulations.selector, "test_SimulateSwapExactIn::1");

        uint256 amount0;
        uint256 amount1;
        assembly ("memory-safe") {
            amount0 := mload(add(d, 0x64))
            amount1 := mload(add(d, 0x84))
        }

        vm.expectRevert(abi.encodeWithSelector(IRouter.Router__Simulation.selector, amount0));
        router.simulateSingle(routes[0], amountIn, true);

        vm.expectRevert(abi.encodeWithSelector(IRouter.Router__Simulation.selector, amount1));
        router.simulateSingle(routes[1], amountIn, true);

        uint256 balance = usdc.balanceOf(address(this));
        (uint256 amountIn0, uint256 amountOut0) =
            router.swapExactIn(routes[0], address(this), amountIn, 0, block.timestamp, address(0));

        assertEq(amountIn0, amountIn, "test_SimulateSwapExactIn::2");
        assertEq(amountOut0, amount0, "test_SimulateSwapExactIn::3");
        assertEq(usdc.balanceOf(address(this)), balance + amountOut0, "test_SimulateSwapExactIn::4");

        (uint256 amountIn1, uint256 amountOut1) =
            router.swapExactIn(routes[1], address(this), amountIn, 0, block.timestamp, address(0));

        assertEq(amountIn1, amountIn, "test_SimulateSwapExactIn::5");
        assertEq(amountOut1, amount1, "test_SimulateSwapExactIn::6");
        assertEq(usdc.balanceOf(address(this)), balance + amountOut0 + amountOut1, "test_SimulateSwapExactIn::7");
    }

    function test_SimulateSwapExactOut() public {
        bytes memory route0 = abi.encodePacked(wavax, v2_0wu_id, usdc);
        bytes memory route1 = abi.encodePacked(wavax, v2_1wu_id, usdc);

        bytes[] memory routes = new bytes[](2);

        routes[0] = route0;
        routes[1] = route1;

        uint256 amountOut = 100e6;

        (, bytes memory d) =
            address(router).call(abi.encodeWithSelector(IRouter.simulate.selector, routes, amountOut, false));

        assertEq(bytes4(d), IRouter.Router__Simulations.selector, "test_SimulateSwapExactOut::1");

        uint256 amount0;
        uint256 amount1;
        assembly ("memory-safe") {
            amount0 := mload(add(d, 0x64))
            amount1 := mload(add(d, 0x84))
        }

        vm.expectRevert(abi.encodeWithSelector(IRouter.Router__Simulation.selector, amount0));
        router.simulateSingle(routes[0], amountOut, false);

        vm.expectRevert(abi.encodeWithSelector(IRouter.Router__Simulation.selector, amount1));
        router.simulateSingle(routes[1], amountOut, false);

        uint256 balance = wavax.balanceOf(address(this));
        (uint256 amountIn0, uint256 amountOut0) =
            router.swapExactOut(routes[0], address(this), amountOut, type(uint256).max, block.timestamp, address(0));

        assertEq(amountIn0, amount0, "test_SimulateSwapExactOut::2");
        assertEq(amountOut0, amountOut, "test_SimulateSwapExactOut::3");
        assertEq(wavax.balanceOf(address(this)), balance - amountIn0, "test_SimulateSwapExactOut::4");

        (uint256 amountIn1, uint256 amountOut1) =
            router.swapExactOut(routes[1], address(this), amountOut, type(uint256).max, block.timestamp, address(0));

        assertEq(amountIn1, amount1, "test_SimulateSwapExactOut::5");
        assertEq(amountOut1, amountOut, "test_SimulateSwapExactOut::6");
        assertEq(wavax.balanceOf(address(this)), balance - amountIn0 - amountIn1, "test_SimulateSwapExactOut::7");
    }

    function test_SimulateSwapExactInNative() public {
        bytes memory route0 = abi.encodePacked(address(0), v2_0wu_id, usdc);
        bytes memory route1 = abi.encodePacked(address(0), v2_1wu_id, usdc);

        bytes[] memory routes = new bytes[](2);

        routes[0] = route0;
        routes[1] = route1;

        uint256 amountIn = 10e18;

        (, bytes memory d) = address(router).call{value: amountIn}(
            abi.encodeWithSelector(IRouter.simulate.selector, routes, amountIn, true)
        );

        assertEq(bytes4(d), IRouter.Router__Simulations.selector, "test_SimulateSwapExactInNative::1");

        uint256 amount0;
        uint256 amount1;
        assembly ("memory-safe") {
            amount0 := mload(add(d, 0x64))
            amount1 := mload(add(d, 0x84))
        }

        vm.expectRevert(abi.encodeWithSelector(IRouter.Router__Simulation.selector, amount0));
        router.simulateSingle{value: amountIn}(routes[0], amountIn, true);

        vm.expectRevert(abi.encodeWithSelector(IRouter.Router__Simulation.selector, amount1));
        router.simulateSingle{value: amountIn}(routes[1], amountIn, true);

        uint256 balance = usdc.balanceOf(address(this));
        (uint256 amountIn0, uint256 amountOut0) =
            router.swapExactIn{value: amountIn}(routes[0], address(this), amountIn, 0, block.timestamp, address(0));

        assertEq(amountIn0, amountIn, "test_SimulateSwapExactInNative::2");
        assertEq(amountOut0, amount0, "test_SimulateSwapExactInNative::3");
        assertEq(usdc.balanceOf(address(this)), balance + amountOut0, "test_SimulateSwapExactInNative::4");

        (uint256 amountIn1, uint256 amountOut1) =
            router.swapExactIn{value: amountIn}(routes[1], address(this), amountIn, 0, block.timestamp, address(0));

        assertEq(amountIn1, amountIn, "test_SimulateSwapExactInNative::5");
        assertEq(amountOut1, amount1, "test_SimulateSwapExactInNative::6");
        assertEq(usdc.balanceOf(address(this)), balance + amountOut0 + amountOut1, "test_SimulateSwapExactInNative::7");
    }

    function test_SimulateSwapExactOutNative() public {
        bytes memory route0 = abi.encodePacked(address(0), v2_0wu_id, usdc);
        bytes memory route1 = abi.encodePacked(address(0), v2_1wu_id, usdc);

        bytes[] memory routes = new bytes[](2);

        routes[0] = route0;
        routes[1] = route1;

        uint256 maxAmountIn = 10e18;
        uint256 amountOut = 100e6;

        (, bytes memory d) = address(router).call{value: maxAmountIn}(
            abi.encodeWithSelector(IRouter.simulate.selector, routes, amountOut, false)
        );

        assertEq(bytes4(d), IRouter.Router__Simulations.selector, "test_SimulateSwapExactOutNative::1");

        uint256 amount0;
        uint256 amount1;
        assembly ("memory-safe") {
            amount0 := mload(add(d, 0x64))
            amount1 := mload(add(d, 0x84))
        }

        vm.expectRevert(abi.encodeWithSelector(IRouter.Router__Simulation.selector, amount0));
        router.simulateSingle{value: maxAmountIn}(routes[0], amountOut, false);

        vm.expectRevert(abi.encodeWithSelector(IRouter.Router__Simulation.selector, amount1));
        router.simulateSingle{value: maxAmountIn}(routes[1], amountOut, false);

        uint256 balance = address(this).balance;
        (uint256 amountIn0, uint256 amountOut0) = router.swapExactOut{value: maxAmountIn}(
            routes[0], address(this), amountOut, type(uint256).max, block.timestamp, address(0)
        );

        assertEq(amountIn0, amount0, "test_SimulateSwapExactOutNative::2");
        assertEq(amountOut0, amountOut, "test_SimulateSwapExactOutNative::3");
        assertEq(address(this).balance, balance - amountIn0, "test_SimulateSwapExactOutNative::4");

        (uint256 amountIn1, uint256 amountOut1) = router.swapExactOut{value: maxAmountIn}(
            routes[1], address(this), amountOut, type(uint256).max, block.timestamp, address(0)
        );

        assertEq(amountIn1, amount1, "test_SimulateSwapExactOutNative::5");
        assertEq(amountOut1, amountOut, "test_SimulateSwapExactOutNative::6");
        assertEq(address(this).balance, balance - amountIn0 - amountIn1, "test_SimulateSwapExactOutNative::7");
    }
}
