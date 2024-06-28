// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {PricePoints} from "./libraries/PricePoints.sol";
import {Math} from "./libraries/Math.sol";
import {ImmutableContract} from "./libraries/ImmutableContract.sol";
import {ITokenMillCallback} from "./interfaces/ITokenMillCallback.sol";
import {ITMFactory} from "./interfaces/ITMFactory.sol";
import {ITMMarket} from "./interfaces/ITMMarket.sol";

/**
 * @title Token Mill Market
 * @dev The token mill market contract.
 */
contract TMMarket is PricePoints, ImmutableContract, ITMMarket {
    using SafeERC20 for IERC20;

    bool internal _locked;
    uint128 internal _baseReserve;
    uint256 internal _quoteReserve;

    uint256 internal _protocolUnclaimedFees;
    uint256 internal _creatorUnclaimedFees;

    /**
     * @dev Modifier to prevent reentrancy.
     */
    modifier nonReentrant() {
        if (_locked) revert TMMarket__ReentrantCall();
        _locked = true;
        _;
        _locked = false;
    }

    /**
     * @dev Initializes the contract.
     */
    function initialize() external override {
        if (msg.sender != _factory()) revert TMMarket__OnlyFactory();

        _baseReserve = uint128(_totalSupply());
    }

    /**
     * @dev Returns the base token address.
     * @return The base token address.
     */
    function getBaseToken() external pure override returns (address) {
        return _baseToken();
    }

    /**
     * @dev Returns the quote token address.
     * @return The quote token address.
     */
    function getQuoteToken() external pure override returns (address) {
        return _quoteToken();
    }

    /**
     * @dev Returns the circulating supply.
     * @return The circulating supply.
     */
    function getCirculatingSupply() external view override returns (uint256) {
        return _totalSupply() - _baseReserve;
    }

    /**
     * @dev Returns the total supply.
     * @return The total supply.
     */
    function getTotalSupply() external pure override returns (uint256) {
        return _totalSupply();
    }

    /**
     * @dev Returns the price at the specified circulating supply.
     * @param circulatingSupply The circulating supply.
     * @param fillBid Whether to fill the bid or ask.
     * @return The price.
     */
    function getPriceAt(uint256 circulatingSupply, bool fillBid) external pure override returns (uint256) {
        uint256 totalSupply = _totalSupply();

        if (circulatingSupply >= totalSupply) return _pricePoints(_pricePointsLength() - 1, fillBid);

        circulatingSupply = circulatingSupply * 1e18 / _basePrecision();
        uint256 widthScaled = _widthScaled();

        uint256 i = circulatingSupply / widthScaled;
        uint256 supply = circulatingSupply % widthScaled;

        uint256 p0 = _pricePoints(i, fillBid);
        uint256 p1 = _pricePoints(i + 1, fillBid);

        return p0 + (p1 - p0) * supply / widthScaled;
    }

    /**
     * @dev Returns the price points.
     * @param fillBid Whether to return the bid or ask price points.
     * @return The price points.
     */
    function getPricePoints(bool fillBid) external pure override returns (uint256[] memory) {
        uint256 length = _pricePointsLength();

        uint256[] memory prices = new uint256[](length);

        for (uint256 i; i < length; ++i) {
            prices[i] = _pricePoints(i, fillBid);
        }

        return prices;
    }

    /**
     * @dev Returns the pending fees.
     * @return protocolFees The protocol fees.
     * @return creatorFees The creator fees.
     */
    function getPendingFees() external view override returns (uint256 protocolFees, uint256 creatorFees) {
        (, uint256 pendingProtocolFees, uint256 pendingCreatorFees) = _getPendingFees(ITMFactory(_factory()));

        return (pendingProtocolFees, pendingCreatorFees);
    }

    /**
     * @dev Returns the delta amounts.
     * @param deltaAmount The delta amount.
     * @param fillBid Whether to fill the bid or ask.
     * @return deltaBaseAmount The delta base amount.
     * @return deltaQuoteAmount The delta quote amount.
     */
    function getDeltaAmounts(int256 deltaAmount, bool fillBid)
        external
        view
        override
        returns (int256 deltaBaseAmount, int256 deltaQuoteAmount)
    {
        uint256 circulatingSupply = _totalSupply() - _baseReserve;

        return (deltaAmount > 0) == fillBid
            ? getDeltaQuoteAmount(circulatingSupply, deltaAmount)
            : getDeltaBaseAmount(circulatingSupply, deltaAmount);
    }

    /**
     * @dev Swap tokens.
     * TOKEN/USD -> TOKEN is base, USD is quote
     * fillBid = true  + dAmount > 0 (true)  -> in: dAmount Base,  out:       -X Quote
     * fillBid = true  + dAmount < 0 (false) -> in:       X Base,  out: -dAmount Quote
     * fillBid = false + dAmount > 0 (true)  -> in: dAmount Quote, out:       -X Base
     * fillBid = false + dAmount < 0 (false) -> in:       X Quote, out: -dAmount Base
     * @param recipient The recipient of the tokens.
     * @param deltaAmount The delta amount.
     * @param fillBid Whether to fill the bid or ask.
     * @param data The data to be passed to the swap callback. If the data is empty, the callback will be skipped.
     * @return deltaBaseAmount The delta base amount.
     * @return deltaQuoteAmount The delta quote amount.
     */
    function swap(address recipient, int256 deltaAmount, bool fillBid, bytes calldata data)
        external
        override
        nonReentrant
        returns (int256 deltaBaseAmount, int256 deltaQuoteAmount)
    {
        if (recipient == address(0)) revert TMMarket__InvalidRecipient();
        if (deltaAmount == 0) revert TMMarket__ZeroAmount();

        (uint256 baseReserve, uint256 quoteReserve) = _getReserves();
        uint256 circulatingSupply = _totalSupply() - baseReserve;

        (deltaBaseAmount, deltaQuoteAmount) = (deltaAmount > 0) == fillBid
            ? getDeltaQuoteAmount(circulatingSupply, deltaAmount)
            : getDeltaBaseAmount(circulatingSupply, deltaAmount);

        (uint256 toSend, uint256 toReceive, IERC20 tokenToSend, IERC20 tokenToReceive) = fillBid
            ? (Math.abs(deltaQuoteAmount), Math.abs(deltaBaseAmount), IERC20(_quoteToken()), IERC20(_baseToken()))
            : (Math.abs(deltaBaseAmount), Math.abs(deltaQuoteAmount), IERC20(_baseToken()), IERC20(_quoteToken()));

        if (toSend > 0) IERC20(tokenToSend).safeTransfer(recipient, toSend);
        if (
            data.length > 0
                && ITokenMillCallback(msg.sender).tokenMillSwapCallback(deltaBaseAmount, deltaQuoteAmount, data)
                    != ITokenMillCallback.tokenMillSwapCallback.selector
        ) {
            revert TMMarket__InvalidSwapCallback();
        }

        uint256 balance = tokenToReceive.balanceOf(address(this));
        if (balance > type(uint128).max) revert TMMarket__ReserveOverflow();

        fillBid
            ? _updateReservesOnFillBid(baseReserve, quoteReserve, toSend, toReceive, balance)
            : _updateReservesOnFillAsk(baseReserve, quoteReserve, toSend, toReceive, balance);

        emit Swap(msg.sender, recipient, deltaBaseAmount, deltaQuoteAmount);
    }

    /**
     * @dev Claims the fees.
     * @param caller The caller of the function.
     * @param recipient The recipient of the fees.
     * @param isCreator Whether to claim the creator fees.
     * @param isProtocol Whether to claim the protocol fees.
     * @return fees The fees claimed.
     */
    function claimFees(address caller, address recipient, bool isCreator, bool isProtocol)
        external
        override
        nonReentrant
        returns (uint256 fees)
    {
        ITMFactory factory = ITMFactory(_factory());

        if (msg.sender != address(factory)) revert TMMarket__OnlyFactory();

        (uint256 quoteReserve, uint256 pendingProtocolFees, uint256 pendingCreatorFees) = _getPendingFees(factory);

        if (isProtocol) {
            fees = pendingProtocolFees;

            pendingProtocolFees = 0;
            _protocolUnclaimedFees = 0;
        }

        if (isCreator) {
            fees += pendingCreatorFees;

            pendingCreatorFees = 0;
            _creatorUnclaimedFees = 0;
        }

        if (pendingProtocolFees > 0) _protocolUnclaimedFees = pendingProtocolFees;
        if (pendingCreatorFees > 0) _creatorUnclaimedFees = pendingCreatorFees;

        if (fees > 0) {
            _quoteReserve = quoteReserve - fees;

            IERC20(_quoteToken()).safeTransfer(recipient, fees);

            emit FeesClaimed(caller, recipient, fees);
        }
    }

    /**
     * @dev Returns the pending fees.
     * @param factory The factory contract.
     * @return The quote reserve, protocol unclaimed fees, and creator unclaimed fees.
     */
    function _getPendingFees(ITMFactory factory) internal view returns (uint256, uint256, uint256) {
        uint256 protocolUnclaimedFees = _protocolUnclaimedFees;
        uint256 creatorUnclaimedFees = _creatorUnclaimedFees;

        uint256 quoteReserve = _quoteReserve;
        (, uint256 minQuoteAmount) = _getQuoteAmount(0, _totalSupply() - _baseReserve, false);

        if (quoteReserve > minQuoteAmount) {
            uint256 totalUnclaimedFees = protocolUnclaimedFees + creatorUnclaimedFees;
            uint256 totalFees = quoteReserve - minQuoteAmount;

            if (totalFees > totalUnclaimedFees) {
                uint256 fees = totalFees - totalUnclaimedFees;

                uint256 protocolShare = factory.getProtocolShareOf(address(this));
                uint256 protocolFees = fees * protocolShare / 1e18;

                protocolUnclaimedFees += protocolFees;
                creatorUnclaimedFees += fees - protocolFees;
            }
        }

        return (quoteReserve, protocolUnclaimedFees, creatorUnclaimedFees);
    }

    /**
     * @dev Returns the reserves.
     * @return The base and quote reserves.
     */
    function _getReserves() internal view returns (uint256, uint256) {
        return (_baseReserve, _quoteReserve);
    }

    /**
     * @dev Updates the reserves on a bid fill.
     * @param baseReserve The base reserve.
     * @param quoteReserve The quote reserve.
     * @param toSend The amount to send.
     * @param toReceive The amount to receive.
     * @param baseBalance The base balance.
     */
    function _updateReservesOnFillBid(
        uint256 baseReserve,
        uint256 quoteReserve,
        uint256 toSend,
        uint256 toReceive,
        uint256 baseBalance
    ) internal {
        if (baseReserve + toReceive > baseBalance) revert TMMarket__InsufficientAmount();

        _baseReserve = uint128(baseBalance);
        _quoteReserve = quoteReserve - toSend;
    }

    /**
     * @dev Updates the reserves on an ask fill.
     * @param baseReserve The base reserve.
     * @param quoteReserve The quote reserve.
     * @param toSend The amount to send.
     * @param toReceive The amount to receive.
     * @param quoteBalance The quote balance.
     */
    function _updateReservesOnFillAsk(
        uint256 baseReserve,
        uint256 quoteReserve,
        uint256 toSend,
        uint256 toReceive,
        uint256 quoteBalance
    ) internal {
        if (quoteReserve + toReceive > quoteBalance) revert TMMarket__InsufficientAmount();

        _baseReserve = uint128(baseReserve - toSend);
        _quoteReserve = quoteBalance;
    }

    /**
     * The immutable args are as follows:
     * [0; 19] - Factory contract address
     * [20; 39] - Base token address
     * [40; 59] - Quote token address
     * [60; 67] - Base precision
     * [68; 75] - Quote precision
     * [76; 91] - Total supply
     * [92; 107] - Width scaled
     * [108; 109] - Price points length
     * [110; 125] - askPrices[0]
     * [126; 141] - bidPrices[0]
     * [142; 157] - askPrices[1]
     * [158; 173] - bidPrices[1]
     * ...
     * [110+32*n; 125+32*n] - askPrices[n]
     * [126+32*n; 141+32*n] - bidPrices[n]
     */

    /**
     * @dev Returns the factory contract using the immutable arguments.
     * @return The factory contract.
     */
    function _factory() internal pure returns (address) {
        return _getAddress(0);
    }

    /**
     * @dev Returns the base token address using the immutable arguments.
     * @return The base token address.
     */
    function _baseToken() internal pure returns (address) {
        return _getAddress(20);
    }

    /**
     * @dev Returns the quote token address using the immutable arguments.
     * @return The quote token address.
     */
    function _quoteToken() internal pure returns (address) {
        return _getAddress(40);
    }

    /**
     * @dev Returns the base precision using the immutable arguments.
     * @return The base precision.
     */
    function _basePrecision() internal pure override returns (uint256) {
        return _getUint(60, 64);
    }

    /**
     * @dev Returns the quote precision using the immutable arguments.
     * @return The quote precision.
     */
    function _quotePrecision() internal pure override returns (uint256) {
        return _getUint(68, 64);
    }

    /**
     * @dev Returns the total supply using the immutable arguments.
     * @return The total supply.
     */
    function _totalSupply() internal pure override returns (uint256) {
        return _getUint(76, 128);
    }

    /**
     * @dev Returns the width scaled using the immutable arguments.
     * @return The width scaled.
     */
    function _widthScaled() internal pure override returns (uint256) {
        return _getUint(92, 128);
    }

    /**
     * @dev Returns the price points length using the immutable arguments.
     * @return The price points length.
     */
    function _pricePointsLength() internal pure override returns (uint256) {
        return _getUint(108, 16);
    }

    /**
     * @dev Returns the price points using the immutable arguments.
     * This function doesn't check that the index is within bounds. It should be done by the parent function.
     * @param i The index of the price point.
     * @param fillBid Whether to fill the bid or ask.
     * @return The price point.
     */
    function _pricePoints(uint256 i, bool fillBid) internal pure override returns (uint256) {
        return _getUint((fillBid ? 110 : 126) + i * 32, 128);
    }
}
