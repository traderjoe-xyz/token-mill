// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Ownable2StepUpgradeable} from "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";
import {IERC20Metadata, IERC20} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {TMMarket} from "./TMMarket.sol";
import {ITMFactory} from "./interfaces/ITMFactory.sol";
import {ITMBaseERC20} from "./interfaces/ITMBaseERC20.sol";
import {ImmutableCreate} from "./libraries/ImmutableCreate.sol";
import {ImmutableHelper} from "./libraries/ImmutableHelper.sol";
import {ITMMarket} from "./interfaces/ITMMarket.sol";

/**
 * @title TokenMill Factory Contract
 * @dev Factory contract for creating markets and tokens.
 */
contract TMFactory is Ownable2StepUpgradeable, ITMFactory {
    using EnumerableSet for EnumerableSet.AddressSet;

    uint256 private constant MAX_QUOTE_TOKENS = 64;
    uint64 private constant MAX_PROTOCOL_SHARE = 1e18;

    address private _protocolFeeRecipient;
    uint64 private _protocolShare;

    mapping(address market => MarketParameters) private _parameters;
    mapping(address token => uint256 packedToken) private _tokens;

    mapping(address token0 => mapping(address token1 => uint256 packedMarket)) private _markets;
    address[] private _allMarkets;

    mapping(uint256 tokenType => address implementation) private _implementations;
    EnumerableSet.AddressSet private _quoteTokens;

    mapping(address => EnumerableSet.AddressSet) private _creatorMarkets;

    constructor() {
        _disableInitializers();
    }

    /**
     * @dev Initializer for the TokenMill Factory contract.
     * @param protocolShare The protocol share percentage.
     * @param initialOwner The initial owner of the contract.
     */
    function initialize(uint64 protocolShare, address initialOwner) external initializer {
        __Ownable_init(initialOwner);

        _updateProtocolShare(protocolShare);
    }

    /**
     * @dev Gets the creator of the specified market.
     * @param market The address of the market.
     * @return The address of the creator of the market.
     */
    function getCreatorOf(address market) external view override returns (address) {
        return _parameters[market].creator;
    }

    /**
     * @dev Returns the number of markets created by the specified creator.
     * @param creator The address of the creator.
     * @return The number of markets created by the creator.
     */
    function getCreatorMarketsLength(address creator) external view override returns (uint256) {
        return _creatorMarkets[creator].length();
    }

    /**
     * @dev Returns the market at the specified index created by the specified creator.
     * @param creator The address of the creator.
     * @param index The index of the market.
     * @return The address of the market created by the creator at the specified index.
     */
    function getCreatorMarketAt(address creator, uint256 index) external view override returns (address) {
        return _creatorMarkets[creator].at(index);
    }

    /**
     * @dev Gets the protocol share of the specified market.
     * @param market The address of the market.
     * @return The protocol share of the market.
     */
    function getProtocolShareOf(address market) external view override returns (uint256) {
        return _parameters[market].protocolShare;
    }

    /**
     * @dev Gets the token type of the specified token.
     * @param token The address of the token.
     * @return The token type of the token.
     */
    function getTokenType(address token) external view override returns (uint256) {
        (uint96 tokenType,) = _decodeToken(_tokens[token]);
        return tokenType;
    }

    /**
     * @dev Gets the market of the specified token.
     * @param token The address of the token.
     * @return The address of the market of the token.
     */
    function getMarketOf(address token) external view override returns (address) {
        (, address market) = _decodeToken(_tokens[token]);
        return market;
    }

    /**
     * @dev Gets the protocol share percentage.
     * @return The protocol share percentage.
     */
    function getProtocolShare() external view override returns (uint256) {
        return _protocolShare;
    }

    /**
     * @dev Gets the protocol fee recipient.
     * @return The address of the protocol fee recipient.
     */
    function getProtocolFeeRecipient() external view override returns (address) {
        return _protocolFeeRecipient;
    }

    /**
     * @dev Gets the market of the specified tokens.
     * @param tokenA The address of the first token.
     * @param tokenB The address of the second token.
     * @return A boolean indicating if the first token is the base token
     * @return The address of the market of the tokens.
     */
    function getMarket(address tokenA, address tokenB) external view override returns (bool, address) {
        uint256 encodedMarket = _markets[tokenA][tokenB];

        return _decodeMarket(encodedMarket);
    }

    /**
     * @dev Gets the number of markets.
     * @return The number of markets.
     */
    function getMarketsLength() external view override returns (uint256) {
        return _allMarkets.length;
    }

    /**
     * @dev Gets the market at the specified index.
     * @param index The index of the market.
     * @return The address of the market at the specified index.
     */
    function getMarketAt(uint256 index) external view override returns (address) {
        return _allMarkets[index];
    }

    /**
     * @dev Gets the quote tokens.
     * @return An array of quote tokens.
     */
    function getQuoteTokens() external view override returns (address[] memory) {
        return _quoteTokens.values();
    }

    /**
     * @dev Checks if the specified token is a quote token.
     * @param quoteToken The address of the token.
     * @return A boolean indicating if the token is a quote token.
     */
    function isQuoteToken(address quoteToken) external view override returns (bool) {
        return _quoteTokens.contains(quoteToken);
    }

    /**
     * @dev Gets the token implementation of the specified token type.
     * @param tokenType The token type.
     * @return The address of the token implementation.
     */
    function getTokenImplementation(uint96 tokenType) external view override returns (address) {
        return _implementations[tokenType];
    }

    /**
     * @dev Creates a new market and token.
     * @param tokenType The token type.
     * @param name The name of the token.
     * @param symbol The symbol of the token.
     * @param quoteToken The address of the quote token.
     * @param totalSupply The total supply of the token.
     * @param bidPrices The bid prices of the market.
     * @param askPrices The ask prices of the market.
     * @param args The additional arguments to be passed to the token.
     * @return baseToken The address of the base token.
     * @return market The address of the market.
     */
    function createMarketAndToken(
        uint96 tokenType,
        string memory name,
        string memory symbol,
        address quoteToken,
        uint256 totalSupply,
        uint256[] memory bidPrices,
        uint256[] memory askPrices,
        bytes memory args
    ) external override returns (address baseToken, address market) {
        baseToken = _createToken(tokenType, name, symbol, args);

        uint256[] memory packedPrices = ImmutableHelper.packPrices(bidPrices, askPrices);
        market = _createMarket(tokenType, name, symbol, baseToken, quoteToken, totalSupply, packedPrices);

        return (baseToken, market);
    }

    /**
     * @dev Updates the creator of the specified market.
     * @param market The address of the market.
     * @param creator The address of the creator.
     */
    function updateCreator(address market, address creator) external override {
        MarketParameters storage parameters = _parameters[market];

        if (msg.sender != parameters.creator) revert TMFactory__InvalidCaller();

        _creatorMarkets[msg.sender].remove(market);
        _creatorMarkets[creator].add(market);

        parameters.creator = creator;

        emit MarketParametersUpdated(market, parameters.protocolShare, creator);
    }

    /**
     * @dev Claims the fees of the specified market.
     * @param market The address of the market.
     * @param recipient The address of the recipient.
     * @return fees The amount of fees claimed.
     */
    function claimFees(address market, address recipient) external override returns (uint256 fees) {
        if (recipient == address(0)) revert TMFactory__InvalidRecipient();

        MarketParameters storage parameters = _parameters[market];

        address creator = parameters.creator;
        address protocolFeeRecipient = _protocolFeeRecipient;

        bool isCreator = msg.sender == creator;
        bool isProtocol = msg.sender == protocolFeeRecipient;

        if (!isCreator && !isProtocol) revert TMFactory__InvalidCaller();

        fees = ITMMarket(market).claimFees(msg.sender, recipient, isCreator, isProtocol);
    }

    /**
     * @dev Updates the protocol share percentage.
     * @param protocolShare The protocol share percentage.
     */
    function updateProtocolShare(uint64 protocolShare) external override onlyOwner {
        _updateProtocolShare(protocolShare);
    }

    /**
     * @dev Updates the protocol fee recipient.
     * @param protocolFeeRecipient The address of the protocol fee recipient.
     */
    function updateProtocolFeeRecipient(address protocolFeeRecipient) external override onlyOwner {
        _protocolFeeRecipient = protocolFeeRecipient;

        emit ProtocolFeeRecipientUpdated(protocolFeeRecipient);
    }

    /**
     * @dev Updates the protocol share of the specified market.
     * @param market The address of the market.
     * @param protocolShare The protocol share percentage.
     */
    function updateProtocolShareOf(address market, uint64 protocolShare) external override onlyOwner {
        if (protocolShare > MAX_PROTOCOL_SHARE) revert TMFactory__InvalidProtocolShare();

        MarketParameters storage parameters = _parameters[market];

        ITMMarket(market).claimFees(address(0), address(0), false, false);

        parameters.protocolShare = protocolShare;

        emit MarketParametersUpdated(market, protocolShare, parameters.creator);
    }

    /**
     * @dev Updates the token implementation of the specified token type.
     * @param tokenType The token type.
     * @param implementation The address of the token implementation.
     */
    function updateTokenImplementation(uint96 tokenType, address implementation) external override onlyOwner {
        if (tokenType == 0) revert TMFactory__InvalidTokenType();

        _implementations[tokenType] = implementation;

        emit TokenImplementationUpdated(tokenType, implementation);
    }

    /**
     * @dev Adds the specified quote token.
     * @param quoteToken The address of the quote token.
     */
    function addQuoteToken(address quoteToken) external override onlyOwner {
        if (!_quoteTokens.add(quoteToken)) revert TMFactory__QuoteTokenAlreadyAdded();
        if (_quoteTokens.length() > MAX_QUOTE_TOKENS) revert TMFactory__MaxQuoteTokensExceeded();

        emit QuoteTokenAdded(quoteToken);
    }

    /**
     * @dev Removes the specified quote token.
     * @param quoteToken The address of the quote token.
     */
    function removeQuoteToken(address quoteToken) external override onlyOwner {
        if (!_quoteTokens.remove(quoteToken)) revert TMFactory__QuoteTokenNotFound();

        emit QuoteTokenRemoved(quoteToken);
    }

    /**
     * @dev Encodes the market with the specified correct order.
     * @param correctOrder A boolean indicating if the order is correct.
     * @param market The address of the market.
     * @return The encoded market.
     */
    function _encodeMarket(uint256 correctOrder, address market) private pure returns (uint256) {
        return uint256(uint160(market) | correctOrder << 160);
    }

    /**
     * @dev Encodes the token with the specified token type.
     * @param tokenType The token type.
     * @param market The address of the market.
     * @return The encoded token.
     */
    function _encodeToken(uint96 tokenType, address market) private pure returns (uint256) {
        return uint256(uint160(market) | uint256(tokenType) << 160);
    }

    /**
     * @dev Decodes the market with the specified encoded market.
     * @param encodedMarket The encoded market.
     * @return correctOrder A boolean indicating if the order is correct.
     * @return market The address of the market.
     */
    function _decodeMarket(uint256 encodedMarket) private pure returns (bool correctOrder, address market) {
        correctOrder = (encodedMarket >> 160) == 1;
        market = address(uint160(encodedMarket));
    }

    /**
     * @dev Decodes the token with the specified encoded token.
     * @param encodedToken The encoded token.
     * @return tokenType The token type.
     * @return market The address of the market.
     */
    function _decodeToken(uint256 encodedToken) private pure returns (uint96 tokenType, address market) {
        tokenType = uint96(encodedToken >> 160);
        market = address(uint160(encodedToken));
    }

    /**
     * @dev Updates the protocol share percentage.
     * @param protocolShare The protocol share percentage.
     */
    function _updateProtocolShare(uint64 protocolShare) private {
        if (protocolShare > MAX_PROTOCOL_SHARE) revert TMFactory__InvalidProtocolShare();

        _protocolShare = protocolShare;

        emit ProtocolShareUpdated(protocolShare);
    }

    /**
     * @dev Creates a new token.
     * @param tokenType The token type.
     * @param name The name of the token.
     * @param symbol The symbol of the token.
     * @param args The additional arguments to be passed to the token.
     * @return token The address of the token.
     */
    function _createToken(uint96 tokenType, string memory name, string memory symbol, bytes memory args)
        internal
        returns (address token)
    {
        address implementation = _implementations[tokenType];
        if (implementation == address(0)) revert TMFactory__InvalidTokenType();

        token = Clones.clone(implementation);

        ITMBaseERC20(token).initialize(name, symbol, args);
    }

    /**
     * @dev Creates a new market.
     * @param tokenType The token type.
     * @param name The name of the market.
     * @param symbol The symbol of the market.
     * @param baseToken The address of the base token.
     * @param quoteToken The address of the quote token.
     * @param totalSupply The total supply of the market.
     * @param packedPrices The packed prices of the market.
     * @return market The address of the market.
     */
    function _createMarket(
        uint96 tokenType,
        string memory name,
        string memory symbol,
        address baseToken,
        address quoteToken,
        uint256 totalSupply,
        uint256[] memory packedPrices
    ) internal returns (address market) {
        if (baseToken == quoteToken) revert TMFactory__SameTokens();
        if (!_quoteTokens.contains(quoteToken)) revert TMFactory__InvalidQuoteToken();

        bytes memory immutableArgs =
            ImmutableHelper.getImmutableArgs(address(this), baseToken, quoteToken, totalSupply, packedPrices);

        market = ImmutableCreate.create(type(TMMarket).runtimeCode, immutableArgs);

        emit MarketCreated(
            quoteToken,
            msg.sender,
            baseToken,
            market,
            totalSupply,
            name,
            symbol,
            IERC20Metadata(baseToken).decimals(),
            packedPrices
        );

        uint64 protocolShare = _protocolShare;

        _allMarkets.push(market);
        _markets[baseToken][quoteToken] = _encodeMarket(1, market);
        _markets[quoteToken][baseToken] = _encodeMarket(0, market);
        _tokens[baseToken] = _encodeToken(tokenType, market);
        _parameters[market] = MarketParameters(protocolShare, msg.sender);
        _creatorMarkets[msg.sender].add(market);

        emit MarketParametersUpdated(market, protocolShare, msg.sender);

        ITMMarket(market).initialize();
        ITMBaseERC20(baseToken).factoryMint(market, totalSupply);

        if (IERC20(baseToken).balanceOf(market) != totalSupply) revert TMFactory__InvalidBalance();
    }
}
