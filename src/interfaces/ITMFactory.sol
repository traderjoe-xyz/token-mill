// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface ITMFactory {
    error TMFactory__SymbolAlreadyExists();
    error Market__InvalidTotalSupply();
    error Market__InvalidCaller();

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

    struct MarketParameters {
        uint64 protocolShare;
        address creator;
    }

    function getCreatorOf(address market) external view returns (address);

    function getProtocolShareOf(address market) external view returns (uint256);

    function getProtocolShare() external view returns (uint256);

    function getProtocolFeeRecipient() external view returns (address);

    function getMarket(address tokenA, address tokenB) external view returns (address);

    function getMarketBySymbol(string memory symbol) external view returns (address);

    function createMarket(
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
}
