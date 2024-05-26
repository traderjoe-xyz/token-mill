// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";
import {IERC20Metadata, IERC20} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {TMMarket} from "./TMMarket.sol";
import {ITMFactory} from "./interfaces/ITMFactory.sol";
import {BasicERC20} from "./templates/BasicERC20.sol";
import {ImmutableCreate} from "./libraries/ImmutableCreate.sol";
import {Helper} from "./libraries/Helper.sol";
import {ITMMarket} from "./interfaces/ITMMarket.sol";

contract TMFactory is Ownable, ITMFactory {
    using EnumerableSet for EnumerableSet.AddressSet;

    address private _protocolFeeRecipient;
    uint64 private _protocolShare;

    mapping(address market => MarketParameters) private _parameters;

    mapping(address token0 => mapping(address token1 => uint256 packedMarket)) private _markets;
    address[] private _allMarkets;

    mapping(TokenType => address implementation) private _implementations;
    EnumerableSet.AddressSet private _quoteTokens;

    constructor(uint64 protocolShare, address initialOwner) Ownable(initialOwner) {
        _updateProtocolShare(protocolShare);
    }

    function getCreatorOf(address market) external view override returns (address) {
        return _parameters[market].creator;
    }

    function getProtocolShareOf(address market) external view override returns (uint256) {
        return _parameters[market].protocolShare;
    }

    function getProtocolShare() external view override returns (uint256) {
        return _protocolShare;
    }

    function getProtocolFeeRecipient() external view override returns (address) {
        return _protocolFeeRecipient;
    }

    function getMarket(address tokenA, address tokenB) external view override returns (bool, address) {
        uint256 encodedMarket = _markets[tokenA][tokenB];

        return _decodeMarket(encodedMarket);
    }

    function getMarketsLength() external view override returns (uint256) {
        return _allMarkets.length;
    }

    function getMarketAt(uint256 index) external view override returns (address) {
        return _allMarkets[index];
    }

    function getQuoteTokens() external view override returns (address[] memory) {
        return _quoteTokens.values();
    }

    function isQuoteToken(address quoteToken) external view override returns (bool) {
        return _quoteTokens.contains(quoteToken);
    }

    function getImplementation(TokenType tokenType) external view override returns (address) {
        return _implementations[tokenType];
    }

    function createMarketAndToken(
        TokenType tokenType,
        string memory name,
        string memory symbol,
        address quoteToken,
        uint256 totalSupply,
        uint256[] memory bidPrices,
        uint256[] memory askPrices
    ) external override returns (address baseToken, address market) {
        baseToken = _createToken(tokenType, keccak256(bytes(symbol)));
        market = _createMarket(name, symbol, baseToken, quoteToken, totalSupply, bidPrices, askPrices);

        return (baseToken, market);
    }

    function _createToken(TokenType tokenType, bytes32 salt) internal returns (address token) {
        address implementation = _implementations[tokenType];
        if (implementation == address(0)) revert TMFactory__InvalidTokenType();

        token = Clones.cloneDeterministic(implementation, salt, 0);

        return token;
    }

    function _createMarket(
        string memory name,
        string memory symbol,
        address baseToken,
        address quoteToken,
        uint256 totalSupply,
        uint256[] memory bidPrices,
        uint256[] memory askPrices
    ) internal returns (address market) {
        if (!_quoteTokens.contains(quoteToken)) revert TMFactory__InvalidQuoteToken();

        uint256[] memory packedPrices = Helper.packPrices(bidPrices, askPrices);
        bytes memory immutableArgs =
            Helper.getImmutableArgs(address(this), baseToken, quoteToken, totalSupply, packedPrices);

        market = ImmutableCreate.create2(type(TMMarket).runtimeCode, immutableArgs, 0);
        ITMMarket(market).initialize();

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
        _parameters[market] = MarketParameters(protocolShare, msg.sender);

        emit MarketParametersUpdated(market, protocolShare, msg.sender);

        BasicERC20(baseToken).initialize(name, symbol, market, totalSupply);

        if (IERC20(baseToken).balanceOf(market) != totalSupply) revert TMFactory__InvalidTotalSupply();
    }

    function updateCreator(address market, address creator) external override {
        MarketParameters storage parameters = _parameters[market];

        if (msg.sender != parameters.creator) revert TMFactory__InvalidCaller();

        parameters.creator = creator;

        emit MarketParametersUpdated(market, parameters.protocolShare, creator);
    }

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

    function updateProtocolShare(uint64 protocolShare) external override onlyOwner {
        _updateProtocolShare(protocolShare);
    }

    function updateProtocolFeeRecipient(address protocolFeeRecipient) external override onlyOwner {
        _protocolFeeRecipient = protocolFeeRecipient;

        emit ProtocolFeeRecipientUpdated(protocolFeeRecipient);
    }

    function updateProtocolShareOf(address market, uint64 protocolShare) external override onlyOwner {
        MarketParameters storage parameters = _parameters[market];

        ITMMarket(market).claimFees(address(0), address(0), false, false);

        parameters.protocolShare = protocolShare;

        emit MarketParametersUpdated(market, protocolShare, parameters.creator);
    }

    function updateTokenImplementation(TokenType tokenType, address implementation) external override onlyOwner {
        if (tokenType == TokenType.Invalid) revert TMFactory__InvalidTokenType();

        _implementations[tokenType] = implementation;

        emit TokenImplementationUpdated(tokenType, implementation);
    }

    function addQuoteToken(address quoteToken) external override onlyOwner {
        if (!_quoteTokens.add(quoteToken)) revert TMFactory__QuoteTokenAlreadyAdded();

        emit QuoteTokenAdded(quoteToken);
    }

    function removeQuoteToken(address quoteToken) external override onlyOwner {
        if (!_quoteTokens.remove(quoteToken)) revert TMFactory__QuoteTokenNotFound();

        emit QuoteTokenRemoved(quoteToken);
    }

    function _encodeMarket(uint256 correctOrder, address market) private pure returns (uint256) {
        return uint256(uint160(market) | correctOrder << 160);
    }

    function _decodeMarket(uint256 encodedMarket) private pure returns (bool correctOrder, address market) {
        correctOrder = (encodedMarket >> 160) == 1;
        market = address(uint160(encodedMarket));
    }

    function _updateProtocolShare(uint64 protocolShare) private {
        if (protocolShare > 1e18) revert TMFactory__InvalidProtocolShare();

        _protocolShare = protocolShare;

        emit ProtocolShareUpdated(protocolShare);
    }
}
