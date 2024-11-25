// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Ownable2StepUpgradeable} from "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";
import {IERC20Metadata, IERC20} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {TMMarket} from "./TMMarket.sol";
import {ITMFactory} from "./interfaces/ITMFactory.sol";
import {ITMBaseERC20} from "./interfaces/ITMBaseERC20.sol";
import {ImmutableCreate} from "./libraries/ImmutableCreate.sol";
import {ImmutableHelper} from "./libraries/ImmutableHelper.sol";
import {ITMMarket} from "./interfaces/ITMMarket.sol";
import {IWNative} from "./interfaces/IWNative.sol";
import {ITMStaking} from "./interfaces/ITMStaking.sol";

/**
 * @title TokenMill Factory Contract
 * @dev Factory contract for creating markets and tokens.
 */
contract TMFactory is Ownable2StepUpgradeable, ITMFactory {
    using EnumerableSet for EnumerableSet.AddressSet;
    using SafeERC20 for IERC20;

    uint256 private constant MAX_QUOTE_TOKENS = 64;
    uint16 private constant BPS = 1e4;

    address public immutable override STAKING;
    address public immutable override WNATIVE;

    address private _protocolFeeRecipient;
    uint16 private _defaultProtocolShare;
    uint16 private _referrerShare;

    mapping(address market => MarketParameters) private _parameters;
    mapping(address token => uint256 packedToken) private _tokens;

    mapping(address token0 => mapping(address token1 => uint256 packedMarket)) private _markets;
    address[] private _allMarkets;

    mapping(uint256 tokenType => address implementation) private _implementations;
    EnumerableSet.AddressSet private _quoteTokens;

    mapping(address creator => EnumerableSet.AddressSet markets) private _creatorMarkets;

    mapping(address token => Referrers referrers) private _referrers;

    receive() external payable {
        if (msg.sender != WNATIVE) revert TMFactory__OnlyWNative();
    }

    constructor(address staking, address wnative) {
        if (staking == address(0) || wnative == address(0)) revert TMFactory__AddressZero();

        _disableInitializers();

        STAKING = staking;
        WNATIVE = wnative;
    }

    /**
     * @dev Initializer for the TokenMill Factory contract.
     * @param protocolShare The protocol share percentage.
     * @param referrerShare The referrer share percentage.
     * @param protocolFeeRecipient The address of the protocol fee recipient.
     * @param initialOwner The address of the initial owner.
     */
    function initialize(uint16 protocolShare, uint16 referrerShare, address protocolFeeRecipient, address initialOwner)
        external
        initializer
    {
        __Ownable_init(initialOwner);

        _updateProtocolShare(protocolShare);
        _updateReferrerShare(referrerShare);
        _updateProtocolFeeRecipient(protocolFeeRecipient);
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
     * @dev Gets the fee shares of the specified market, which includes the protocol, and staking shares.
     * @param market The address of the market.
     * @return protocolShare The protocol share percentage.
     * @return creatorShare The creator share percentage.
     * @return stakingShare The staking share percentage.
     */
    function getFeeSharesOf(address market)
        external
        view
        override
        returns (uint256 protocolShare, uint256 creatorShare, uint256 stakingShare)
    {
        MarketParameters storage parameters = _parameters[market];

        return (parameters.protocolShare, parameters.creatorShare, parameters.stakingShare);
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
    function getDefaultProtocolShare() external view override returns (uint256) {
        return _defaultProtocolShare;
    }

    /**
     * @dev Gets the referrer share percentage. The referrer share percentage is the percentage of the protocol fees
     * that will be distributed to the referrer (if any).
     * @return The referrer share percentage.
     */
    function getReferrerShare() external view override returns (uint256) {
        return _referrerShare;
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
     * @dev Returns the referrer fees of the specified token.
     * @param token The address of the token.
     * @return The total referrer fees of the token.
     */
    function getReferrerFeesOf(address token, address referrer) external view override returns (uint256) {
        return _referrers[token].unclaimed[referrer];
    }

    /**
     * @dev Get the protocol fees of the specified token.
     * @param token The address of the token.
     * @return The total protocol fees of the token.
     */
    function getProtocolFees(address token) external view override returns (uint256) {
        uint256 balance = _balanceOf(token, address(this));
        uint256 totalReferrer = _referrers[token].total;

        unchecked {
            return balance > totalReferrer ? balance - totalReferrer : 0;
        }
    }

    /**
     * @dev Creates a new market and token.
     * @param parameters The market creation parameters.
     * @return baseToken The address of the base token.
     * @return market The address of the market.
     */
    function createMarketAndToken(MarketCreationParameters calldata parameters)
        public
        override
        returns (address baseToken, address market)
    {
        if (bytes(parameters.symbol).length == 0 || bytes(parameters.name).length == 0) {
            revert TMFactory__InvalidTokenParameters();
        }

        uint256[] memory packedPrices = ImmutableHelper.packPrices(parameters.bidPrices, parameters.askPrices);

        baseToken = _createToken(parameters);
        market = _createMarket(parameters, packedPrices, baseToken);

        return (baseToken, market);
    }

    /**
     * @dev Creates a new TM market and vesting schedules for the specified recipients.
     * Warning: If the token is a fee-on-transfer token, transferring tokens to the staking contract to vest them
     * should **not** result in any transfer fee, ie, that sending 10 tokens to the staking contract should
     * result in the staking contract receiving at least 10 tokens when vesting them with this function.
     * Note that the first vesting will receive all the fees from the swap.
     * @param params The parameters for the market creation.
     * @param vestingParams The parameters for the vesting schedules.
     * @param referrer The address of the referrer.
     * @param amountQuoteIn The amount of quote tokens to be swapped.
     * @param minAmountBaseOut The minimum amount of base tokens to be received.
     * @return baseToken The address of the base token.
     * @return market The address of the market.
     * @return amountBaseOut The amount of base tokens received.
     */
    function createMarketAndVestings(
        MarketCreationParameters calldata params,
        VestingParameters[] calldata vestingParams,
        address referrer,
        uint256 amountQuoteIn,
        uint256 minAmountBaseOut
    )
        external
        payable
        override
        returns (address baseToken, address market, uint256 amountBaseOut, uint256[] memory vestingIds)
    {
        if (amountQuoteIn == 0) revert TMFactory__ZeroAmount();

        uint256 length = vestingParams.length;
        if (length == 0) revert TMFactory__NoVestingParams();

        (baseToken, market) = createMarketAndToken(params);

        {
            address quoteToken = params.quoteToken;
            if (msg.value >= amountQuoteIn && quoteToken == WNATIVE) {
                IWNative(quoteToken).deposit{value: amountQuoteIn}();
                IERC20(quoteToken).safeTransfer(market, amountQuoteIn);
            } else {
                IERC20(quoteToken).safeTransferFrom(msg.sender, market, amountQuoteIn);
            }
        }

        {
            (int256 deltaBaseAmount, int256 deltaQuoteAmount) =
                ITMMarket(market).swap(address(this), int256(amountQuoteIn), false, new bytes(0), referrer);
            if (uint256(deltaQuoteAmount) != amountQuoteIn) revert TMFactory__TooManyQuoteTokenSent();
            amountBaseOut = uint256(-deltaBaseAmount);
        }

        if (amountBaseOut < minAmountBaseOut) revert TMFactory__InsufficientOutputAmount();

        IERC20(baseToken).forceApprove(STAKING, amountBaseOut);

        uint256 total = BPS;
        uint256 remainingBase = amountBaseOut;

        vestingIds = new uint256[](length);

        for (uint256 i; i < length; i++) {
            VestingParameters calldata vesting = vestingParams[i];

            uint256 percent = vesting.percent;
            if (percent > total) revert TMFactory__InvalidVestingPercents();

            uint256 amount = remainingBase * vesting.percent / total;

            unchecked {
                remainingBase -= amount;
                total -= percent;
            }

            vestingIds[i] = ITMStaking(STAKING).createVestingSchedule(
                baseToken,
                vesting.beneficiary,
                uint128(amount),
                uint128(amount),
                vesting.start,
                vesting.cliffDuration,
                vesting.endDuration
            );
        }

        if (total != 0) revert TMFactory__InvalidVestingTotalPercents();

        if (msg.value > 0) {
            uint256 leftOver = address(this).balance;
            if (leftOver > 0) {
                _transferNative(msg.sender, leftOver);
            }
        }
    }

    /**
     * @dev Updates the creator of the specified market.
     * @param market The address of the market.
     * @param creator The address of the creator.
     */
    function updateCreatorOf(address market, address creator) external override {
        if (creator == address(0)) revert TMFactory__AddressZero();

        MarketParameters storage parameters = _parameters[market];

        if (msg.sender != parameters.creator) revert TMFactory__InvalidCaller();

        _claimFees(market, msg.sender);
        _updateCreatorOf(parameters, market, creator);
    }

    /**
     * @dev Updates the fee shares of the specified market.
     * @param market The address of the market.
     * @param creatorShare The creator share percentage.
     * @param stakingShare The staking share percentage.
     */
    function updateFeeSharesOf(address market, uint16 creatorShare, uint16 stakingShare) external override {
        MarketParameters storage parameters = _parameters[market];

        if (msg.sender != parameters.creator) revert TMFactory__InvalidCaller();

        uint256 protocolShare = parameters.protocolShare;

        if (protocolShare + creatorShare + stakingShare != BPS) {
            revert TMFactory__InvalidFeeShares();
        }

        _claimFees(market, msg.sender);

        parameters.creatorShare = creatorShare;
        parameters.stakingShare = stakingShare;

        emit MarketFeeSharesUpdated(market, protocolShare, creatorShare, stakingShare);
    }

    /**
     * @dev Claims the fees of the specified market.
     * Only the creator of the market can claim the creator fees.
     * Only the staking contract can claim the staking fees.
     * @param market The address of the market.
     * @return claimedFees The total fees claimed.
     */
    function claimFees(address market) external override returns (uint256 claimedFees) {
        address creator = _parameters[market].creator;

        if (msg.sender != creator && msg.sender != STAKING) revert TMFactory__InvalidCaller();

        return _claimFees(market, creator);
    }

    /**
     * @dev Claims the referrer fees of the specified token.
     * @param token The address of the token.
     * @return claimedFees The total fees claimed.
     */
    function claimReferrerFees(address token) external override returns (uint256 claimedFees) {
        Referrers storage referrers = _referrers[token == address(0) ? WNATIVE : token];

        claimedFees = referrers.unclaimed[msg.sender];

        if (claimedFees > 0) {
            referrers.unclaimed[msg.sender] = 0;

            referrers.total -= claimedFees;

            emit ReferrerFeesClaimed(token, msg.sender, claimedFees);

            if (token == address(0)) {
                IWNative(WNATIVE).withdraw(claimedFees);
                _transferNative(msg.sender, claimedFees);
            } else {
                IERC20(token).safeTransfer(msg.sender, claimedFees);
            }
        }
    }

    /**
     * @dev Claims the protocol fees of the specified token.
     * @param token The address of the token.
     * @return claimedFees The total fees claimed.
     */
    function claimProtocolFees(address token) external override returns (uint256 claimedFees) {
        address protocolFeeRecipient = _protocolFeeRecipient;
        if (msg.sender != protocolFeeRecipient) revert TMFactory__InvalidCaller();

        Referrers storage referrers = _referrers[token];

        uint256 totalReferrer = referrers.total;
        uint256 balance = _balanceOf(token, address(this));

        if (balance > totalReferrer) {
            unchecked {
                claimedFees = balance - totalReferrer;
            }

            emit ProtocolFeesClaimed(token, protocolFeeRecipient, claimedFees);

            IERC20(token).safeTransfer(protocolFeeRecipient, claimedFees);
        }
    }

    /**
     * @dev Handles the fees of the specified token.
     * Must be called by a valid market contract.
     * @param token The address of the quote token.
     * @param referrer The address of the referrer.
     * @param totalProtocolFees The total protocol fees.
     * @return protocolFees The protocol fees (excluding the referrer fees).
     * @return referrerFees The referrer fees.
     */
    function handleProtocolFees(address token, address referrer, uint256 totalProtocolFees)
        external
        override
        returns (uint256 protocolFees, uint256 referrerFees)
    {
        MarketParameters storage parameters = _parameters[msg.sender];
        if (parameters.protocolShare + parameters.creatorShare + parameters.stakingShare != BPS) {
            revert TMFactory__InvalidCaller(); // A valid market must have the share percentages summing up to 100%.
        }

        if (referrer != address(0)) {
            if (referrer == STAKING) revert TMFactory__InvalidReferrer();

            referrerFees = (totalProtocolFees * _referrerShare) / BPS;
            protocolFees = totalProtocolFees - referrerFees;

            if (referrerFees > 0) {
                Referrers storage referrers = _referrers[token];

                referrers.total += referrerFees;
                unchecked {
                    referrers.unclaimed[referrer] += referrerFees;
                }
            }
        } else {
            protocolFees = totalProtocolFees;
        }

        emit FeesReceived(token, msg.sender, referrer, protocolFees, referrerFees);
    }

    /**
     * @dev Updates the protocol share percentage.
     * @param protocolShare The protocol share percentage.
     */
    function updateProtocolShare(uint16 protocolShare) external override onlyOwner {
        _updateProtocolShare(protocolShare);
    }

    /**
     * @dev Updates the referrer share percentage.
     * @param referrerShare The referrer share percentage.
     */
    function updateReferrerShare(uint16 referrerShare) external override onlyOwner {
        _updateReferrerShare(referrerShare);
    }

    /**
     * @dev Updates the protocol fee recipient.
     * @param protocolFeeRecipient The address of the protocol fee recipient.
     */
    function updateProtocolFeeRecipient(address protocolFeeRecipient) external override onlyOwner {
        _updateProtocolFeeRecipient(protocolFeeRecipient);
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
        return uint256((correctOrder << 160) | uint160(market));
    }

    /**
     * @dev Encodes the token with the specified token type.
     * @param tokenType The token type.
     * @param market The address of the market.
     * @return The encoded token.
     */
    function _encodeToken(uint96 tokenType, address market) private pure returns (uint256) {
        return uint256((uint256(tokenType) << 160) | uint160(market));
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
     * @dev Returns the balance of the specified token for the specified account.
     * @param token The address of the token.
     * @param account The address of the account.
     * @return The balance of the token for the account.
     */
    function _balanceOf(address token, address account) private view returns (uint256) {
        return IERC20(token).balanceOf(account);
    }

    /**
     * @dev Transfers `amount` of native tokens to `to`.
     * @param to The account to transfer the native tokens to.
     * @param amount The amount of native tokens to transfer.
     */
    function _transferNative(address to, uint256 amount) internal {
        (bool success,) = to.call{value: amount}(new bytes(0));
        if (!success) revert TMFactory__TransferFailed();
    }

    /**
     * @dev Claims the fees of the specified market.
     * @param market The address of the market.
     * @param creator The address of the creator.
     * @return claimedFees The total fees claimed.
     */
    function _claimFees(address market, address creator) internal returns (uint256 claimedFees) {
        return ITMMarket(market).claimFees(msg.sender, creator, STAKING);
    }

    /**
     * @dev Updates the protocol share percentage.
     * @param protocolShare The protocol share percentage.
     */
    function _updateProtocolShare(uint16 protocolShare) private {
        if (protocolShare > BPS) revert TMFactory__InvalidProtocolShare();

        _defaultProtocolShare = protocolShare;

        emit ProtocolSharesUpdated(protocolShare);
    }

    /**
     * @dev Updates the referrer share percentage.
     * @param referrerShare The referrer share percentage.
     */
    function _updateReferrerShare(uint16 referrerShare) private {
        if (referrerShare > BPS) revert TMFactory__InvalidReferrerShare();

        _referrerShare = referrerShare;

        emit ReferrerShareUpdated(referrerShare);
    }

    /**
     * @dev Updates the protocol fee recipient.
     * @param protocolFeeRecipient The address of the protocol fee recipient.
     */
    function _updateProtocolFeeRecipient(address protocolFeeRecipient) private {
        if (protocolFeeRecipient == address(0)) revert TMFactory__AddressZero();

        _protocolFeeRecipient = protocolFeeRecipient;

        emit ProtocolFeeRecipientUpdated(protocolFeeRecipient);
    }

    /**
     * @dev Creates a new token.
     * @param p The market creation parameters.
     * @return token The address of the token.
     */
    function _createToken(MarketCreationParameters calldata p) internal returns (address token) {
        address implementation = _implementations[p.tokenType];
        if (implementation == address(0)) revert TMFactory__InvalidTokenType();

        token = Clones.clone(implementation);

        ITMBaseERC20(token).initialize(p.name, p.symbol, p.args);
    }

    /**
     * @dev Creates a new market.
     * @param p The market creation parameters.
     * @param packedPrices The packed prices of the market.
     * @param baseToken The address of the base token.
     * @return market The address of the market.
     */
    function _createMarket(MarketCreationParameters calldata p, uint256[] memory packedPrices, address baseToken)
        internal
        returns (address market)
    {
        if (baseToken == p.quoteToken) revert TMFactory__SameTokens();
        if (!_quoteTokens.contains(p.quoteToken)) revert TMFactory__InvalidQuoteToken();

        uint16 protocolShare = _defaultProtocolShare;
        if (uint256(protocolShare) + p.creatorShare + p.stakingShare != BPS) {
            revert TMFactory__InvalidFeeShares();
        }

        bytes memory immutableArgs =
            ImmutableHelper.getImmutableArgs(address(this), baseToken, p.quoteToken, p.totalSupply, packedPrices);

        market = ImmutableCreate.create(type(TMMarket).runtimeCode, immutableArgs);

        emit MarketCreated(
            p.quoteToken,
            msg.sender,
            baseToken,
            market,
            p.totalSupply,
            p.name,
            p.symbol,
            IERC20Metadata(baseToken).decimals(),
            packedPrices
        );

        _allMarkets.push(market);
        _markets[baseToken][p.quoteToken] = _encodeMarket(1, market);
        _markets[p.quoteToken][baseToken] = _encodeMarket(0, market);
        _tokens[baseToken] = _encodeToken(p.tokenType, market);

        _parameters[market] = MarketParameters(protocolShare, p.creatorShare, p.stakingShare, msg.sender);
        _creatorMarkets[msg.sender].add(market);

        emit MarketFeeSharesUpdated(market, protocolShare, p.creatorShare, p.stakingShare);
        emit MarketCreatorUpdated(market, msg.sender);

        ITMMarket(market).initialize();
        ITMBaseERC20(baseToken).factoryMint(market, p.totalSupply);

        if (_balanceOf(baseToken, market) != p.totalSupply) revert TMFactory__InvalidBalance();
    }

    /**
     * @dev Updates the creator of the specified market.
     * @param parameters The market parameters.
     * @param market The address of the market.
     * @param creator The address of the creator.
     */
    function _updateCreatorOf(MarketParameters storage parameters, address market, address creator) internal {
        _creatorMarkets[msg.sender].remove(market);
        _creatorMarkets[creator].add(market);

        parameters.creator = creator;

        emit MarketCreatorUpdated(market, creator);
    }
}
