// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./TestHelper.sol";
import "../src/TMLens.sol";

contract EmptyContract {}

contract TestTMLens is TestHelper {
    TMLens lens;

    function setUp() public override {
        super.setUp();
        setUpTokens();

        lens = new TMLens(ITMFactory(address(factory)));
    }

    function test_getAggregateMarketData() public {
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
        TMLens.DetailedMarketData memory detailedMarketData = lens.getSingleDetailedMarketData(address(ec));
        assertEq(detailedMarketData.marketExists, false, "test_getSingleDetailedMarketData::1");

        detailedMarketData = lens.getSingleDetailedMarketData(address(0));
        assertEq(detailedMarketData.marketExists, false, "test_getSingleDetailedMarketData::2");

        detailedMarketData = lens.getSingleDetailedMarketData(market0w);
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
        assertEq(detailedMarketData.protocolShare, 1e17, "test_getSingleDetailedMarketData::14");
        assertEq(detailedMarketData.totalSupply, 500_000_000e18, "test_getSingleDetailedMarketData::15");
        assertEq(detailedMarketData.circulatingSupply, 0, "test_getSingleDetailedMarketData::16");
        assertEq(detailedMarketData.spotPriceFillBid, 0, "test_getSingleDetailedMarketData::17");
        assertEq(detailedMarketData.spotPriceFillAsk, 0, "test_getSingleDetailedMarketData::18");
        assertEq(detailedMarketData.askPrices, askPrices0w, "test_getSingleDetailedMarketData::19");
        assertEq(detailedMarketData.bidPrices, bidPrices0w, "test_getSingleDetailedMarketData::20");
        assertEq(detailedMarketData.protocolPendingFees, 0, "test_getSingleDetailedMarketData::21");
        assertEq(detailedMarketData.creatorPendingFees, 0, "test_getSingleDetailedMarketData::22");
    }

    function test_getMultipleDetailedMarketData() public {
        address[] memory marketAddresses = new address[](2);
        marketAddresses[0] = market0w;
        marketAddresses[1] = market21;

        TMLens.DetailedMarketData[] memory detailedMarketData = lens.getMultipleDetailedMarketData(marketAddresses);
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
        assertEq(detailedMarketData[1].protocolShare, 1e17, "test_getMultipleDetailedMarketData::13");
        assertEq(detailedMarketData[1].totalSupply, 50_000_000e18, "test_getMultipleDetailedMarketData::14");
        assertEq(detailedMarketData[1].circulatingSupply, 0, "test_getMultipleDetailedMarketData::15");
        assertEq(detailedMarketData[1].spotPriceFillBid, bidPrices[0], "test_getMultipleDetailedMarketData::16");
        assertEq(detailedMarketData[1].spotPriceFillAsk, askPrices[0], "test_getMultipleDetailedMarketData::17");
        assertEq(detailedMarketData[1].askPrices, askPrices, "test_getMultipleDetailedMarketData::18");
        assertEq(detailedMarketData[1].bidPrices, bidPrices, "test_getMultipleDetailedMarketData::19");
        assertEq(detailedMarketData[1].protocolPendingFees, 0, "test_getMultipleDetailedMarketData::20");
        assertEq(detailedMarketData[1].creatorPendingFees, 0, "test_getMultipleDetailedMarketData::21");
    }

    function test_getCreatorData() public {
        TMLens.CreatorData memory creatorData = lens.getCreatorData(address(this));

        assertEq(creatorData.creatorMarkets.length, 3, "test_getCreatorData::1");
        assertEq(creatorData.creatorMarketPendingFees.length, 3, "test_getCreatorData::2");
        assertEq(creatorData.creatorMarkets[0], market0w, "test_getCreatorData::3");
        assertEq(creatorData.creatorMarketPendingFees[0], 0, "test_getCreatorData::4");

        creatorData = lens.getCreatorData(address(0));
        assertEq(creatorData.creatorMarkets.length, 0, "test_getCreatorData::5");
        assertEq(creatorData.creatorMarketPendingFees.length, 0, "test_getCreatorData::6");
    }
}
