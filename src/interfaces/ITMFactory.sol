// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title TMFactory Interface
 * @dev Interface of the factory contract.
 */
interface ITMFactory {
    error TMFactory__InvalidBalance();
    error TMFactory__InvalidCaller();
    error TMFactory__InvalidQuoteToken();
    error TMFactory__InvalidFeeShares();
    error TMFactory__QuoteTokenAlreadyAdded();
    error TMFactory__QuoteTokenNotFound();
    error TMFactory__MaxQuoteTokensExceeded();
    error TMFactory__InvalidTokenType();
    error TMFactory__InvalidRecipient();
    error TMFactory__InvalidProtocolShare();
    error TMFactory__AddressZero();
    error TMFactory__ZeroAmount();
    error TMFactory__SameTokens();
    error TMFactory__ZeroFeeRecipients();
    error TMFactory__InvalidReferrerShare();
    error TMFactory__InvalidReferrer();
    error TMFactory__TransferFailed();
    error TMFactory__NoVestingParams();
    error TMFactory__InvalidVestingPercents();
    error TMFactory__InvalidVestingTotalPercents();
    error TMFactory__TooManyQuoteTokenSent();
    error TMFactory__InsufficientOutputAmount();
    error TMFactory__BalanceOfFailed();
    error TMFactory__InvalidTokenParameters();
    error TMFactory__OnlyWNative();

    // packedPrices = `(askPrice << 128) | bidPrice` for each price point
    event MarketCreated(
        address indexed quoteToken,
        address indexed creator,
        address indexed baseToken,
        address market,
        uint256 totalSupply,
        string name,
        string symbol,
        uint8 decimals,
        uint256[] packedPrices
    );
    event MarketFeeSharesUpdated(
        address indexed market, uint256 protocolShare, uint256 creatorShare, uint256 stakingShare
    );
    event ProtocolSharesUpdated(uint256 protocolShare);
    event MarketCreatorUpdated(address indexed market, address indexed creator);
    event TokenImplementationUpdated(uint96 tokenType, address implementation);
    event QuoteTokenAdded(address quoteToken);
    event QuoteTokenRemoved(address quoteToken);
    event ProtocolFeeRecipientUpdated(address recipient);
    event ReferrerShareUpdated(uint256 referrerShare);
    event FeesReceived(
        address indexed token,
        address indexed market,
        address indexed referrer,
        uint256 protocolFees,
        uint256 referrerFees
    );
    event ReferrerFeesClaimed(address indexed token, address indexed referrer, uint256 claimedFees);
    event ProtocolFeesClaimed(address indexed token, address indexed referrer, uint256 claimedFees);

    struct Referrers {
        uint256 total;
        mapping(address => uint256) unclaimed;
    }

    struct MarketParameters {
        uint16 protocolShare;
        uint16 creatorShare;
        uint16 stakingShare;
        address creator;
    }

    struct MarketCreationParameters {
        uint96 tokenType;
        string name;
        string symbol;
        address quoteToken;
        uint256 totalSupply;
        uint16 creatorShare;
        uint16 stakingShare;
        uint256[] bidPrices;
        uint256[] askPrices;
        bytes args;
    }

    struct VestingParameters {
        address beneficiary;
        uint256 percent;
        uint80 start;
        uint80 cliffDuration;
        uint80 endDuration;
    }

    function STAKING() external view returns (address);

    function WNATIVE() external view returns (address);

    function getCreatorOf(address market) external view returns (address);

    function getCreatorMarketsLength(address creator) external view returns (uint256);

    function getCreatorMarketAt(address creator, uint256 index) external view returns (address);

    function getFeeSharesOf(address market) external view returns (uint256, uint256, uint256);

    function getTokenType(address token) external view returns (uint256);

    function getMarketOf(address token) external view returns (address);

    function getDefaultProtocolShare() external view returns (uint256);

    function getProtocolFeeRecipient() external view returns (address);

    function getReferrerShare() external view returns (uint256);

    function getMarket(address tokenA, address tokenB) external view returns (bool tokenAisBase, address market);

    function getMarketsLength() external view returns (uint256);

    function getMarketAt(uint256 index) external view returns (address);

    function getQuoteTokens() external view returns (address[] memory);

    function isQuoteToken(address quoteToken) external view returns (bool);

    function getTokenImplementation(uint96 tokenType) external view returns (address);

    function getReferrerFeesOf(address token, address referrer) external view returns (uint256);

    function getProtocolFees(address token) external view returns (uint256);

    function createMarketAndToken(MarketCreationParameters calldata parameters)
        external
        returns (address baseToken, address market);

    function createMarketAndVestings(
        MarketCreationParameters calldata params,
        VestingParameters[] calldata vestingParams,
        address referrer,
        uint256 amountQuoteIn,
        uint256 minAmountBaseOut
    )
        external
        payable
        returns (address baseToken, address market, uint256 amountBaseOut, uint256[] memory vestingIds);

    function updateCreatorOf(address market, address creator) external;

    function updateFeeSharesOf(address market, uint16 creatorShare, uint16 stakingShare) external;

    function claimFees(address market) external returns (uint256 claimedFees);

    function claimReferrerFees(address token) external returns (uint256 claimedFees);

    function claimProtocolFees(address token) external returns (uint256 claimedFees);

    function handleProtocolFees(address token, address referrer, uint256 totalProtocolFees)
        external
        returns (uint256 protocolFees, uint256 referrerFees);

    function updateProtocolShare(uint16 protocolShare) external;

    function updateReferrerShare(uint16 referrerShare) external;

    function updateProtocolFeeRecipient(address recipient) external;

    function updateTokenImplementation(uint96 tokenType, address implementation) external;

    function addQuoteToken(address quoteToken) external;

    function removeQuoteToken(address quoteToken) external;
}
