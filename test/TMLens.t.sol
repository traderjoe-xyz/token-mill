// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/proxy/utils/Initializable.sol";

import "./TestHelper.sol";
import "../src/TMLens.sol";
import "../src/utils/TMStaking.sol";
import "../src/interfaces/ITMStaking.sol";

contract EmptyContract {}

contract TestTMLens is TestHelper {
    ITMStaking public staking;
    TMLens lens;

    address alice = makeAddr("alice");
    address bob = makeAddr("bob");

    function setUpStaking() public {
        address stakingImp = address(new TMStaking(address(factory)));
        staking = ITMStaking(
            address(
                new TransparentUpgradeableProxy(stakingImp, address(this), abi.encodeCall(ITMStaking.initialize, ()))
            )
        );
    }

    function simulateStaking() public {
        factory.updateProtocolFeeRecipient(address(1));

        vm.deal(alice, 1e18);
        vm.startPrank(alice);

        wnative.deposit{value: 1e18}();
        wnative.transfer(market0w, 1e18);

        ITMMarket(market0w).swap(alice, 1e18, false, "", alice);

        IERC20(token0).approve(address(staking), 3e18);
        staking.deposit(token0, alice, 1e18, 0);

        staking.createVestingSchedule(token0, bob, 2e18, 0, uint80(block.timestamp), 100, 100);

        vm.stopPrank();
    }

    function setUp() public override {
        stakingAddress = _predictContractAddress(6);

        super.setUp();
        setUpTokens();
        setUpStaking();

        lens = new TMLens(ITMFactory(address(factory)));

        factory.updateReferrerShare(0.2e4);
    }

    function test_getAggregateMarketData() public view {
        TMLens.AggregateMarketData memory aggregateMarketData = lens.getAggregateMarketData(0, 10);

        assertEq(aggregateMarketData.whitelistedQuoteTokens.length, 3, "test_getAggregateMarketData::1");
        assertEq(aggregateMarketData.whitelistedQuoteTokens[0], address(wnative), "test_getAggregateMarketData::2");

        TMLens.MarketData memory marketData = aggregateMarketData.allMarketData[0];
        assertEq(marketData.market, market0w, "test_getAggregateMarketData::3");
        assertEq(marketData.quoteToken, address(wnative), "test_getAggregateMarketData::4");
        assertEq(marketData.baseToken, address(token0), "test_getAggregateMarketData::5");

        aggregateMarketData = lens.getAggregateMarketData(2, 1);
        marketData = aggregateMarketData.allMarketData[0];
        assertEq(marketData.market, market21, "test_getAggregateMarketData::6");
        assertEq(marketData.quoteToken, token1, "test_getAggregateMarketData::7");
        assertEq(marketData.baseToken, token2, "test_getAggregateMarketData::8");
    }

    function test_getSingleDetailedMarketData() public {
        EmptyContract ec = new EmptyContract();
        TMLens.DetailedMarketData memory detailedMarketData = lens.getSingleDetailedMarketData(address(ec), alice);
        assertEq(detailedMarketData.marketExists, false, "test_getSingleDetailedMarketData::1");

        detailedMarketData = lens.getSingleDetailedMarketData(address(0), address(0));
        assertEq(detailedMarketData.marketExists, false, "test_getSingleDetailedMarketData::2");

        detailedMarketData = lens.getSingleDetailedMarketData(market0w, alice);
        assertEq(detailedMarketData.marketExists, true, "test_getSingleDetailedMarketData::3");
        assertEq(detailedMarketData.quoteToken, address(wnative), "test_getSingleDetailedMarketData::4");
        assertEq(detailedMarketData.baseToken, token0, "test_getSingleDetailedMarketData::5");
        assertEq(detailedMarketData.baseTokenType, 1, "test_getSingleDetailedMarketData::6");
        assertEq(detailedMarketData.quoteTokenDecimals, 18, "test_getSingleDetailedMarketData::7");
        assertEq(detailedMarketData.baseTokenDecimals, 18, "test_getSingleDetailedMarketData::8");
        assertEq(detailedMarketData.quoteTokenName, "Wrapped Native", "test_getSingleDetailedMarketData::9");
        assertEq(detailedMarketData.baseTokenName, "Token0", "test_getSingleDetailedMarketData::10");
        assertEq(detailedMarketData.quoteTokenSymbol, "WNATIVE", "test_getSingleDetailedMarketData::11");
        assertEq(detailedMarketData.baseTokenSymbol, "T0", "test_getSingleDetailedMarketData::12");
        assertEq(detailedMarketData.marketCreator, address(this), "test_getSingleDetailedMarketData::13");
        assertEq(detailedMarketData.protocolShare, 0.2e4, "test_getSingleDetailedMarketData::14");
        assertEq(detailedMarketData.creatorShare, 0.2e4, "test_getSingleDetailedMarketData::15");
        assertEq(detailedMarketData.referrerShare, 0.2e4, "test_getSingleDetailedMarketData::16");
        assertEq(detailedMarketData.stakingShare, 0.6e4, "test_getSingleDetailedMarketData::17");
        assertEq(detailedMarketData.totalSupply, 500_000_000e18, "test_getSingleDetailedMarketData::18");
        assertEq(detailedMarketData.circulatingSupply, 0, "test_getSingleDetailedMarketData::19");
        assertEq(detailedMarketData.spotPriceFillBid, 0, "test_getSingleDetailedMarketData::20");
        assertEq(detailedMarketData.spotPriceFillAsk, 0, "test_getSingleDetailedMarketData::21");
        assertEq(detailedMarketData.askPrices, askPrices0w, "test_getSingleDetailedMarketData::22");
        assertEq(detailedMarketData.bidPrices, bidPrices0w, "test_getSingleDetailedMarketData::23");
        assertEq(detailedMarketData.protocolPendingFees, 0, "test_getSingleDetailedMarketData::24");
        assertEq(detailedMarketData.creatorPendingFees, 0, "test_getSingleDetailedMarketData::25");
        assertEq(detailedMarketData.referrerPendingFees, 0, "test_getSingleDetailedMarketData::26");
        assertEq(detailedMarketData.stakingPendingFees, 0, "test_getSingleDetailedMarketData::27");
    }

    function test_getMultipleDetailedMarketData() public view {
        address[] memory marketAddresses = new address[](2);
        marketAddresses[0] = market0w;
        marketAddresses[1] = market21;

        TMLens.DetailedMarketData[] memory detailedMarketData =
            lens.getMultipleDetailedMarketData(marketAddresses, alice);
        assertEq(detailedMarketData.length, 2, "test_getMultipleDetailedMarketData::1");

        uint256[] memory askPrices = new uint256[](3);
        askPrices[0] = 10e18;
        askPrices[1] = 20e18;
        askPrices[2] = 21e18;

        uint256[] memory bidPrices = new uint256[](3);
        bidPrices[0] = 1e18;
        bidPrices[1] = 10e18;
        bidPrices[2] = 20e18;

        assertEq(detailedMarketData[1].marketExists, true, "test_getMultipleDetailedMarketData::2");
        assertEq(detailedMarketData[1].quoteToken, token1, "test_getMultipleDetailedMarketData::3");
        assertEq(detailedMarketData[1].baseToken, token2, "test_getMultipleDetailedMarketData::4");
        assertEq(detailedMarketData[1].baseTokenType, 1, "test_getMultipleDetailedMarketData::5");
        assertEq(detailedMarketData[1].quoteTokenDecimals, 18, "test_getMultipleDetailedMarketData::6");
        assertEq(detailedMarketData[1].baseTokenDecimals, 18, "test_getMultipleDetailedMarketData::7");
        assertEq(detailedMarketData[1].quoteTokenName, "Token1", "test_getMultipleDetailedMarketData::8");
        assertEq(detailedMarketData[1].baseTokenName, "Token2", "test_getMultipleDetailedMarketData::9");
        assertEq(detailedMarketData[1].quoteTokenSymbol, "T1", "test_getMultipleDetailedMarketData::10");
        assertEq(detailedMarketData[1].baseTokenSymbol, "T2", "test_getMultipleDetailedMarketData::11");
        assertEq(detailedMarketData[1].marketCreator, address(this), "test_getMultipleDetailedMarketData::12");
        assertEq(detailedMarketData[1].protocolShare, 0.2e4, "test_getMultipleDetailedMarketData::13");
        assertEq(detailedMarketData[1].creatorShare, 0.2e4, "test_getMultipleDetailedMarketData::14");
        assertEq(detailedMarketData[1].referrerShare, 0.2e4, "test_getMultipleDetailedMarketData::15");
        assertEq(detailedMarketData[1].stakingShare, 0.6e4, "test_getMultipleDetailedMarketData::16");
        assertEq(detailedMarketData[1].totalSupply, 50_000_000e18, "test_getMultipleDetailedMarketData::17");
        assertEq(detailedMarketData[1].circulatingSupply, 0, "test_getMultipleDetailedMarketData::18");
        assertEq(detailedMarketData[1].spotPriceFillBid, bidPrices[0], "test_getMultipleDetailedMarketData::19");
        assertEq(detailedMarketData[1].spotPriceFillAsk, askPrices[0], "test_getMultipleDetailedMarketData::20");
        assertEq(detailedMarketData[1].askPrices, askPrices, "test_getMultipleDetailedMarketData::21");
        assertEq(detailedMarketData[1].bidPrices, bidPrices, "test_getMultipleDetailedMarketData::22");
        assertEq(detailedMarketData[1].protocolPendingFees, 0, "test_getMultipleDetailedMarketData::23");
        assertEq(detailedMarketData[1].creatorPendingFees, 0, "test_getMultipleDetailedMarketData::24");
        assertEq(detailedMarketData[1].referrerPendingFees, 0, "test_getMultipleDetailedMarketData::25");
        assertEq(detailedMarketData[1].stakingPendingFees, 0, "test_getMultipleDetailedMarketData::26");
        assertEq(detailedMarketData[1].totalStaked, 0, "test_getMultipleDetailedMarketData::27");
        assertEq(detailedMarketData[1].totalLocked, 0, "test_getMultipleDetailedMarketData::28");
    }

    function test_getCreatorData() public view {
        TMLens.CreatorData memory creatorData = lens.getCreatorData(address(this));

        assertEq(creatorData.creatorMarkets.length, 3, "test_getCreatorData::1");
        assertEq(creatorData.creatorMarketPendingFees.length, 3, "test_getCreatorData::2");
        assertEq(creatorData.creatorMarkets[0], market0w, "test_getCreatorData::3");
        assertEq(creatorData.creatorMarketPendingFees[0], 0, "test_getCreatorData::4");

        creatorData = lens.getCreatorData(address(0));
        assertEq(creatorData.creatorMarkets.length, 0, "test_getCreatorData::5");
        assertEq(creatorData.creatorMarketPendingFees.length, 0, "test_getCreatorData::6");
    }

    function test_getDetailedStakingDataPerUser() public {
        simulateStaking();

        TMLens.SingleTokenUserStakingData[] memory detailedStakingData =
            lens.getMultipleDetailedStakingDataPerUser(alice, 1, 1, 0, 10);

        assertEq(detailedStakingData.length, 0, "test_getDetailedStakingDataPerUser::1");

        detailedStakingData = lens.getMultipleDetailedStakingDataPerUser(alice, 0, 1, 0, 10);

        assertEq(detailedStakingData.length, 1, "test_getDetailedStakingDataPerUser::2");
        assertEq(detailedStakingData[0].sharesAmount, 1e18, "test_getDetailedStakingDataPerUser::3");
        assertEq(detailedStakingData[0].lockedSharesAmount, 0, "test_getDetailedStakingDataPerUser::4");
        assertEq(detailedStakingData[0].pendingRewards, 6e16, "test_getDetailedStakingDataPerUser::5");
        assertEq(detailedStakingData[0].vestingSchedules.length, 0, "test_getDetailedStakingDataPerUser::6");

        TMLens.SingleTokenUserStakingData memory detailedSingleStakingData =
            lens.getSingleDetailedStakingDataPerUser(bob, token0, 0, 10);

        assertEq(detailedSingleStakingData.market, market0w, "test_getDetailedStakingDataPerUser::7");
        assertEq(detailedSingleStakingData.baseToken, token0, "test_getDetailedStakingDataPerUser::8");
        assertEq(detailedSingleStakingData.baseTokenName, "Token0", "test_getDetailedStakingDataPerUser::9");
        assertEq(detailedSingleStakingData.baseTokenSymbol, "T0", "test_getDetailedStakingDataPerUser::10");
        assertEq(detailedSingleStakingData.baseTokenDecimals, 18, "test_getDetailedStakingDataPerUser::11");
        assertEq(detailedSingleStakingData.quoteToken, address(wnative), "test_getDetailedStakingDataPerUser::12");
        assertEq(detailedSingleStakingData.quoteTokenName, "Wrapped Native", "test_getDetailedStakingDataPerUser::13");
        assertEq(detailedSingleStakingData.quoteTokenSymbol, "WNATIVE", "test_getDetailedStakingDataPerUser::14");
        assertEq(detailedSingleStakingData.quoteTokenDecimals, 18, "test_getDetailedStakingDataPerUser::15");
        assertEq(detailedSingleStakingData.sharesAmount, 0, "test_getDetailedStakingDataPerUser::16");
        assertEq(detailedSingleStakingData.lockedSharesAmount, 2e18, "test_getDetailedStakingDataPerUser::17");
        assertEq(detailedSingleStakingData.pendingRewards, 0, "test_getDetailedStakingDataPerUser::18");
        assertEq(detailedSingleStakingData.vestingSchedules.length, 1, "test_getDetailedStakingDataPerUser::19");

        ITMStaking.VestingSchedule memory vestingSchedule = detailedSingleStakingData.vestingSchedules[0];

        assertEq(vestingSchedule.beneficiary, bob, "test_getDetailedStakingDataPerUser::20");
        assertEq(vestingSchedule.total, 2e18, "test_getDetailedStakingDataPerUser::21");
        assertEq(vestingSchedule.released, 0, "test_getDetailedStakingDataPerUser::22");
        assertEq(vestingSchedule.start, 1, "test_getDetailedStakingDataPerUser::23");
        assertEq(vestingSchedule.cliffDuration, 100, "test_getDetailedStakingDataPerUser::24");
        assertEq(vestingSchedule.vestingDuration, 100, "test_getDetailedStakingDataPerUser::25");

        TMLens.DetailedMarketData memory detailedMarketData = lens.getSingleDetailedMarketData(market0w, address(0));
        assertEq(detailedMarketData.totalStaked, 1e18, "test_getDetailedStakingDataPerUser::26");
        assertEq(detailedMarketData.totalLocked, 2e18, "test_getDetailedStakingDataPerUser::27");
    }

    function test_getSingleDetailedTokenStakingData() public {
        simulateStaking();

        TMLens.DetailedTokenStakingData memory tokenStakingData = lens.getSingleDetailedTokenStakingData(token0);

        assertEq(tokenStakingData.totalStaked, 1e18, "test_getSingleDetailedTokenStakingData::1");
        assertEq(tokenStakingData.totalLocked, 2e18, "test_getSingleDetailedTokenStakingData::2");
        assertEq(tokenStakingData.vestingSchedules.length, 1, "test_getSingleDetailedTokenStakingData::3");

        ITMStaking.VestingSchedule memory vestingSchedule = tokenStakingData.vestingSchedules[0];

        assertEq(vestingSchedule.beneficiary, bob, "test_getSingleDetailedTokenStakingData::4");
        assertEq(vestingSchedule.total, 2e18, "test_getSingleDetailedTokenStakingData::5");
        assertEq(vestingSchedule.released, 0, "test_getSingleDetailedTokenStakingData::6");
        assertEq(vestingSchedule.start, 1, "test_getSingleDetailedTokenStakingData::7");
        assertEq(vestingSchedule.cliffDuration, 100, "test_getSingleDetailedTokenStakingData::8");
        assertEq(vestingSchedule.vestingDuration, 100, "test_getSingleDetailedTokenStakingData::9");
    }
}
