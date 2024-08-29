// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {ITMFactory} from "./interfaces/ITMFactory.sol";
import {ITMMarket} from "./interfaces/ITMMarket.sol";

/**
 * @title Token Mill Lens
 * @dev Contains logic for gathering aggregate data on markets deployed from the Token Mill
 * factory contract, along with detailed data on individual markets, and creator data about
 * associated markets and pending fees.
 */
contract TMLens {
    struct MarketData {
        address market;
        address quoteToken;
        address baseToken;
    }

    struct AggregateMarketData {
        address[] whitelistedQuoteTokens;
        MarketData[] allMarketData;
    }

    struct DetailedMarketData {
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

    struct CreatorData {
        address[] creatorMarkets;
        uint256[] creatorMarketPendingFees;
    }

    ITMFactory private _TMFactory;

    constructor(ITMFactory TMFactory) {
        _TMFactory = TMFactory;
    }

    /**
     * @dev Returns high level data about markets launched from the TMFactory contract, for a specified chunk.
     * @param start Starting index of markets in TMFactory _allMarkets array to gather data for.
     * @param offset Number of markets to gather data for, starting from `start`.
     * @return aggregateMarketData Struct containing aggregate market data.
     */
    function getAggregateMarketData(uint256 start, uint256 offset)
        external
        view
        returns (AggregateMarketData memory aggregateMarketData)
    {
        uint256 numberOfMarkets = _TMFactory.getMarketsLength();

        offset = start >= numberOfMarkets ? 0 : (start + offset > numberOfMarkets ? numberOfMarkets - start : offset);

        MarketData[] memory marketData = new MarketData[](offset);

        for (uint256 i; i < offset; i++) {
            address market = _TMFactory.getMarketAt(start + i);

            marketData[i] = MarketData({
                market: market,
                quoteToken: ITMMarket(market).getQuoteToken(),
                baseToken: ITMMarket(market).getBaseToken()
            });
        }

        aggregateMarketData =
            AggregateMarketData({whitelistedQuoteTokens: _TMFactory.getQuoteTokens(), allMarketData: marketData});
    }

    /**
     * @dev Returns detailed data about every market in a provided array.
     * @param marketAddresses Array of market addresses to gather data for.
     * @return detailedMarketData Array of structs, each containing detailed market data.
     */
    function getMultipleDetailedMarketData(address[] calldata marketAddresses)
        external
        view
        returns (DetailedMarketData[] memory detailedMarketData)
    {
        uint256 length = marketAddresses.length;
        detailedMarketData = new DetailedMarketData[](length);

        for (uint256 i; i < length; i++) {
            detailedMarketData[i] = getSingleDetailedMarketData(marketAddresses[i]);
        }
    }

    /**
     * @dev Returns information for a given user about the markets they are a creator for.
     * @param creatorAddress Address of the creator to gather data for.
     * @return creatorData Struct containing data on the markets a user is a creator for.
     */
    function getCreatorData(address creatorAddress) external view returns (CreatorData memory creatorData) {
        uint256 creatorMarketsLength = _TMFactory.getCreatorMarketsLength(creatorAddress);

        address[] memory creatorMarkets = new address[](creatorMarketsLength);
        uint256[] memory creatorMarketPendingFees = new uint256[](creatorMarketsLength);

        for (uint256 i; i < creatorMarketsLength; i++) {
            address marketAddress = _TMFactory.getCreatorMarketAt(creatorAddress, i);
            (, uint256 creatorFees) = ITMMarket(marketAddress).getPendingFees();

            creatorMarkets[i] = marketAddress;
            creatorMarketPendingFees[i] = creatorFees;
        }

        creatorData = CreatorData({creatorMarkets: creatorMarkets, creatorMarketPendingFees: creatorMarketPendingFees});
    }

    /**
     * @dev Returns detailed data about a single market.
     * @param marketAddress Address of the market to gather data for.
     * @return detailedMarketData Struct containing detailed data about a market.
     */
    function getSingleDetailedMarketData(address marketAddress)
        public
        view
        returns (DetailedMarketData memory detailedMarketData)
    {
        if (marketAddress.code.length != 0) {
            ITMMarket market = ITMMarket(marketAddress);

            try market.getBaseToken() returns (address baseToken) {
                if (marketAddress == _TMFactory.getMarketOf(baseToken)) {
                    address quoteToken = market.getQuoteToken();
                    uint256 circulatingSupply = market.getCirculatingSupply();
                    (uint256 protocolFees, uint256 creatorFees) = market.getPendingFees();

                    detailedMarketData = DetailedMarketData({
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
                        spotPriceFillBid: market.getPriceAt(circulatingSupply, true),
                        spotPriceFillAsk: market.getPriceAt(circulatingSupply, false),
                        askPrices: market.getPricePoints(true),
                        bidPrices: market.getPricePoints(false),
                        protocolPendingFees: protocolFees,
                        creatorPendingFees: creatorFees
                    });
                }
            } catch {}
        }
    }
}
