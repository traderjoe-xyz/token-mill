// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface ITMFactory {
    error TMFactory__SymbolAlreadyExists();
    error TMFactory__InvalidTotalSupply();
    error TMFactory__InvalidCaller();
    error TMFactory__InvalidQuoteToken();
    error TMFactory__InvalidProtocolShare();
    error TMFactory__QuoteTokenAlreadyAdded();
    error TMFactory__QuoteTokenNotFound();
    error TMFactory__InvalidTokenType();

    // packedPrices = `(askPrice << 128) | bidPrice` for each price point
    event MarketCreated(
        address indexed quoteToken,
        address indexed creator,
        address baseToken,
        address market,
        uint256 totalSupply,
        uint256[] packedPrices
    );
    event MarketParametersUpdated(address indexed market, uint64 protocolShare, address creator);
    event ProtocolShareUpdated(uint64 protocolShare);
    event TokenImplementationUpdated(TokenType tokenType, address implementation);
    event QuoteTokenAdded(address quoteToken);
    event QuoteTokenRemoved(address quoteToken);

    struct MarketParameters {
        uint64 protocolShare;
        address creator;
    }

    enum TokenType {
        Invalid,
        BasicERC20
    }

    function getCreatorOf(address market) external view returns (address);

    function getProtocolShareOf(address market) external view returns (uint256);

    function getProtocolShare() external view returns (uint256);

    function getProtocolFeeRecipient() external view returns (address);

    function getMarket(address tokenA, address tokenB) external view returns (address);

    function getMarketBySymbol(string memory symbol) external view returns (address);

    function getMarketsLength() external view returns (uint256);

    function getMarketAt(uint256 index) external view returns (address);

    function getQuoteTokens() external view returns (address[] memory);

    function isQuoteToken(address quoteToken) external view returns (bool);

    function getImplementation(TokenType tokenType) external view returns (address);

    function createMarketAndToken(
        TokenType tokenType,
        string memory name,
        string memory symbol,
        address quoteToken,
        uint256 totalSupply,
        uint256[] memory bidPrices,
        uint256[] memory askPrices
    ) external returns (address baseToken, address market);

    function updateCreator(address market, address creator) external;

    function updateProtocolShare(uint64 protocolShare) external;

    function updateProtocolShareOf(address market, uint64 protocolShare) external;

    function updateTokenImplementation(TokenType tokenType, address implementation) external;

    function addQuoteToken(address quoteToken) external;

    function removeQuoteToken(address quoteToken) external;
}
