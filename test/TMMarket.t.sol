// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./TestHelper.sol";

import "./mocks/TransferTaxToken.sol";

contract TestTMMarket is TestHelper {
    bytes32 private _callbackReturn;

    function setUp() public override {
        stakingAddress = address(1);

        super.setUp();
        setUpTokens();
    }

    function test_Initialize() public {
        vm.expectRevert(ITMMarket.TMMarket__OnlyFactory.selector);
        ITMMarket(market0w).initialize();
    }

    function test_Getters() public view {
        assertEq(ITMMarket(market0w).getFactory(), address(factory), "test_Getters::1");
        assertEq(ITMMarket(market0w).getBaseToken(), token0, "test_Getters::2");
        assertEq(ITMMarket(market0w).getQuoteToken(), address(wnative), "test_Getters::3");
        assertEq(ITMMarket(market0w).getCirculatingSupply(), 0, "test_Getters::4");
        assertEq(ITMMarket(market0w).getTotalSupply(), 500_000_000e18, "test_Getters::5");

        (uint256 baseReserve, uint256 quoteReserve) = ITMMarket(market0w).getReserves();

        assertEq(baseReserve, 500_000_000e18, "test_Getters::6");
        assertEq(quoteReserve, 0, "test_Getters::7");

        uint256[] memory prices = ITMMarket(market0w).getPricePoints(true);

        assertEq(prices.length, 3, "test_Getters::8");
        assertEq(prices[0], askPrices0w[0], "test_Getters::9");
        assertEq(prices[1], askPrices0w[1], "test_Getters::10");
        assertEq(prices[2], askPrices0w[2], "test_Getters::11");

        prices = ITMMarket(market0w).getPricePoints(false);

        assertEq(prices.length, 3, "test_Getters::12");
        assertEq(prices[0], bidPrices0w[0], "test_Getters::13");
        assertEq(prices[1], bidPrices0w[1], "test_Getters::14");
        assertEq(prices[2], bidPrices0w[2], "test_Getters::15");
    }

    function test_Fuzz_GetPriceAt(uint256 circulatingSupply) public view {
        circulatingSupply = bound(circulatingSupply, 0, 500_000_000e18);

        uint256 askPrice = ITMMarket(market0w).getPriceAt(circulatingSupply, false);
        uint256 bidPrice = ITMMarket(market0w).getPriceAt(circulatingSupply, true);

        uint256 width = 500_000_000e18 / 2;
        uint256 index = circulatingSupply / width;

        if (circulatingSupply == width * index) {
            assertEq(askPrice, askPrices0w[index], "test_Fuzz_GetPriceAt::1");
            assertEq(bidPrice, bidPrices0w[index], "test_Fuzz_GetPriceAt::2");
        } else {
            uint256 expectedAskPrice = askPrices0w[index]
                + Math.div((askPrices0w[index + 1] - askPrices0w[index]) * (circulatingSupply - index * width), width, true);
            uint256 expectedBidPrice = bidPrices0w[index]
                + Math.div(
                    (bidPrices0w[index + 1] - bidPrices0w[index]) * (circulatingSupply - index * width), width, false
                );

            assertEq(askPrice, expectedAskPrice, "test_Fuzz_GetPriceAt::3");
            assertEq(bidPrice, expectedBidPrice, "test_Fuzz_GetPriceAt::4");
        }
    }

    function test_Revert_Swap() external {
        vm.expectRevert(ITMMarket.TMMarket__InvalidRecipient.selector);
        ITMMarket(market0w).swap(address(0), 0, false, new bytes(0), address(0));

        vm.expectRevert(ITMMarket.TMMarket__ZeroAmount.selector);
        ITMMarket(market0w).swap(address(this), 0, false, new bytes(0), address(0));

        vm.expectRevert(ITMMarket.TMMarket__InvalidSwapCallback.selector);
        ITMMarket(market0w).swap(address(this), 1, false, abi.encode(address(0)), address(0));

        vm.expectRevert(ITMMarket.TMMarket__ReentrantCall.selector);
        ITMMarket(market0w).swap(
            address(this),
            1,
            false,
            abi.encode(
                address(market0w), abi.encodeWithSelector(ITMMarket.swap.selector, address(0), 0, false, new bytes(0))
            ),
            address(0)
        );

        vm.expectRevert(ITMMarket.TMMarket__InsufficientAmount.selector);
        ITMMarket(market0w).swap(address(this), 1e18, false, new bytes(0), address(0));

        deal(address(wnative), address(market0w), 100e18);
        (int256 deltaBaseAmount,) = ITMMarket(market0w).swap(address(this), 1e18, false, new bytes(0), address(0));

        uint256 balance = wnative.balanceOf(address(factory));

        (uint256 baseReserve, uint256 quoteReserve) = ITMMarket(market0w).getReserves();
        (uint256 creatorFees, uint256 stakingFees) = ITMMarket(market0w).getPendingFees();

        assertEq(baseReserve, 500_000_000e18 - uint256(-deltaBaseAmount), "test_Revert_Swap::1");
        assertEq(quoteReserve, 100e18 - balance - creatorFees - stakingFees, "test_Revert_Swap::2");

        vm.expectRevert(ITMMarket.TMMarket__InsufficientAmount.selector);
        ITMMarket(market0w).swap(address(this), 1e18, true, new bytes(0), address(0));
    }

    struct Fees {
        uint256 creatorFees;
        uint256 stakingFees;
    }

    function test_ClaimFees() external {
        Fees memory fees;
        (fees.creatorFees, fees.stakingFees) = ITMMarket(market0w).getPendingFees();

        assertEq(fees.creatorFees, 0, "test_ClaimFees::1");
        assertEq(fees.stakingFees, 0, "test_ClaimFees::2");

        bytes memory route = abi.encodePacked(address(0), uint32(3 << 24), token0);
        (, uint256 amountOut) =
            router.swapExactIn{value: 10e18}(route, address(this), 10e18, 0, block.timestamp, address(this));

        (fees.creatorFees, fees.stakingFees) = ITMMarket(market0w).getPendingFees();

        assertGt(fees.creatorFees, 0, "test_ClaimFees::3");
        assertGt(fees.stakingFees, 0, "test_ClaimFees::4");

        vm.prank(address(factory));
        ITMMarket(market0w).claimFees(address(this), address(this), address(this));

        assertEq(wnative.balanceOf(address(this)), fees.creatorFees + fees.stakingFees, "test_ClaimFees::5");

        (fees.creatorFees, fees.stakingFees) = ITMMarket(market0w).getPendingFees();

        assertEq(fees.creatorFees, 0, "test_ClaimFees::6");
        assertEq(fees.stakingFees, 0, "test_ClaimFees::7");

        IERC20(token0).approve(address(router), amountOut);
        route = abi.encodePacked(token0, uint32(3 << 24), address(wnative));

        router.swapExactIn(route, address(this), amountOut, 0, block.timestamp, address(0));

        assertApproxEqAbs(IERC20(wnative).balanceOf(market0w), 0, 1, "test_ClaimFees::8");
    }

    function test_Revert_ClaimFees() external {
        vm.expectRevert(ITMMarket.TMMarket__OnlyFactory.selector);
        ITMMarket(market0w).claimFees(address(0), address(0), address(0));
    }

    function test_SwapUsingCallback() external {
        _callbackReturn = ITokenMillCallback.tokenMillSwapCallback.selector;

        wnative.deposit{value: 10e18}();

        bytes memory data =
            abi.encode(address(wnative), abi.encodeWithSelector(IERC20.transfer.selector, market0w, 10e18));

        (int256 deltaBaseAmount, int256 deltaQuoteAmount) =
            ITMMarket(market0w).swap(address(this), 10e18, false, data, address(0));

        assertEq(deltaQuoteAmount, 10e18, "test_SwapUsingCallback::1");
        assertLt(deltaBaseAmount, 0, "test_SwapUsingCallback::2");
        assertEq(wnative.balanceOf(address(this)), 0, "test_SwapUsingCallback::3");
        assertEq(wnative.balanceOf(market0w) + wnative.balanceOf(address(factory)), 10e18, "test_SwapUsingCallback::4");
        assertEq(IERC20(token0).balanceOf(address(this)), uint256(-deltaBaseAmount), "test_SwapUsingCallback::5");
        assertEq(
            IERC20(token0).balanceOf(market0w), 500_000_000e18 - uint256(-deltaBaseAmount), "test_SwapUsingCallback::6"
        );
    }

    function tokenMillSwapCallback(int256, int256, bytes calldata data) external returns (bytes32) {
        if (data.length > 32) {
            (address cAddress, bytes memory cData) = abi.decode(data, (address, bytes));

            (bool s,) = address(cAddress).call(cData);

            if (!s) {
                assembly ("memory-safe") {
                    returndatacopy(0, 0, returndatasize())
                    revert(0, returndatasize())
                }
            }
        }

        return _callbackReturn;
    }

    function test_unclaimedClaimedFees() external {
        Fees memory fees;
        (fees.creatorFees, fees.stakingFees) = ITMMarket(market0w).getPendingFees();

        assertEq(fees.creatorFees, 0, "test_unclaimedClaimedFees::1");
        assertEq(fees.stakingFees, 0, "test_unclaimedClaimedFees::2");

        bytes memory route = abi.encodePacked(address(0), uint32(3 << 24), token0);
        (, uint256 amountOut) =
            router.swapExactIn{value: 10e18}(route, address(this), 10e18, 0, block.timestamp, address(this));

        (fees.creatorFees, fees.stakingFees) = ITMMarket(market0w).getPendingFees();

        assertGt(fees.creatorFees, 0, "test_unclaimedClaimedFees::3");
        assertGt(fees.stakingFees, 0, "test_unclaimedClaimedFees::4");

        vm.prank(address(factory));
        uint256 feesClaimed1 = ITMMarket(market0w).claimFees(address(this), address(0), address(0));

        Fees memory unclaimedFees;

        (unclaimedFees.creatorFees, unclaimedFees.stakingFees) = ITMMarket(market0w).getPendingFees();

        assertEq(unclaimedFees.creatorFees, fees.creatorFees, "test_unclaimedClaimedFees::5");
        assertEq(unclaimedFees.stakingFees, fees.stakingFees, "test_unclaimedClaimedFees::6");

        (, uint256 amountOut2) =
            router.swapExactIn{value: 10e18}(route, address(this), 10e18, 0, block.timestamp, address(this));

        vm.prank(address(factory));
        uint256 feesClaimed2 = ITMMarket(market0w).claimFees(address(this), address(this), address(this));

        assertEq(wnative.balanceOf(address(this)), feesClaimed1 + feesClaimed2, "test_unclaimedClaimedFees::7");
        assertApproxEqAbs(
            feesClaimed1 + feesClaimed2, (fees.creatorFees + fees.stakingFees) * 2, 1, "test_unclaimedClaimedFees::8"
        );

        (fees.creatorFees, fees.stakingFees) = ITMMarket(market0w).getPendingFees();

        assertEq(fees.creatorFees, 0, "test_unclaimedClaimedFees::9");
        assertEq(fees.stakingFees, 0, "test_unclaimedClaimedFees::10");

        IERC20(token0).approve(address(router), amountOut + amountOut2);
        route = abi.encodePacked(token0, uint32(3 << 24), address(wnative));

        router.swapExactIn(route, address(this), amountOut + amountOut2, 0, block.timestamp, address(0));

        assertApproxEqAbs(IERC20(wnative).balanceOf(market0w), 0, 1, "test_unclaimedClaimedFees::11");
    }
}
