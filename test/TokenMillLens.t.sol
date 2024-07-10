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

    function test_getAllMarketMetadata() public {
        TokenMillLens.AggregateMarketMetadata memory aggregateMarketMetadata = tokenMillLens.getAllMarketMetadata(0,10);

        assertEq(aggregateMarketMetadata.numberOfMarkets, 3);
        assertEq(aggregateMarketMetadata.whitelistedQuoteTokens.length, 3);
        assertEq(aggregateMarketMetadata.whitelistedQuoteTokens[0], address(wnative));
        
        TokenMillLens.MarketAddresses memory marketAddresses = aggregateMarketMetadata.allMarketAddresses[0];
        assertEq(marketAddresses.market, market0w);
        assertEq(marketAddresses.quoteToken, address(wnative));
        assertEq(marketAddresses.baseToken, address(token0));
        
        aggregateMarketMetadata = tokenMillLens.getAllMarketMetadata(2,1);
        marketAddresses = aggregateMarketMetadata.allMarketAddresses[0];
        assertEq(marketAddresses.market, market21);
        assertEq(marketAddresses.quoteToken, token1);
        assertEq(marketAddresses.baseToken, token2);
    }

    function test_getSingleMarketMetadata() public {
        EmptyContract ec = new EmptyContract();
        TokenMillLens.IndividualMarketMetadata memory individualMarketMetadata = 
            tokenMillLens.getSingleMarketMetadata(address(ec));
        assertEq(individualMarketMetadata.marketExists, false);

        vm.expectRevert();
        individualMarketMetadata = tokenMillLens.getSingleMarketMetadata(address(0));

        individualMarketMetadata = tokenMillLens.getSingleMarketMetadata(market0w);
        assertEq(individualMarketMetadata.marketExists, true);
        assertEq(individualMarketMetadata.quoteToken, address(wnative));
        assertEq(individualMarketMetadata.baseToken, token0);
        assertEq(individualMarketMetadata.baseTokenType, 1);
        assertEq(individualMarketMetadata.quoteTokenDecimals, 18);
        assertEq(individualMarketMetadata.baseTokenDecimals, 18);
        assertEq(individualMarketMetadata.quoteTokenName, "Wrapped Native");
        assertEq(individualMarketMetadata.baseTokenName, "Token0");
        assertEq(individualMarketMetadata.quoteTokenSymbol, "WNATIVE");
        assertEq(individualMarketMetadata.baseTokenSymbol, "T0");
        assertEq(individualMarketMetadata.marketCreator, address(this));
        assertEq(individualMarketMetadata.protocolShare, 1e17);
        assertEq(individualMarketMetadata.totalSupply, 500_000_000e18);
        assertEq(individualMarketMetadata.circulatingSupply, 0);
        assertEq(individualMarketMetadata.spotPriceFillBid, 0);
        assertEq(individualMarketMetadata.spotPriceFillAsk, 0);
        assertEq(individualMarketMetadata.askPrices, askPrices0w);
        assertEq(individualMarketMetadata.bidPrices, bidPrices0w);
        assertEq(individualMarketMetadata.protocolPendingFees, 0);
        assertEq(individualMarketMetadata.creatorPendingFees, 0);
    }

    function test_getMultipleMarketMetadata() public {
        address[] memory marketAddresses = new address[](2);
        marketAddresses[0] = market0w;
        marketAddresses[1] = market21;

        TokenMillLens.IndividualMarketMetadata[] memory individualMarketsMetadata = 
            tokenMillLens.getMultipleMarketMetadata(marketAddresses);
        assertEq(individualMarketsMetadata.length, 2);

        uint256[] memory askPrices = new uint256[](3);
        askPrices[0] = 10e18;
        askPrices[1] = 20e18;
        askPrices[2] = 21e18;

        uint256[] memory bidPrices = new uint256[](3);
        bidPrices[0] = 1e18;
        bidPrices[1] = 10e18;
        bidPrices[2] = 20e18;        

        assertEq(individualMarketsMetadata[1].marketExists, true);
        assertEq(individualMarketsMetadata[1].quoteToken, token1);
        assertEq(individualMarketsMetadata[1].baseToken, token2);
        assertEq(individualMarketsMetadata[1].baseTokenType, 1);
        assertEq(individualMarketsMetadata[1].quoteTokenDecimals, 18);
        assertEq(individualMarketsMetadata[1].baseTokenDecimals, 18);
        assertEq(individualMarketsMetadata[1].quoteTokenName, "Token1");
        assertEq(individualMarketsMetadata[1].baseTokenName, "Token2");
        assertEq(individualMarketsMetadata[1].quoteTokenSymbol, "T1");
        assertEq(individualMarketsMetadata[1].baseTokenSymbol, "T2");
        assertEq(individualMarketsMetadata[1].marketCreator, address(this));
        assertEq(individualMarketsMetadata[1].protocolShare, 1e17);
        assertEq(individualMarketsMetadata[1].totalSupply, 50_000_000e18);
        assertEq(individualMarketsMetadata[1].circulatingSupply, 0);
        assertEq(individualMarketsMetadata[1].spotPriceFillBid, bidPrices[0]);
        assertEq(individualMarketsMetadata[1].spotPriceFillAsk, askPrices[0]);
        assertEq(individualMarketsMetadata[1].askPrices, askPrices);
        assertEq(individualMarketsMetadata[1].bidPrices, bidPrices);
        assertEq(individualMarketsMetadata[1].protocolPendingFees, 0);
        assertEq(individualMarketsMetadata[1].creatorPendingFees, 0);
    }

    function test_getUserMetadata() public {
        TokenMillLens.UserMetadata memory userMetadata = tokenMillLens.getUserMetadata(address(this));

        assertEq(userMetadata.userMarkets.length, 3);
        assertEq(userMetadata.userMarketPendingFees.length, 3);
        assertEq(userMetadata.userMarkets[0], market0w);
        assertEq(userMetadata.userMarketPendingFees[0], 0);

        userMetadata = tokenMillLens.getUserMetadata(address(0));
        assertEq(userMetadata.userMarkets.length, 0);
        assertEq(userMetadata.userMarketPendingFees.length, 0);
    }

}