// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./TestHelper.sol";

import "./mocks/TransferTaxToken.sol";

import "../src/CliffVestingContract.sol";

contract TestRouter is TestHelper {
    function setUp() public override {
        super.setUp();
        setUpTokens();
    }

    receive() external payable {}

    function test_SwapExactInTtoTSingleHop() public {
        wnative.deposit{value: 1e18}();
        wnative.approve(address(router), 1e18);

        bytes memory route = abi.encodePacked(wnative, uint32(3 << 24), token0);

        assertEq(wnative.balanceOf(address(this)), 1e18, "test_SwapExactInTtoTSingleHop::1");
        assertEq(wnative.balanceOf(market0w), 0, "test_SwapExactInTtoTSingleHop::2");
        assertEq(IERC20(token0).balanceOf(address(this)), 0, "test_SwapExactInTtoTSingleHop::3");
        assertEq(IERC20(token0).balanceOf(market0w), 500_000_000e18, "test_SwapExactInTtoTSingleHop::4");

        (, uint256 amountOut) = router.swapExactIn(route, address(this), 1e18, 1e18, block.timestamp);

        assertEq(wnative.balanceOf(address(this)), 0, "test_SwapExactInTtoTSingleHop::5");
        assertEq(wnative.balanceOf(market0w), 1e18, "test_SwapExactInTtoTSingleHop::6");
        assertEq(IERC20(token0).balanceOf(address(this)), amountOut, "test_SwapExactInTtoTSingleHop::7");
        assertEq(IERC20(token0).balanceOf(market0w), 500_000_000e18 - amountOut, "test_SwapExactInTtoTSingleHop::8");
    }

    function test_SwapExactInNtoTSingleHop() public {
        bytes memory route = abi.encodePacked(address(0), uint32(3 << 24), token0);

        uint256 balance = address(this).balance;
        assertEq(wnative.balanceOf(market0w), 0, "test_SwapExactInNtoTSingleHop::1");
        assertEq(IERC20(token0).balanceOf(address(this)), 0, "test_SwapExactInNtoTSingleHop::2");
        assertEq(IERC20(token0).balanceOf(market0w), 500_000_000e18, "test_SwapExactInNtoTSingleHop::3");

        (, uint256 amountOut) = router.swapExactIn{value: 1e18}(route, address(this), 1e18, 1e18, block.timestamp);

        assertEq(address(this).balance, balance - 1e18, "test_SwapExactInNtoTSingleHop::4");
        assertEq(wnative.balanceOf(market0w), 1e18, "test_SwapExactInNtoTSingleHop::5");
        assertEq(IERC20(token0).balanceOf(address(this)), amountOut, "test_SwapExactInNtoTSingleHop::6");
        assertEq(IERC20(token0).balanceOf(market0w), 500_000_000e18 - amountOut, "test_SwapExactInNtoTSingleHop::7");
    }

    function test_SwapExactInTtoTtoTSingleHop() public {
        wnative.deposit{value: 1e18}();
        wnative.approve(address(router), 1e18);

        bytes memory route = abi.encodePacked(wnative, uint32(3 << 24), token0);
        (, uint256 amountOutToken0) = router.swapExactIn(route, address(this), 1e18, 1e18, block.timestamp);

        IERC20(token0).approve(address(router), amountOutToken0);

        route = abi.encodePacked(token0, uint32(3 << 24), wnative);
        (, uint256 amountOutW) = router.swapExactIn(route, address(this), amountOutToken0, 0.1e18, block.timestamp);

        assertEq(wnative.balanceOf(address(this)), amountOutW, "test_SwapExactInTtoTtoTSingleHop::1");
        assertEq(wnative.balanceOf(market0w), 1e18 - amountOutW, "test_SwapExactInTtoTtoTSingleHop::2");
        assertEq(IERC20(token0).balanceOf(address(this)), 0, "test_SwapExactInTtoTtoTSingleHop::3");
        assertEq(IERC20(token0).balanceOf(market0w), 500_000_000e18, "test_SwapExactInTtoTtoTSingleHop::4");
    }

    function test_SwapExactInNtoTtoNSingleHop() public {
        bytes memory route = abi.encodePacked(address(0), uint32(3 << 24), token0);
        (, uint256 amountOutToken0) = router.swapExactIn{value: 1e18}(route, address(this), 1e18, 1e18, block.timestamp);

        uint256 balance = address(this).balance;
        IERC20(token0).approve(address(router), amountOutToken0);

        route = abi.encodePacked(token0, uint32(3 << 24), address(0));
        (, uint256 amountOutN) = router.swapExactIn(route, address(this), amountOutToken0, 0.1e18, block.timestamp);

        assertEq(address(this).balance, balance + amountOutN, "test_SwapExactInNtoTtoNSingleHop::1");
        assertEq(wnative.balanceOf(market0w), 1e18 - amountOutN, "test_SwapExactInNtoTtoNSingleHop::2");
        assertEq(IERC20(token0).balanceOf(address(this)), 0, "test_SwapExactInNtoTtoNSingleHop::3");
        assertEq(IERC20(token0).balanceOf(market0w), 500_000_000e18, "test_SwapExactInNtoTtoNSingleHop::4");
    }

    function test_SwapExactInTtoTMultiHop() public {
        wnative.deposit{value: 1e18}();
        wnative.approve(address(router), 1e18);

        bytes memory route =
            abi.encodePacked(wnative, uint32(3 << 24), token0, uint32(3 << 24), token1, uint32(3 << 24), token2);

        assertEq(wnative.balanceOf(address(this)), 1e18, "test_SwapExactInTtoTMultiHop::1");
        assertEq(wnative.balanceOf(market0w), 0, "test_SwapExactInTtoTMultiHop::2");
        assertEq(IERC20(token0).balanceOf(address(this)), 0, "test_SwapExactInTtoTMultiHop::3");
        assertEq(IERC20(token0).balanceOf(market0w), 500_000_000e18, "test_SwapExactInTtoTMultiHop::4");
        assertEq(IERC20(token1).balanceOf(address(this)), 0, "test_SwapExactInTtoTMultiHop::5");
        assertEq(IERC20(token1).balanceOf(market10), 100_000_000e18, "test_SwapExactInTtoTMultiHop::6");
        assertEq(IERC20(token2).balanceOf(address(this)), 0, "test_SwapExactInTtoTMultiHop::7");
        assertEq(IERC20(token2).balanceOf(market21), 50_000_000e18, "test_SwapExactInTtoTMultiHop::8");

        (, uint256 amountOut) = router.swapExactIn(route, address(this), 1e18, 1e18, block.timestamp);

        assertEq(wnative.balanceOf(address(this)), 0, "test_SwapExactInTtoTMultiHop::9");
        assertEq(wnative.balanceOf(market0w), 1e18, "test_SwapExactInTtoTMultiHop::10");
        assertEq(IERC20(token0).balanceOf(address(this)), 0, "test_SwapExactInTtoTMultiHop::11");

        uint256 balance = IERC20(token0).balanceOf(market0w);
        assertLt(IERC20(token0).balanceOf(market0w), 500_000_000e18, "test_SwapExactInTtoTMultiHop::12");
        assertEq(IERC20(token0).balanceOf(market10), 500_000_000e18 - balance, "test_SwapExactInTtoTMultiHop::13");

        balance = IERC20(token1).balanceOf(market10);
        assertEq(IERC20(token1).balanceOf(address(this)), 0, "test_SwapExactInTtoTMultiHop::14");
        assertLt(IERC20(token1).balanceOf(market10), 100_000_000e18, "test_SwapExactInTtoTMultiHop::15");
        assertEq(IERC20(token1).balanceOf(market21), 100_000_000e18 - balance, "test_SwapExactInTtoTMultiHop::16");

        assertEq(IERC20(token2).balanceOf(address(this)), amountOut, "test_SwapExactInTtoTMultiHop::17");
        assertEq(IERC20(token2).balanceOf(market21), 50_000_000e18 - amountOut, "test_SwapExactInTtoTMultiHop::18");
    }

    function test_SwapExactInNtoTMultiHop() public {
        bytes memory route =
            abi.encodePacked(address(0), uint32(3 << 24), token0, uint32(3 << 24), token1, uint32(3 << 24), token2);

        uint256 balance = address(this).balance;
        assertEq(wnative.balanceOf(market0w), 0, "test_SwapExactInNtoTMultiHop::1");
        assertEq(IERC20(token0).balanceOf(address(this)), 0, "test_SwapExactInNtoTMultiHop::2");
        assertEq(IERC20(token0).balanceOf(market0w), 500_000_000e18, "test_SwapExactInNtoTMultiHop::3");
        assertEq(IERC20(token1).balanceOf(address(this)), 0, "test_SwapExactInNtoTMultiHop::4");
        assertEq(IERC20(token1).balanceOf(market10), 100_000_000e18, "test_SwapExactInNtoTMultiHop::5");
        assertEq(IERC20(token2).balanceOf(address(this)), 0, "test_SwapExactInNtoTMultiHop::6");
        assertEq(IERC20(token2).balanceOf(market21), 50_000_000e18, "test_SwapExactInNtoTMultiHop::7");

        (, uint256 amountOut) = router.swapExactIn{value: 1e18}(route, address(this), 1e18, 1e18, block.timestamp);

        assertEq(address(this).balance, balance - 1e18, "test_SwapExactInNtoTMultiHop::8");
        assertEq(wnative.balanceOf(market0w), 1e18, "test_SwapExactInNtoTMultiHop::9");
        assertEq(IERC20(token0).balanceOf(address(this)), 0, "test_SwapExactInNtoTMultiHop::10");

        uint256 balanceToken0 = IERC20(token0).balanceOf(market0w);
        assertLt(IERC20(token0).balanceOf(market0w), 500_000_000e18, "test_SwapExactInNtoTMultiHop::11");
        assertEq(IERC20(token0).balanceOf(market10), 500_000_000e18 - balanceToken0, "test_SwapExactInNtoTMultiHop::12");

        balance = IERC20(token1).balanceOf(market10);
        assertEq(IERC20(token1).balanceOf(address(this)), 0, "test_SwapExactInNtoTMultiHop::13");
        assertLt(IERC20(token1).balanceOf(market10), 100_000_000e18, "test_SwapExactInNtoTMultiHop::14");
        assertEq(IERC20(token1).balanceOf(market21), 100_000_000e18 - balance, "test_SwapExactInNtoTMultiHop::15");

        assertEq(IERC20(token2).balanceOf(address(this)), amountOut, "test_SwapExactInNtoTMultiHop::16");
        assertEq(IERC20(token2).balanceOf(market21), 50_000_000e18 - amountOut, "test_SwapExactInNtoTMultiHop::17");
    }

    function test_SwapExactInTtoTtoTMultiHop() public {
        wnative.deposit{value: 1e18}();
        wnative.approve(address(router), 1e18);

        bytes memory route =
            abi.encodePacked(wnative, uint32(3 << 24), token0, uint32(3 << 24), token1, uint32(3 << 24), token2);
        (, uint256 amountOutToken2) = router.swapExactIn(route, address(this), 1e18, 1e18, block.timestamp);

        IERC20(token2).approve(address(router), amountOutToken2);

        route = abi.encodePacked(token2, uint32(3 << 24), token1, uint32(3 << 24), token0, uint32(3 << 24), wnative);
        (, uint256 amountOutW) = router.swapExactIn(route, address(this), amountOutToken2, 0.1e18, block.timestamp);

        assertEq(wnative.balanceOf(address(this)), amountOutW, "test_SwapExactInTtoTtoTMultiHop::1");
        assertEq(wnative.balanceOf(market0w), 1e18 - amountOutW, "test_SwapExactInTtoTtoTMultiHop::2");
        assertEq(IERC20(token2).balanceOf(address(this)), 0, "test_SwapExactInTtoTtoTMultiHop::3");
        assertEq(IERC20(token2).balanceOf(market21), 50_000_000e18, "test_SwapExactInTtoTtoTMultiHop::4");
    }

    function test_SwapExactInNtoTtoNMultiHop() public {
        bytes memory route =
            abi.encodePacked(address(0), uint32(3 << 24), token0, uint32(3 << 24), token1, uint32(3 << 24), token2);
        (, uint256 amountOutToken2) = router.swapExactIn{value: 1e18}(route, address(this), 1e18, 1e18, block.timestamp);

        uint256 balance = address(this).balance;
        IERC20(token2).approve(address(router), amountOutToken2);

        route = abi.encodePacked(token2, uint32(3 << 24), token1, uint32(3 << 24), token0, uint32(3 << 24), address(0));
        (, uint256 amountOutN) = router.swapExactIn(route, address(this), amountOutToken2, 0.1e18, block.timestamp);

        assertEq(address(this).balance, balance + amountOutN, "test_SwapExactInNtoTtoNMultiHop::1");
        assertEq(wnative.balanceOf(market0w), 1e18 - amountOutN, "test_SwapExactInNtoTtoNMultiHop::2");
        assertEq(IERC20(token2).balanceOf(address(this)), 0, "test_SwapExactInNtoTtoNMultiHop::3");
        assertEq(IERC20(token2).balanceOf(market21), 50_000_000e18, "test_SwapExactInNtoTtoNMultiHop::4");
    }

    function test_SwapExactOutTtoTSingleHop() public {
        wnative.deposit{value: 1e18}();
        wnative.approve(address(router), 1e18);

        (int256 deltaBaseAmount,) = ITMMarket(market0w).getDeltaBaseAmount(0, 0.9e18);

        bytes memory route = abi.encodePacked(wnative, uint32(3 << 24), token0);

        assertEq(wnative.balanceOf(address(this)), 1e18, "test_SwapExactOutTtoTSingleHop::1");
        assertEq(wnative.balanceOf(market0w), 0, "test_SwapExactOutTtoTSingleHop::2");
        assertEq(IERC20(token0).balanceOf(address(this)), 0, "test_SwapExactOutTtoTSingleHop::3");
        assertEq(IERC20(token0).balanceOf(market0w), 500_000_000e18, "test_SwapExactOutTtoTSingleHop::4");

        (uint256 amountIn,) =
            router.swapExactOut(route, address(this), uint256(-deltaBaseAmount), 1e18, block.timestamp);

        assertEq(wnative.balanceOf(address(this)), 1e18 - amountIn, "test_SwapExactOutTtoTSingleHop::5");
        assertEq(wnative.balanceOf(market0w), amountIn, "test_SwapExactOutTtoTSingleHop::6");
        assertEq(
            IERC20(token0).balanceOf(address(this)), uint256(-deltaBaseAmount), "test_SwapExactOutTtoTSingleHop::7"
        );
        assertEq(
            IERC20(token0).balanceOf(market0w),
            500_000_000e18 - uint256(-deltaBaseAmount),
            "test_SwapExactOutTtoTSingleHop::8"
        );
    }

    function test_SwapExactOutNtoTSingleHop() public {
        (int256 deltaBaseAmount,) = ITMMarket(market0w).getDeltaBaseAmount(0, 0.9e18);

        bytes memory route = abi.encodePacked(address(0), uint32(3 << 24), token0);

        uint256 balance = address(this).balance;
        assertEq(wnative.balanceOf(market0w), 0, "test_SwapExactOutNtoTSingleHop::1");
        assertEq(IERC20(token0).balanceOf(address(this)), 0, "test_SwapExactOutNtoTSingleHop::2");
        assertEq(IERC20(token0).balanceOf(market0w), 500_000_000e18, "test_SwapExactOutNtoTSingleHop::3");

        (uint256 amountIn,) =
            router.swapExactOut{value: 1e18}(route, address(this), uint256(-deltaBaseAmount), 1e18, block.timestamp);

        assertEq(address(this).balance, balance - amountIn, "test_SwapExactOutNtoTSingleHop::4");
        assertEq(wnative.balanceOf(market0w), amountIn, "test_SwapExactOutNtoTSingleHop::5");
        assertEq(
            IERC20(token0).balanceOf(address(this)), uint256(-deltaBaseAmount), "test_SwapExactOutNtoTSingleHop::6"
        );
        assertEq(
            IERC20(token0).balanceOf(market0w),
            500_000_000e18 - uint256(-deltaBaseAmount),
            "test_SwapExactOutNtoTSingleHop::7"
        );
    }

    function test_SwapExactOutTtoTtoTSingleHop() public {
        wnative.deposit{value: 1e18}();
        wnative.approve(address(router), 1e18);

        (int256 deltaBaseAmount,) = ITMMarket(market0w).getDeltaBaseAmount(0, 0.9e18);

        bytes memory route = abi.encodePacked(wnative, uint32(3 << 24), token0);
        router.swapExactOut(route, address(this), uint256(-deltaBaseAmount), 1e18, block.timestamp);

        IERC20(token0).approve(address(router), uint256(-deltaBaseAmount));

        (, int256 deltaQuoteAmount) =
            ITMMarket(market0w).getDeltaQuoteAmount(ITMMarket(market0w).getCirculatingSupply(), -deltaBaseAmount);

        route = abi.encodePacked(token0, uint32(3 << 24), wnative);
        router.swapExactOut(
            route, address(this), uint256(-deltaQuoteAmount), uint256(-deltaBaseAmount), block.timestamp
        );

        assertEq(
            wnative.balanceOf(address(this)),
            1e18 - 0.9e18 + uint256(-deltaQuoteAmount),
            "test_SwapExactOutTtoTtoTSingleHop::1"
        );
        assertEq(
            wnative.balanceOf(market0w), 0.9e18 - uint256(-deltaQuoteAmount), "test_SwapExactOutTtoTtoTSingleHop::2"
        );
        assertEq(IERC20(token0).balanceOf(address(this)), 0, "test_SwapExactOutTtoTtoTSingleHop::3");
        assertEq(IERC20(token0).balanceOf(market0w), 500_000_000e18, "test_SwapExactOutTtoTtoTSingleHop::4");
    }

    function test_SwapExactOutNtoTtoNSingleHop() public {
        (int256 deltaBaseAmount,) = ITMMarket(market0w).getDeltaBaseAmount(0, 0.9e18);

        uint256 balance = address(this).balance;

        bytes memory route = abi.encodePacked(address(0), uint32(3 << 24), token0);
        router.swapExactOut{value: 1e18}(route, address(this), uint256(-deltaBaseAmount), 1e18, block.timestamp);

        IERC20(token0).approve(address(router), uint256(-deltaBaseAmount));

        (, int256 deltaQuoteAmount) =
            ITMMarket(market0w).getDeltaQuoteAmount(ITMMarket(market0w).getCirculatingSupply(), -deltaBaseAmount);

        route = abi.encodePacked(token0, uint32(3 << 24), address(0));
        router.swapExactOut(
            route, address(this), uint256(-deltaQuoteAmount), uint256(-deltaBaseAmount), block.timestamp
        );

        assertEq(
            address(this).balance, balance - 0.9e18 + uint256(-deltaQuoteAmount), "test_SwapExactOutNtoTtoNSingleHop::1"
        );
        assertEq(
            wnative.balanceOf(market0w), 0.9e18 - uint256(-deltaQuoteAmount), "test_SwapExactOutNtoTtoNSingleHop::2"
        );
        assertEq(IERC20(token0).balanceOf(address(this)), 0, "test_SwapExactOutNtoTtoNSingleHop::3");
        assertEq(IERC20(token0).balanceOf(market0w), 500_000_000e18, "test_SwapExactOutNtoTtoNSingleHop::4");
    }

    function test_SwapExactOutTtoTMultiHop() public {
        wnative.deposit{value: 1e18}();
        wnative.approve(address(router), 1e18);

        (int256 deltaBaseAmount,) = ITMMarket(market0w).getDeltaAmounts(0.9e18, false);
        (deltaBaseAmount,) = ITMMarket(market10).getDeltaAmounts(-deltaBaseAmount, false);
        (deltaBaseAmount,) = ITMMarket(market21).getDeltaAmounts(-deltaBaseAmount, false);

        bytes memory route =
            abi.encodePacked(wnative, uint32(3 << 24), token0, uint32(3 << 24), token1, uint32(3 << 24), token2);

        assertEq(wnative.balanceOf(address(this)), 1e18, "test_SwapExactOutTtoTMultiHop::1");
        assertEq(wnative.balanceOf(market0w), 0, "test_SwapExactOutTtoTMultiHop::2");
        assertEq(IERC20(token0).balanceOf(address(this)), 0, "test_SwapExactOutTtoTMultiHop::3");
        assertEq(IERC20(token0).balanceOf(market0w), 500_000_000e18, "test_SwapExactOutTtoTMultiHop::4");
        assertEq(IERC20(token1).balanceOf(address(this)), 0, "test_SwapExactOutTtoTMultiHop::5");
        assertEq(IERC20(token1).balanceOf(market10), 100_000_000e18, "test_SwapExactOutTtoTMultiHop::6");
        assertEq(IERC20(token2).balanceOf(address(this)), 0, "test_SwapExactOutTtoTMultiHop::7");
        assertEq(IERC20(token2).balanceOf(market21), 50_000_000e18, "test_SwapExactOutTtoTMultiHop::8");

        (uint256 amountIn, uint256 amountOut) =
            router.swapExactOut(route, address(this), uint256(-deltaBaseAmount), 1e18, block.timestamp);

        assertEq(wnative.balanceOf(address(this)), 1e18 - amountIn, "test_SwapExactOutTtoTMultiHop::9");
        assertEq(wnative.balanceOf(market0w), amountIn, "test_SwapExactOutTtoTMultiHop::10");
        assertEq(IERC20(token0).balanceOf(address(this)), 0, "test_SwapExactOutTtoTMultiHop::11");

        uint256 balance = IERC20(token0).balanceOf(market0w);
        assertLt(IERC20(token0).balanceOf(market0w), 500_000_000e18, "test_SwapExactOutTtoTMultiHop::12");
        assertEq(IERC20(token0).balanceOf(market10), 500_000_000e18 - balance, "test_SwapExactOutTtoTMultiHop::13");

        balance = IERC20(token1).balanceOf(market10);
        assertEq(IERC20(token1).balanceOf(address(this)), 0, "test_SwapExactOutTtoTMultiHop::14");
        assertLt(IERC20(token1).balanceOf(market10), 100_000_000e18, "test_SwapExactOutTtoTMultiHop::15");
        assertEq(IERC20(token1).balanceOf(market21), 100_000_000e18 - balance, "test_SwapExactOutTtoTMultiHop::16");

        assertEq(IERC20(token2).balanceOf(address(this)), amountOut, "test_SwapExactOutTtoTMultiHop::17");
        assertEq(IERC20(token2).balanceOf(market21), 50_000_000e18 - amountOut, "test_SwapExactOutTtoTMultiHop::18");
    }

    function test_SwapExactOutNtoTMultiHop() public {
        (int256 deltaBaseAmount,) = ITMMarket(market0w).getDeltaAmounts(0.9e18, false);
        (deltaBaseAmount,) = ITMMarket(market10).getDeltaAmounts(-deltaBaseAmount, false);
        (deltaBaseAmount,) = ITMMarket(market21).getDeltaAmounts(-deltaBaseAmount, false);

        bytes memory route =
            abi.encodePacked(address(0), uint32(3 << 24), token0, uint32(3 << 24), token1, uint32(3 << 24), token2);

        uint256 balance = address(this).balance;
        assertEq(wnative.balanceOf(market0w), 0, "test_SwapExactOutNtoTMultiHop::1");
        assertEq(IERC20(token0).balanceOf(address(this)), 0, "test_SwapExactOutNtoTMultiHop::2");
        assertEq(IERC20(token0).balanceOf(market0w), 500_000_000e18, "test_SwapExactOutNtoTMultiHop::3");
        assertEq(IERC20(token1).balanceOf(address(this)), 0, "test_SwapExactOutNtoTMultiHop::4");
        assertEq(IERC20(token1).balanceOf(market10), 100_000_000e18, "test_SwapExactOutNtoTMultiHop::5");
        assertEq(IERC20(token2).balanceOf(address(this)), 0, "test_SwapExactOutNtoTMultiHop::6");
        assertEq(IERC20(token2).balanceOf(market21), 50_000_000e18, "test_SwapExactOutNtoTMultiHop::7");

        (uint256 amountIn, uint256 amountOut) =
            router.swapExactOut{value: 1e18}(route, address(this), uint256(-deltaBaseAmount), 1e18, block.timestamp);

        assertEq(address(this).balance, balance - amountIn, "test_SwapExactOutNtoTMultiHop::8");
        assertEq(wnative.balanceOf(market0w), amountIn, "test_SwapExactOutNtoTMultiHop::9");
        assertEq(IERC20(token0).balanceOf(address(this)), 0, "test_SwapExactOutNtoTMultiHop::10");

        uint256 balanceToken0 = IERC20(token0).balanceOf(market0w);
        assertLt(IERC20(token0).balanceOf(market0w), 500_000_000e18, "test_SwapExactOutNtoTMultiHop::11");
        assertEq(
            IERC20(token0).balanceOf(market10), 500_000_000e18 - balanceToken0, "test_SwapExactOutNtoTMultiHop::12"
        );

        balance = IERC20(token1).balanceOf(market10);
        assertEq(IERC20(token1).balanceOf(address(this)), 0, "test_SwapExactOutNtoTMultiHop::13");
        assertLt(IERC20(token1).balanceOf(market10), 100_000_000e18, "test_SwapExactOutNtoTMultiHop::14");
        assertEq(IERC20(token1).balanceOf(market21), 100_000_000e18 - balance, "test_SwapExactOutNtoTMultiHop::15");

        assertEq(IERC20(token2).balanceOf(address(this)), amountOut, "test_SwapExactOutNtoTMultiHop::16");
        assertEq(IERC20(token2).balanceOf(market21), 50_000_000e18 - amountOut, "test_SwapExactOutNtoTMultiHop::17");
    }

    function test_SwapExactOutTtoTtoTMultiHop() public {
        wnative.deposit{value: 1e18}();
        wnative.approve(address(router), 1e18);

        (int256 deltaBaseAmount,) = ITMMarket(market0w).getDeltaAmounts(0.9e18, false);
        (deltaBaseAmount,) = ITMMarket(market10).getDeltaAmounts(-deltaBaseAmount, false);
        (deltaBaseAmount,) = ITMMarket(market21).getDeltaAmounts(-deltaBaseAmount, false);

        bytes memory route =
            abi.encodePacked(wnative, uint32(3 << 24), token0, uint32(3 << 24), token1, uint32(3 << 24), token2);
        router.swapExactOut(route, address(this), uint256(-deltaBaseAmount), 1e18, block.timestamp);

        uint256 amountToken2 = IERC20(token2).balanceOf(address(this));
        IERC20(token2).approve(address(router), amountToken2);

        (, int256 deltaQuoteAmount) = ITMMarket(market21).getDeltaAmounts(int256(amountToken2 * 9 / 10), true);
        (, deltaQuoteAmount) = ITMMarket(market10).getDeltaAmounts(-deltaQuoteAmount, true);
        (, deltaQuoteAmount) = ITMMarket(market0w).getDeltaAmounts(-deltaQuoteAmount, true);

        route = abi.encodePacked(token2, uint32(3 << 24), token1, uint32(3 << 24), token0, uint32(3 << 24), wnative);
        (uint256 amountIn,) =
            router.swapExactOut(route, address(this), uint256(-deltaQuoteAmount), amountToken2, block.timestamp);

        uint256 wnativeBalance = wnative.balanceOf(address(this));
        assertGe(wnativeBalance, 1e18 - 0.9e18 + uint256(-deltaQuoteAmount), "test_SwapExactOutTtoTtoTMultiHop::1");
        assertEq(wnative.balanceOf(market0w), 1e18 - wnativeBalance, "test_SwapExactOutTtoTtoTMultiHop::2");

        uint256 token2Balance = IERC20(token2).balanceOf(address(this));
        assertEq(token2Balance, uint256(-deltaBaseAmount) - amountIn, "test_SwapExactOutTtoTtoTMultiHop::3");
        assertEq(
            IERC20(token2).balanceOf(market21), 50_000_000e18 - token2Balance, "test_SwapExactOutTtoTtoTMultiHop::4"
        );
    }

    function test_SwapExactOutNtoTtoNMultiHop() public {
        (int256 deltaBaseAmount,) = ITMMarket(market0w).getDeltaAmounts(0.9e18, false);
        (deltaBaseAmount,) = ITMMarket(market10).getDeltaAmounts(-deltaBaseAmount, false);
        (deltaBaseAmount,) = ITMMarket(market21).getDeltaAmounts(-deltaBaseAmount, false);

        uint256 balance = address(this).balance;

        bytes memory route =
            abi.encodePacked(address(0), uint32(3 << 24), token0, uint32(3 << 24), token1, uint32(3 << 24), token2);
        router.swapExactOut{value: 1e18}(route, address(this), uint256(-deltaBaseAmount), 1e18, block.timestamp);

        uint256 amountToken2 = IERC20(token2).balanceOf(address(this));
        IERC20(token2).approve(address(router), amountToken2);

        (, int256 deltaQuoteAmount) = ITMMarket(market21).getDeltaAmounts(int256(amountToken2 * 9 / 10), true);
        (, deltaQuoteAmount) = ITMMarket(market10).getDeltaAmounts(-deltaQuoteAmount, true);
        (, deltaQuoteAmount) = ITMMarket(market0w).getDeltaAmounts(-deltaQuoteAmount, true);

        route = abi.encodePacked(token2, uint32(3 << 24), token1, uint32(3 << 24), token0, uint32(3 << 24), address(0));
        (uint256 amountIn,) =
            router.swapExactOut(route, address(this), uint256(-deltaQuoteAmount), amountToken2, block.timestamp);

        assertGe(
            address(this).balance, balance - 0.9e18 + uint256(-deltaQuoteAmount), "test_SwapExactOutNtoTtoNMultiHop::1"
        );
        assertEq(wnative.balanceOf(market0w), balance - address(this).balance, "test_SwapExactOutNtoTtoNMultiHop::2");

        uint256 token2Balance = IERC20(token2).balanceOf(address(this));
        assertEq(token2Balance, uint256(-deltaBaseAmount) - amountIn, "test_SwapExactOutNtoTtoNMultiHop::3");
        assertEq(
            IERC20(token2).balanceOf(market21), 50_000_000e18 - token2Balance, "test_SwapExactOutNtoTtoNMultiHop::4"
        );
    }

    function test_SwapExactInNtoTSingleHopExcessNative() public {
        bytes memory route = abi.encodePacked(address(0), uint32(3 << 24), token0);

        uint256 balance = address(this).balance;
        assertEq(wnative.balanceOf(market0w), 0, "test_SwapExactInNtoTSingleHopExcessNative::1");
        assertEq(IERC20(token0).balanceOf(address(this)), 0, "test_SwapExactInNtoTSingleHopExcessNative::2");
        assertEq(IERC20(token0).balanceOf(market0w), 500_000_000e18, "test_SwapExactInNtoTSingleHopExcessNative::3");

        (, uint256 amountOut) = router.swapExactIn{value: 10e18}(route, address(this), 1e18, 1e18, block.timestamp);

        assertEq(address(this).balance, balance - 1e18, "test_SwapExactInNtoTSingleHopExcessNative::4");
        assertEq(wnative.balanceOf(market0w), 1e18, "test_SwapExactInNtoTSingleHopExcessNative::5");
        assertEq(IERC20(token0).balanceOf(address(this)), amountOut, "test_SwapExactInNtoTSingleHopExcessNative::6");
        assertEq(
            IERC20(token0).balanceOf(market0w),
            500_000_000e18 - amountOut,
            "test_SwapExactInNtoTSingleHopExcessNative::7"
        );
    }

    function test_SwapExactInTtoTtoTMultiHopTransferTaxTokens() public {
        wnative.deposit{value: 1e18}();
        wnative.approve(address(router), 1e18);

        uint256[] memory prices = new uint256[](2);

        prices[0] = 1e18;
        prices[1] = 1e18 + 1;

        factory.updateTokenImplementation(2, address(new TransferTaxToken(address(factory), 0.1e18)));
        (address taxToken, address market) = factory.createMarketAndToken(
            2, "TaxToken", "TT", address(wnative), 500_000_000e18, prices, prices, new bytes(0)
        );

        bytes memory route = abi.encodePacked(wnative, uint32(3 << 24), taxToken);

        (uint256 amountIn, uint256 amountOut) =
            router.swapExactInSupportingFeeOnTransferTokens(route, address(this), 1e18, 0, block.timestamp);

        assertEq(amountIn, 1e18, "test_SwapExactInTtoTtoTMultiHopTransferTaxTokens::1");
        assertApproxEqAbs(amountOut, 0.9e18, 1, "test_SwapExactInTtoTtoTMultiHopTransferTaxTokens::2");

        assertEq(
            IERC20(taxToken).balanceOf(address(this)), amountOut, "test_SwapExactInTtoTtoTMultiHopTransferTaxTokens::3"
        );
        assertEq(IERC20(wnative).balanceOf(market), 1e18, "test_SwapExactInTtoTtoTMultiHopTransferTaxTokens::4");

        IERC20(taxToken).approve(address(router), amountOut);

        route = abi.encodePacked(taxToken, uint32(3 << 24), wnative);

        vm.expectRevert(ITMMarket.TMMarket__InsufficientAmount.selector);
        router.swapExactIn(route, address(this), amountOut, 0, block.timestamp);

        uint256 balance = address(this).balance;

        (uint256 amountIn2, uint256 amountOut2) = router.swapExactInSupportingFeeOnTransferTokens{value: 1e18}(
            route, address(this), amountOut, 0, block.timestamp
        );

        assertEq(amountIn2, amountOut, "test_SwapExactInTtoTtoTMultiHopTransferTaxTokens::5");
        assertApproxEqAbs(amountOut2, 0.9e18 * 0.9e18 / 1e18, 1, "test_SwapExactInTtoTtoTMultiHopTransferTaxTokens::6");

        assertEq(address(this).balance, balance, "test_SwapExactInTtoTtoTMultiHopTransferTaxTokens::7");
        assertEq(wnative.balanceOf(address(this)), amountOut2, "test_SwapExactInTtoTtoTMultiHopTransferTaxTokens::8");
        assertEq(wnative.balanceOf(market), 1e18 - amountOut2, "test_SwapExactInTtoTtoTMultiHopTransferTaxTokens::9");
        assertEq(IERC20(taxToken).balanceOf(address(this)), 0, "test_SwapExactInTtoTtoTMultiHopTransferTaxTokens::10");
        assertGt(
            IERC20(taxToken).balanceOf(market),
            500_000_000e18 - amountOut,
            "test_SwapExactInTtoTtoTMultiHopTransferTaxTokens::11"
        );
    }

    function test_SwapExactInNtoTtoNMultiHopTransferTaxTokens() public {
        uint256[] memory prices = new uint256[](2);

        prices[0] = 1e18;
        prices[1] = 1e18 + 1;

        factory.updateTokenImplementation(2, address(new TransferTaxToken(address(factory), 0.1e18)));
        (address taxToken, address market) = factory.createMarketAndToken(
            2, "TaxToken", "TT", address(wnative), 500_000_000e18, prices, prices, new bytes(0)
        );

        uint256 balance = address(this).balance;

        bytes memory route = abi.encodePacked(address(0), uint32(3 << 24), taxToken);

        (uint256 amountIn, uint256 amountOut) =
            router.swapExactInSupportingFeeOnTransferTokens{value: 1e18}(route, address(this), 1e18, 0, block.timestamp);

        assertEq(amountIn, 1e18, "test_SwapExactInNtoTtoNMultiHopTransferTaxTokens::1");
        assertApproxEqAbs(amountOut, 0.9e18, 1, "test_SwapExactInNtoTtoNMultiHopTransferTaxTokens::2");

        assertEq(
            IERC20(taxToken).balanceOf(address(this)), amountOut, "test_SwapExactInNtoTtoNMultiHopTransferTaxTokens::3"
        );
        assertEq(address(this).balance, balance - amountIn, "test_SwapExactInNtoTtoNMultiHopTransferTaxTokens::4");

        IERC20(taxToken).approve(address(router), amountOut);

        route = abi.encodePacked(taxToken, uint32(3 << 24), address(0));

        vm.expectRevert(ITMMarket.TMMarket__InsufficientAmount.selector);
        router.swapExactIn(route, address(this), amountOut, 0, block.timestamp);

        (uint256 amountIn2, uint256 amountOut2) = router.swapExactInSupportingFeeOnTransferTokens{value: 1e18}(
            route, address(this), amountOut, 0, block.timestamp
        );

        assertEq(amountIn2, amountOut, "test_SwapExactInNtoTtoNMultiHopTransferTaxTokens::5");
        assertApproxEqAbs(amountOut2, 0.9e18 * 0.9e18 / 1e18, 1, "test_SwapExactInNtoTtoNMultiHopTransferTaxTokens::6");

        assertEq(
            address(this).balance,
            balance - amountIn + amountOut2,
            "test_SwapExactInNtoTtoNMultiHopTransferTaxTokens::7"
        );
        assertEq(wnative.balanceOf(address(this)), 0, "test_SwapExactInNtoTtoNMultiHopTransferTaxTokens::8");
        assertEq(wnative.balanceOf(market), 1e18 - amountOut2, "test_SwapExactInNtoTtoNMultiHopTransferTaxTokens::9");
        assertEq(IERC20(taxToken).balanceOf(address(this)), 0, "test_SwapExactInNtoTtoNMultiHopTransferTaxTokens::10");
        assertGt(
            IERC20(taxToken).balanceOf(market),
            500_000_000e18 - amountOut,
            "test_SwapExactInNtoTtoNMultiHopTransferTaxTokens::11"
        );
    }

    function test_Revert_SwapExactIn() public {
        bytes memory route = abi.encodePacked(address(0), uint32(3 << 24), token0);

        vm.expectRevert(IRouter.Router__ExceedsDeadline.selector);
        router.swapExactIn{value: 1e18}(new bytes(0), address(0), 0, 0, block.timestamp - 1);

        vm.expectRevert(IRouter.Router__InvalidRecipient.selector);
        router.swapExactIn{value: 1e18}(new bytes(0), address(router), 0, 0, block.timestamp);

        vm.expectRevert(IRouter.Router__InvalidRecipient.selector);
        router.swapExactInSupportingFeeOnTransferTokens{value: 1e18}(
            new bytes(0), address(router), 0, 0, block.timestamp
        );

        vm.expectRevert(IRouter.Router__InsufficientOutputAmount.selector);
        router.swapExactIn{value: 1e18}(route, address(this), 1e18, type(uint256).max, block.timestamp);

        vm.expectRevert(IRouter.Router__InsufficientOutputAmount.selector);
        router.swapExactInSupportingFeeOnTransferTokens{value: 1e18}(
            route, address(this), 1e18, type(uint256).max, block.timestamp
        );

        route = abi.encodePacked(token0, uint32(3 << 24), token1);
        deal(token0, address(this), 500_000_000e18 + 1);
        IERC20(token0).approve(address(router), 500_000_000e18 + 1);

        vm.expectRevert(IRouter.Router__InvalidAmounts.selector);
        router.swapExactIn(route, address(this), 500_000_000e18 + 1, 1e18, block.timestamp);

        vm.expectRevert(IRouter.Router__InvalidAmounts.selector);
        router.swapExactInSupportingFeeOnTransferTokens(route, address(this), 500_000_000e18 + 1, 1e18, block.timestamp);
    }

    function test_Revert_SwapExactOut() public {
        bytes memory route = abi.encodePacked(address(0), uint32(3 << 24), token0);

        vm.expectRevert(IRouter.Router__ExceedsDeadline.selector);
        router.swapExactOut(new bytes(0), address(0), 0, 0, block.timestamp - 1);

        vm.expectRevert(IRouter.Router__InvalidRecipient.selector);
        router.swapExactOut(new bytes(0), address(router), 0, 0, block.timestamp);

        vm.expectRevert(IRouter.Router__InvalidAmounts.selector);
        router.swapExactOut{value: 1e18}(route, address(this), 500_000_000e18 + 1, 0, block.timestamp);

        route = abi.encodePacked(token0, uint32(3 << 24), address(0));

        vm.expectRevert(IRouter.Router__InvalidAmounts.selector);
        router.swapExactOut(route, address(this), type(uint128).max, 0, block.timestamp);

        route = abi.encodePacked(address(0), uint32(3 << 24), token0);

        vm.expectRevert(IRouter.Router__ExceedsMaxInputAmount.selector);
        router.swapExactOut(route, address(this), 1, 0, block.timestamp);

        uint256[] memory prices = new uint256[](2);

        prices[0] = 1e18;
        prices[1] = 1e18 + 1;

        factory.updateTokenImplementation(2, address(new TransferTaxToken(address(factory), 0.1e18)));
        (address taxToken,) = factory.createMarketAndToken(
            2, "TaxToken", "TT", address(wnative), 500_000_000e18, prices, prices, new bytes(0)
        );

        route = abi.encodePacked(address(0), uint32(3 << 24), taxToken);

        vm.expectRevert(IRouter.Router__InsufficientOutputAmount.selector);
        router.swapExactOut{value: 1e18}(route, address(this), 1e18 - 1, 1e18, block.timestamp);
    }

    function test_CreateTMMarketAndVesting() public {
        CliffVestingContract vesting;
        vesting = new CliffVestingContract();

        wnative.deposit{value: 1e18}();
        wnative.approve(address(router), 1e18);

        IRouter.TMMarketCreationAndPurchaseArgs memory args = IRouter.TMMarketCreationAndPurchaseArgs({
            tokenType: 1,
            name: "Token0-V",
            symbol: "T0-V", 
            quoteToken: address(wnative), 
            totalSupply: 500_000_000e18, 
            bidPrices: bidPrices0w, 
            askPrices: askPrices0w, 
            args: abi.encode(18),
            quoteTokenAmountIn: 0,
            baseTokenAmountOutMin: 1e22
        });
        IRouter.VestingArgs[] memory vestings = new IRouter.VestingArgs[](2);
        uint256 expectedBasePurchaseAmount = 7071067811865475244008; // pre-computed

        vm.expectRevert(IRouter.Router__InsufficientReceivedQuote.selector);
        (address baseToken, address market, uint256 baseAmountReceived) = router.createTMMarketAndVesting(
            args, address(vesting), vestings
        );

        args.quoteTokenAmountIn = 1e18;

        vm.expectRevert(IRouter.Router__InsufficientReceivedBase.selector);
        (baseToken, market, baseAmountReceived) = router.createTMMarketAndVesting(
            args, address(vesting), vestings
        );

        args.baseTokenAmountOutMin = 1e21;

        vm.expectRevert(ICliffVestingContract.CliffVestingContract__InvalidVestingSchedule.selector);
        (baseToken, market, baseAmountReceived) = router.createTMMarketAndVesting(
            args, address(vesting), vestings
        );

        vestings[0] = IRouter.VestingArgs({
            beneficiary: address(1),
            amount: 1e18,
            start: uint80(block.timestamp),
            cliffDuration: uint80(block.timestamp + 3600),
            vestingDuration: uint80(block.timestamp + 3600)
        });

        vestings[1] = IRouter.VestingArgs({
            beneficiary: address(2),
            amount: 1e18,
            start: uint80(block.timestamp),
            cliffDuration: uint80(block.timestamp + 3600),
            vestingDuration: uint80(block.timestamp + 3600)
        });

        vm.expectRevert(IRouter.Router__InsufficientVestingAllocation.selector);
        (baseToken, market, baseAmountReceived) = router.createTMMarketAndVesting(
            args, address(vesting), vestings
        );

        vestings[1].amount = uint128(expectedBasePurchaseAmount - 1e18);

        (baseToken, market, baseAmountReceived) = router.createTMMarketAndVesting(
            args, address(vesting), vestings
        );

        assertEq(factory.getCreatorOf(market), address(this), "test_CreateTMMarketAndCreateVesting::1");
        
        assertEq(IERC20(baseToken).balanceOf(address(vesting)), baseAmountReceived, "test_CreateTMMarketAndCreateVesting::2");
        
        assertEq(IERC20(baseToken).balanceOf(address(router)), 0, "test_CreateTMMarketAndCreateVesting::3");
        
        assertEq(wnative.balanceOf(address(router)), 0, "test_CreateTMMarketAndCreateVesting::4");
        
        assertEq(wnative.balanceOf(market), 1e18, "test_CreateTMMarketAndCreateVesting::5");

        assertEq(vesting.getNumberOfVestings(baseToken), 2, "test_CreateTMMarketAndCreateVesting::6");

        ICliffVestingContract.VestingSchedule memory vestingSchedule = vesting.getVestingSchedule(
            baseToken, 0
        );

        assertEq(vestingSchedule.beneficiary, address(1), "test_CreateTMMarketAndCreateVesting::7");
        assertEq(vestingSchedule.total, 1e18, "test_CreateTMMarketAndCreateVesting::8");

        vestingSchedule = vesting.getVestingSchedule(baseToken, 1);        

        assertEq(vestingSchedule.beneficiary, address(2), "test_CreateTMMarketAndCreateVesting::9");
        assertEq(vestingSchedule.total, uint128(expectedBasePurchaseAmount - 1e18), "test_CreateTMMarketAndCreateVesting::10");
    }
}
