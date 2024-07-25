// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./TestHelper.sol";
import "../src/TokenMillLens.sol";

contract EmptyContract {}

contract TestTokenMillLens is TestHelper {

    TokenMillLens tokenMillLens;

    function setUp() public override {
        super.setUp();
        setUpTokens();

        tokenMillLens = new TokenMillLens(ITMFactory(address(factory)));
    }    

    function test_getAggregateMarketData() public {
        TokenMillLens.AggregateMarketData memory aggregateMarketData = tokenMillLens.getAggregateMarketData(0,10);

        assertEq(aggregateMarketData.whitelistedQuoteTokens.length, 3);
        assertEq(aggregateMarketData.whitelistedQuoteTokens[0], address(wnative));
        
        TokenMillLens.MarketData memory marketData = aggregateMarketData.allMarketData[0];
        assertEq(marketData.market, market0w);
        assertEq(marketData.quoteToken, address(wnative));
        assertEq(marketData.baseToken, address(token0));
        
        aggregateMarketData = tokenMillLens.getAggregateMarketData(2,1);
        marketData = aggregateMarketData.allMarketData[0];
        assertEq(marketData.market, market21);
        assertEq(marketData.quoteToken, token1);
        assertEq(marketData.baseToken, token2);
    }

    function test_getSingleDetailedMarketData() public {
        EmptyContract ec = new EmptyContract();
        TokenMillLens.DetailedMarketData memory detailedMarketData = 
            tokenMillLens.getSingleDetailedMarketData(address(ec));
        assertEq(detailedMarketData.marketExists, false);

        detailedMarketData = tokenMillLens.getSingleDetailedMarketData(address(0));
        assertEq(detailedMarketData.marketExists, false);

        detailedMarketData = tokenMillLens.getSingleDetailedMarketData(market0w);
        assertEq(detailedMarketData.marketExists, true);
        assertEq(detailedMarketData.quoteToken, address(wnative));
        assertEq(detailedMarketData.baseToken, token0);
        assertEq(detailedMarketData.baseTokenType, 1);
        assertEq(detailedMarketData.quoteTokenDecimals, 18);
        assertEq(detailedMarketData.baseTokenDecimals, 18);
        assertEq(detailedMarketData.quoteTokenName, "Wrapped Native");
        assertEq(detailedMarketData.baseTokenName, "Token0");
        assertEq(detailedMarketData.quoteTokenSymbol, "WNATIVE");
        assertEq(detailedMarketData.baseTokenSymbol, "T0");
        assertEq(detailedMarketData.marketCreator, address(this));
        assertEq(detailedMarketData.protocolShare, 1e17);
        assertEq(detailedMarketData.totalSupply, 500_000_000e18);
        assertEq(detailedMarketData.circulatingSupply, 0);
        assertEq(detailedMarketData.spotPriceFillBid, 0);
        assertEq(detailedMarketData.spotPriceFillAsk, 0);
        assertEq(detailedMarketData.askPrices, askPrices0w);
        assertEq(detailedMarketData.bidPrices, bidPrices0w);
        assertEq(detailedMarketData.protocolPendingFees, 0);
        assertEq(detailedMarketData.creatorPendingFees, 0);
    }

    function test_getMultipleDetailedMarketData() public {
        address[] memory marketAddresses = new address[](2);
        marketAddresses[0] = market0w;
        marketAddresses[1] = market21;

        TokenMillLens.DetailedMarketData[] memory detailedMarketsData = 
            tokenMillLens.getMultipleDetailedMarketData(marketAddresses);
        assertEq(detailedMarketsData.length, 2);

        uint256[] memory askPrices = new uint256[](3);
        askPrices[0] = 10e18;
        askPrices[1] = 20e18;
        askPrices[2] = 21e18;

        uint256[] memory bidPrices = new uint256[](3);
        bidPrices[0] = 1e18;
        bidPrices[1] = 10e18;
        bidPrices[2] = 20e18;        

        assertEq(detailedMarketsData[1].marketExists, true);
        assertEq(detailedMarketsData[1].quoteToken, token1);
        assertEq(detailedMarketsData[1].baseToken, token2);
        assertEq(detailedMarketsData[1].baseTokenType, 1);
        assertEq(detailedMarketsData[1].quoteTokenDecimals, 18);
        assertEq(detailedMarketsData[1].baseTokenDecimals, 18);
        assertEq(detailedMarketsData[1].quoteTokenName, "Token1");
        assertEq(detailedMarketsData[1].baseTokenName, "Token2");
        assertEq(detailedMarketsData[1].quoteTokenSymbol, "T1");
        assertEq(detailedMarketsData[1].baseTokenSymbol, "T2");
        assertEq(detailedMarketsData[1].marketCreator, address(this));
        assertEq(detailedMarketsData[1].protocolShare, 1e17);
        assertEq(detailedMarketsData[1].totalSupply, 50_000_000e18);
        assertEq(detailedMarketsData[1].circulatingSupply, 0);
        assertEq(detailedMarketsData[1].spotPriceFillBid, bidPrices[0]);
        assertEq(detailedMarketsData[1].spotPriceFillAsk, askPrices[0]);
        assertEq(detailedMarketsData[1].askPrices, askPrices);
        assertEq(detailedMarketsData[1].bidPrices, bidPrices);
        assertEq(detailedMarketsData[1].protocolPendingFees, 0);
        assertEq(detailedMarketsData[1].creatorPendingFees, 0);
    }

    function test_getCreatorData() public {
        TokenMillLens.CreatorData memory creatorData = tokenMillLens.getCreatorData(address(this));

        assertEq(creatorData.userMarkets.length, 3);
        assertEq(creatorData.userMarketPendingFees.length, 3);
        assertEq(creatorData.userMarkets[0], market0w);
        assertEq(creatorData.userMarketPendingFees[0], 0);

        creatorData = tokenMillLens.getCreatorData(address(0));
        assertEq(creatorData.userMarkets.length, 0);
        assertEq(creatorData.userMarketPendingFees.length, 0);
    }

}