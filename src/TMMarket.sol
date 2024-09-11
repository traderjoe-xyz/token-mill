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
 * The view functions might return an outdated value if they're called in the middle of a swap or a fee claim.
 */
contract TMMarket is PricePoints, ImmutableContract, ITMMarket {
    using SafeERC20 for IERC20;

    uint256 private constant PRECISION = 1e18;

    bool internal _locked;
    uint120 internal _initialized;
    uint128 internal _baseReserve;

    uint128 internal _quoteReserve;
    uint128 internal _totalReferrerFees;

    uint128 internal _creatorUnclaimedFees;
    uint128 internal _stakingUnclaimedFees;

    mapping(address => uint256) internal _referrerFees;

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
        if (_initialized != 0) revert TMMarket__AlreadyInitialized();

        _initialized = 1;
        _baseReserve = uint128(_totalSupply());
    }

    /**
     * @dev Returns the factory address.
     * @return The factory address.
     */
    function getFactory() external pure override returns (address) {
        return _factory();
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
     * @dev Returns the reserves. The quote reserve includes the pending fees.
     * @return baseReserve The base reserve.
     * @return quoteReserve The quote reserve (including the pending fees).
     */
    function getReserves() external view override returns (uint256 baseReserve, uint256 quoteReserve) {
        return _getReserves();
    }

    /**
     * @dev Returns the price at the specified circulating supply.
     * @param circulatingSupply The circulating supply.
     * @param swapB2Q Whether to swap base to quote (true) or quote to base (false).
     * @return The price.
     */
    function getPriceAt(uint256 circulatingSupply, bool swapB2Q) external pure override returns (uint256) {
        uint256 totalSupply = _totalSupply();

        bool askPrice = !swapB2Q;

        if (circulatingSupply >= totalSupply) {
            if (circulatingSupply > totalSupply) revert TMMarket__InvalidCirculatingSupply();
            return _pricePoints(_pricePointsLength() - 1, askPrice);
        }

        circulatingSupply = circulatingSupply * PRECISION / _basePrecision();
        uint256 widthScaled = _widthScaled();

        uint256 i = circulatingSupply / widthScaled;
        uint256 supply = circulatingSupply % widthScaled;

        uint256 p0 = _pricePoints(i, askPrice);
        uint256 p1 = _pricePoints(i + 1, askPrice);

        return p0 + Math.div((p1 - p0) * supply, widthScaled, askPrice);
    }

    /**
     * @dev Returns the price points.
     * @param swapB2Q Whether to swap base to quote (true) or quote to base (false).
     * @return The price points.
     */
    function getPricePoints(bool swapB2Q) external pure override returns (uint256[] memory) {
        uint256 length = _pricePointsLength();

        uint256[] memory prices = new uint256[](length);

        for (uint256 i; i < length; ++i) {
            prices[i] = _pricePoints(i, swapB2Q);
        }

        return prices;
    }

    /**
     * @dev Returns the pending fees.
     * @param referrer The referrer address.
     * @return protocolFees The protocol fees.
     * @return creatorFees The creator fees.
     * @return referrerFees The referrer fees.
     * @return stakingFees The staking fees.
     */
    function getPendingFees(address referrer)
        external
        view
        override
        returns (uint256 protocolFees, uint256 creatorFees, uint256 referrerFees, uint256 stakingFees)
    {
        (, protocolFees, creatorFees, stakingFees) = _getPendingFees(ITMFactory(_factory()));
        referrerFees = _referrerFees[referrer];
    }

    /**
     * @dev Returns the delta amounts.
     * @param deltaAmount The delta amount.
     * @param swapB2Q Whether to swap base to quote (true) or quote to base (false).
     * @return deltaBaseAmount The delta base amount.
     * @return deltaQuoteAmount The delta quote amount.
     */
    function getDeltaAmounts(int256 deltaAmount, bool swapB2Q)
        external
        view
        override
        returns (int256 deltaBaseAmount, int256 deltaQuoteAmount)
    {
        if (deltaAmount == 0) revert TMMarket__ZeroAmount();

        uint256 circulatingSupply = _totalSupply() - _baseReserve;

        return (deltaAmount > 0) == swapB2Q
            ? getDeltaQuoteAmount(circulatingSupply, deltaAmount)
            : getDeltaBaseAmount(circulatingSupply, deltaAmount);
    }

    /**
     * @dev Swap tokens.
     * TOKEN/USD -> TOKEN is base, USD is quote
     * swapB2Q = true  + dAmount > 0 (true)  -> in: dAmount Base,  out:       -X Quote
     * swapB2Q = true  + dAmount < 0 (false) -> in:       X Base,  out: -dAmount Quote
     * swapB2Q = false + dAmount > 0 (true)  -> in: dAmount Quote, out:       -X Base
     * swapB2Q = false + dAmount < 0 (false) -> in:       X Quote, out: -dAmount Base
     * @param recipient The recipient of the tokens.
     * @param deltaAmount The delta amount.
     * @param swapB2Q Whether to swap base to quote (true) or quote to base (false).
     * @param data The data to be passed to the swap callback. If the data is empty, the callback will be skipped.
     * @return deltaBaseAmount The delta base amount.
     * @return deltaQuoteAmount The delta quote amount.
     */
    function swap(address recipient, int256 deltaAmount, bool swapB2Q, bytes calldata data, address referrer)
        external
        override
        nonReentrant
        returns (int256 deltaBaseAmount, int256 deltaQuoteAmount)
    {
        if (recipient == address(0)) revert TMMarket__InvalidRecipient();
        if (deltaAmount == 0) revert TMMarket__ZeroAmount();

        (uint256 baseReserve, uint256 quoteReserve) = _getReserves();
        uint256 circulatingSupply = _totalSupply() - baseReserve;

        (deltaBaseAmount, deltaQuoteAmount) = (deltaAmount > 0) == swapB2Q
            ? getDeltaQuoteAmount(circulatingSupply, deltaAmount)
            : getDeltaBaseAmount(circulatingSupply, deltaAmount);

        (uint256 toSend, uint256 toReceive, IERC20 tokenToSend, IERC20 tokenToReceive) = swapB2Q
            ? (Math.abs(deltaQuoteAmount), Math.abs(deltaBaseAmount), IERC20(_quoteToken()), IERC20(_baseToken()))
            : (Math.abs(deltaBaseAmount), Math.abs(deltaQuoteAmount), IERC20(_baseToken()), IERC20(_quoteToken()));

        if (toSend > 0) IERC20(tokenToSend).safeTransfer(recipient, toSend);
        if (data.length > 0) {
            bytes memory cdata = new bytes(160 + data.length);
            uint256 success;

            assembly {
                mstore(cdata, 0xc556a189) // tokenMillSwapCallback(int256,int256,bytes)

                mstore(add(cdata, 32), deltaBaseAmount)
                mstore(add(cdata, 64), deltaQuoteAmount)
                mstore(add(cdata, 96), 96)
                mstore(add(cdata, 128), data.length)
                calldatacopy(add(cdata, 160), data.offset, data.length)

                success := call(gas(), caller(), 0, add(28, cdata), add(160, data.length), 0, 4)

                switch success
                case 0 {
                    returndatacopy(0, 0, returndatasize())
                    revert(0, returndatasize())
                }
                default { success := and(eq(returndatasize(), 4), eq(shr(224, mload(0)), 0xc556a189)) } // tokenMillSwapCallback(int256,int256,bytes)
            }

            if (success == 0) revert TMMarket__InvalidSwapCallback();
        }

        emit Swap(msg.sender, recipient, referrer, deltaBaseAmount, deltaQuoteAmount);

        uint256 balance = tokenToReceive.balanceOf(address(this));
        if (balance > type(uint128).max) revert TMMarket__ReserveOverflow();

        swapB2Q
            ? _updateReservesOnB2Q(baseReserve, quoteReserve, toSend, toReceive, balance)
            : _updateReservesOnQ2B(referrer, circulatingSupply, baseReserve, quoteReserve, toSend, toReceive, balance);
    }

    /**
     * @dev Claims the fees for the caller.
     * @param caller The caller of the function. This will be used to claim the referrer fees.
     * @param protocol The protocol fee recipient.
     * @param creator The creator of the market.
     * @param staking The staking contract address.
     * @return The protocol fees claimed.
     * @return claimedFees The total fees claimed.
     */
    function claimFees(address caller, address protocol, address creator, address staking)
        external
        override
        nonReentrant
        returns (uint256, uint256 claimedFees)
    {
        ITMFactory factory = ITMFactory(_factory());

        if (msg.sender != address(factory)) revert TMMarket__OnlyFactory();

        (
            uint256 quoteReserve,
            uint256 protocolUnclaimedFees,
            uint256 creatorUnclaimedFees,
            uint256 stakingUnclaimedFees
        ) = _getPendingFees(factory);

        if (caller == staking) {
            claimedFees = stakingUnclaimedFees;
            _stakingUnclaimedFees = 0;
        } else {
            _stakingUnclaimedFees = uint128(stakingUnclaimedFees);
        }

        if (caller == creator) {
            claimedFees += creatorUnclaimedFees;
            _creatorUnclaimedFees = 0;
        } else {
            _creatorUnclaimedFees = uint128(creatorUnclaimedFees);
        }

        uint256 referrerFees = _referrerFees[caller];

        if (referrerFees > 0) {
            _referrerFees[caller] = 0;
            _totalReferrerFees -= uint128(referrerFees);

            claimedFees += referrerFees;
        }

        uint256 totalFees = protocolUnclaimedFees + claimedFees;

        if (totalFees > 0) {
            _quoteReserve = uint128(quoteReserve - totalFees);

            IERC20 quoteToken = IERC20(_quoteToken());

            if (protocolUnclaimedFees > 0) quoteToken.safeTransfer(protocol, protocolUnclaimedFees);
            if (claimedFees > 0) quoteToken.safeTransfer(caller, claimedFees);

            emit FeesClaimed(caller, protocolUnclaimedFees, claimedFees);
        }

        return (protocolUnclaimedFees, claimedFees);
    }

    /**
     * @dev Returns the pending fees.
     * @param factory The factory contract.
     * @return quoteReserve The quote reserve.
     * @return protocolUnclaimedFees The protocol unclaimed fees.
     * @return creatorUnclaimedFees The creator unclaimed fees.
     * @return stakingUnclaimedFees The staking unclaimed fees.
     */
    function _getPendingFees(ITMFactory factory)
        internal
        view
        returns (
            uint256 quoteReserve,
            uint256 protocolUnclaimedFees,
            uint256 creatorUnclaimedFees,
            uint256 stakingUnclaimedFees
        )
    {
        stakingUnclaimedFees = _stakingUnclaimedFees;
        creatorUnclaimedFees = _creatorUnclaimedFees;

        quoteReserve = _quoteReserve;
        (, uint256 minQuoteAmount) = _getQuoteAmount(0, _totalSupply() - _baseReserve, false, true);

        if (quoteReserve > minQuoteAmount) {
            uint256 totalReferrerFees = _totalReferrerFees;

            uint256 totalUnclaimedFees = totalReferrerFees + stakingUnclaimedFees + creatorUnclaimedFees;
            uint256 totalFees = quoteReserve - minQuoteAmount;

            if (totalFees > totalUnclaimedFees) {
                uint256 fees = totalFees - totalUnclaimedFees;

                (uint256 protocolShare, uint256 creatorShare,, uint256 stakingShare) =
                    factory.getFeeSharesOf(address(this));

                uint256 totalShare = protocolShare + creatorShare + stakingShare;

                uint256 stakingFees = fees * stakingShare / totalShare;
                uint256 creatorFees = fees * creatorShare / totalShare;
                uint256 protocolFees = fees - stakingFees - creatorFees;

                protocolUnclaimedFees = protocolFees;
                creatorUnclaimedFees += creatorFees;
                stakingUnclaimedFees += stakingFees;
            }
        }
    }

    /**
     * @dev Returns the reserves.
     * @return The base and quote reserves.
     */
    function _getReserves() internal view returns (uint256, uint256) {
        return (_baseReserve, _quoteReserve);
    }

    /**
     * @dev Updates the reserves on a base to quote swap.
     * @param baseReserve The base reserve.
     * @param quoteReserve The quote reserve.
     * @param toSend The amount to send.
     * @param toReceive The amount to receive.
     * @param baseBalance The base balance.
     */
    function _updateReservesOnB2Q(
        uint256 baseReserve,
        uint256 quoteReserve,
        uint256 toSend,
        uint256 toReceive,
        uint256 baseBalance
    ) internal {
        if (baseReserve + toReceive > baseBalance) revert TMMarket__InsufficientAmount();

        _baseReserve = uint128(baseBalance);
        _quoteReserve = uint128(quoteReserve - toSend);
    }

    /**
     * @dev Updates the reserves on a quote to base swap.
     * @param baseReserve The base reserve.
     * @param quoteReserve The quote reserve.
     * @param toSend The amount to send.
     * @param toReceive The amount to receive.
     * @param quoteBalance The quote balance.
     */
    function _updateReservesOnQ2B(
        address referrer,
        uint256 circulatingSupply,
        uint256 baseReserve,
        uint256 quoteReserve,
        uint256 toSend,
        uint256 toReceive,
        uint256 quoteBalance
    ) internal {
        if (quoteReserve + toReceive > quoteBalance) revert TMMarket__InsufficientAmount();

        if (referrer != address(0)) {
            uint256 share;
            uint256 totalShare;

            {
                (uint256 protocolShare, uint256 creatorShare, uint256 referrerShare, uint256 stakingShare) =
                    ITMFactory(_factory()).getFeeSharesOf(address(this));

                share = referrerShare;
                totalShare = protocolShare + creatorShare + referrerShare + stakingShare;
            }

            if (share > 0) {
                (, uint256 buybackAmount) = _getQuoteAmount(circulatingSupply, toSend, false, true);
                uint256 minQuoteAmount = quoteReserve + buybackAmount;

                if (quoteBalance > minQuoteAmount) {
                    uint256 referrerFees = (quoteBalance - minQuoteAmount) * share / totalShare;

                    _referrerFees[referrer] += referrerFees;
                    _totalReferrerFees += uint128(referrerFees);
                }
            }
        }

        _baseReserve = uint128(baseReserve - toSend);
        _quoteReserve = uint128(quoteBalance);
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
        return _getUint(108, 8);
    }

    /**
     * @dev Returns the price points using the immutable arguments.
     * This function doesn't check that the index is within bounds. It should be done by the parent function.
     * @param i The index of the price point.
     * @param askPrice Whether to get the ask price (true), ie, the price at which the user can sell the base token,
     * or the bid price (false), ie, the price at which the user can buy the base token.
     * @return The price of the base token in the quote token at the specified index.
     */
    function _pricePoints(uint256 i, bool askPrice) internal pure override returns (uint256) {
        return _getUint((askPrice ? 109 : 125) + i * 32, 128);
    }
}
