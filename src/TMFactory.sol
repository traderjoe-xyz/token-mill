// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import {TMMarket} from "./TMMarket.sol";
import {ITMFactory} from "./interfaces/ITMFactory.sol";
import {BasicERC20} from "./templates/BasicERC20.sol";
import {ImmutableCreate} from "./libraries/ImmutableCreate.sol";
import {Helper} from "./libraries/Helper.sol";
import {ITMMarket} from "./interfaces/ITMMarket.sol";

contract TMFactory is Ownable, ITMFactory {
    address private _protocolFeeRecipient;
    uint64 private _protocolShare;

    mapping(string symbol => address market) private _registry;
    mapping(address market => MarketParameters) private _parameters;
    mapping(address token0 => mapping(address token1 => address market)) private _markets;

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

    function getMarket(address tokenA, address tokenB) external view override returns (address) {
        (address token0, address token1) = _sortTokens(tokenA, tokenB);
        return _markets[token0][token1];
    }

    function getMarketBySymbol(string memory symbol) external view override returns (address) {
        return _registry[symbol];
    }

    function createMarket(
        string memory name,
        string memory symbol,
        address quoteToken,
        uint256 totalSupply,
        uint256[] memory bidPrices,
        uint256[] memory askPrices
    ) external override returns (address baseToken, address market) {
        if (_registry[symbol] != address(0)) revert TMFactory__SymbolAlreadyExists();

        baseToken = address(new BasicERC20(name, symbol));

        uint256[] memory packedPrices = Helper.packPrices(bidPrices, askPrices);
        bytes memory immutableArgs =
            Helper.getImmutableArgs(address(this), baseToken, quoteToken, totalSupply, packedPrices);

        market = ImmutableCreate.create2(type(TMMarket).runtimeCode, immutableArgs, 0);
        emit MarketCreated(quoteToken, msg.sender, baseToken, market, totalSupply, packedPrices);

        BasicERC20(baseToken).initialize(market, totalSupply);

        if (IERC20(baseToken).balanceOf(market) != totalSupply) revert Market__InvalidTotalSupply();

        uint64 protocolShare = _protocolShare;

        (address token0, address token1) = _sortTokens(baseToken, quoteToken);

        _registry[symbol] = market;
        _markets[token0][token1] = market;
        _parameters[market] = MarketParameters(protocolShare, msg.sender);

        emit MarketParametersUpdated(market, protocolShare, msg.sender);

        return (baseToken, market);
    }

    function updateCreator(address market, address creator) external override {
        MarketParameters storage parameters = _parameters[market];

        if (msg.sender != parameters.creator) revert Market__InvalidCaller();

        parameters.creator = creator;

        emit MarketParametersUpdated(market, parameters.protocolShare, creator);
    }

    function updateProtocolShare(uint64 protocolShare) external override onlyOwner {
        _updateProtocolShare(protocolShare);
    }

    function updateProtocolShareOf(address market, uint64 protocolShare) external override onlyOwner {
        MarketParameters storage parameters = _parameters[market];

        address protocolFeeRecipient = _protocolFeeRecipient;

        ITMMarket(market).claimFees(protocolFeeRecipient, protocolFeeRecipient);

        parameters.protocolShare = protocolShare;

        emit MarketParametersUpdated(market, protocolShare, parameters.creator);
    }

    function _sortTokens(address tokenA, address tokenB) private pure returns (address, address) {
        return tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
    }

    function _updateProtocolShare(uint64 protocolShare) private {
        _protocolShare = protocolShare;

        emit ProtocolShareUpdated(protocolShare);
    }
}
