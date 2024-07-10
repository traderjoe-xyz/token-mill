// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {ITMFactory} from "./interfaces/ITMFactory.sol";
import {ITMMarket} from "./interfaces/ITMMarket.sol";

contract TokenMillLens {

    struct MarketAddresses {
        address market;
        address quoteToken;
        address baseToken;
    }

    struct AggregateMarketMetadata {
        uint256 numberOfMarkets;
        address[] whitelistedQuoteTokens;
        MarketAddresses[] allMarketAddresses;
    }

    struct IndividualMarketMetadata {
        bool marketExists;
        address quoteToken;
        address baseToken;
        uint256 baseTokenType;
        uint256 quoteTokenDecimals;
        uint256 baseTokenDecimals;
        string quoteTokenName;
        string baseTokenName;
        string quoteTokenSymbol;	
        string baseTokenSymbol;
        address marketCreator;
        uint256 protocolShare;
        uint256 totalSupply;
        uint256 circulatingSupply;
        uint256 spotPriceFillBid;
        uint256 spotPriceFillAsk;
        uint256[] askPrices;
        uint256[] bidPrices;
        uint256 protocolPendingFees;
        uint256 creatorPendingFees;
    }

    struct UserMetadata {
        address[] userMarkets;
        uint256[] userMarketPendingFees;
    }

    ITMFactory private _TMFactory;

    constructor(ITMFactory TMFactory) {
        _TMFactory = TMFactory;
    }

    function getAllMarketMetadata(
        uint256 start,
        uint256 offset
    ) external view returns (AggregateMarketMetadata memory aggregateMarketMetadata) {
        uint256 numberOfMarkets = _TMFactory.getMarketsLength();

        offset = start >= numberOfMarkets ? 0 : (start + offset > numberOfMarkets ? numberOfMarkets - start : offset);

        MarketAddresses[] memory marketAddresses = new MarketAddresses[](offset);

        for (uint256 i; i < offset; i++) {
            address market = _TMFactory.getMarketAt(start+i);

            marketAddresses[i] = MarketAddresses({
                market: market,
                quoteToken: ITMMarket(market).getQuoteToken(),
                baseToken: ITMMarket(market).getBaseToken()
            });
        }

        aggregateMarketMetadata = AggregateMarketMetadata({
            numberOfMarkets: numberOfMarkets,
            whitelistedQuoteTokens: _TMFactory.getQuoteTokens(),
            allMarketAddresses: marketAddresses
        });
    }

    function getMultipleMarketMetadata(
        address[] calldata marketAddresses
    ) external view returns (IndividualMarketMetadata[] memory individualMarketsMetadata) {
        uint256 length = marketAddresses.length;
        individualMarketsMetadata = new IndividualMarketMetadata[](length);

        for (uint256 i; i < length; i++) {
            individualMarketsMetadata[i] = getSingleMarketMetadata(marketAddresses[i]);
        }
    }

    function getSingleMarketMetadata(
        address marketAddress
    ) public view returns (IndividualMarketMetadata memory individualMarketMetadata) {
        ITMMarket market = ITMMarket(marketAddress);

        try market.getBaseToken() returns (address baseToken) {
            if (marketAddress == _TMFactory.getMarketOf(baseToken)) {
                address quoteToken = market.getQuoteToken();
                uint256 circulatingSupply = market.getCirculatingSupply();
                (uint256 protocolFees, uint256 creatorFees) = market.getPendingFees();

                individualMarketMetadata = IndividualMarketMetadata({
                    marketExists: true,
                    quoteToken: quoteToken,
                    baseToken: baseToken,
                    baseTokenType: _TMFactory.getTokenType(baseToken),
                    quoteTokenDecimals: IERC20Metadata(quoteToken).decimals(),
                    baseTokenDecimals: IERC20Metadata(baseToken).decimals(),
                    quoteTokenName: IERC20Metadata(quoteToken).name(),
                    baseTokenName: IERC20Metadata(baseToken).name(),
                    quoteTokenSymbol: IERC20Metadata(quoteToken).symbol(),
                    baseTokenSymbol: IERC20Metadata(baseToken).symbol(),
                    marketCreator: _TMFactory.getCreatorOf(marketAddress),
                    protocolShare: _TMFactory.getProtocolShareOf(marketAddress),
                    totalSupply: market.getTotalSupply(),
                    circulatingSupply: circulatingSupply,
                    spotPriceFillBid: market.getPriceAt(circulatingSupply, false),
                    spotPriceFillAsk: market.getPriceAt(circulatingSupply, true),
                    askPrices: market.getPricePoints(true),
                    bidPrices: market.getPricePoints(false),
                    protocolPendingFees: protocolFees,
                    creatorPendingFees: creatorFees
                });
            }
        } catch {}
    }

    function getUserMetadata(
        address userAddress
    ) external view returns (UserMetadata memory userMetadata) {
        uint256 creatorMarketsLength = _TMFactory.getCreatorMarketsLength(userAddress);
        
        address[] memory userMarkets = new address[](creatorMarketsLength);
        uint256[] memory userMarketPendingFees = new uint256[](creatorMarketsLength);

        for (uint256 i; i < creatorMarketsLength; i++) {
            address marketAddress = _TMFactory.getCreatorMarketAt(userAddress, i);
            (,uint256 creatorFees) = ITMMarket(marketAddress).getPendingFees();
            
            userMarkets[i] = marketAddress;
            userMarketPendingFees[i] = creatorFees;
        }

        userMetadata = UserMetadata({
            userMarkets: userMarkets,
            userMarketPendingFees: userMarketPendingFees
        });
    }

}