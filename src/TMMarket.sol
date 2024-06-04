// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {PricePoints} from "./libraries/PricePoints.sol";
import {Math} from "./libraries/Math.sol";
import {ImmutableContract} from "./libraries/ImmutableContract.sol";
import {ITokenMillCallback} from "./interfaces/ITokenMillCallback.sol";
import {ITMFactory} from "./interfaces/ITMFactory.sol";
import {ITMMarket} from "./interfaces/ITMMarket.sol";

contract TMMarket is PricePoints, ImmutableContract, ITMMarket {
    using SafeERC20 for IERC20;

    bool internal _locked;
    uint128 internal _baseReserve;
    uint256 internal _quoteReserve;

    uint256 internal _protocolUnclaimedFees;
    uint256 internal _creatorUnclaimedFees;

    modifier nonReentrant() {
        if (_locked) revert TMMarket__ReentrantCall();
        _locked = true;
        _;
        _locked = false;
    }

    function initialize() external override {
        if (msg.sender != _factory()) revert TMMarket__OnlyFactory();

        _baseReserve = uint128(_totalSupply());
    }

    function getBaseToken() external pure override returns (address) {
        return _baseToken();
    }

    function getQuoteToken() external pure override returns (address) {
        return _quoteToken();
    }

    function getCirculatingSupply() external view override returns (uint256) {
        return _totalSupply() - _baseReserve;
    }

    function getTotalSupply() external pure override returns (uint256) {
        return _totalSupply();
    }

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

    function getPricePoints(bool fillBid) external pure override returns (uint256[] memory) {
        uint256 length = _pricePointsLength();

        uint256[] memory prices = new uint256[](length);

        for (uint256 i; i < length; ++i) {
            prices[i] = _pricePoints(i, fillBid);
        }

        return prices;
    }

    function getPendingFees() external view override returns (uint256 protocolFees, uint256 creatorFees) {
        (, uint256 pendingProtocolFees, uint256 pendingCreatorFees) = _getPendingFees(ITMFactory(_factory()));

        return (pendingProtocolFees, pendingCreatorFees);
    }

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

    // TOKEN/USD -> TOKEN is base, USD is quote
    // fillBid -> in base, out quote
    // fillAsk -> in quote, out base
    //
    // fillBid = true  + dAmount > 0 (true)  -> in: dAmount Base,  out:       -X Quote
    // fillBid = true  + dAmount < 0 (false) -> in:       X Base,  out: -dAmount Quote
    // fillBid = false + dAmount > 0 (true)  -> in: dAmount Quote, out:       -X Base
    // fillBid = false + dAmount < 0 (false) -> in:       X Quote, out: -dAmount Base
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

        fillBid
            ? _updateReservesOnFillBid(baseReserve, quoteReserve, toSend, toReceive, balance)
            : _updateReservesOnFillAsk(baseReserve, quoteReserve, toSend, toReceive, balance);

        emit Swap(msg.sender, recipient, deltaBaseAmount, deltaQuoteAmount);
    }

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

    function _getPendingFees(ITMFactory factory) internal view returns (uint256, uint256, uint256) {
        uint256 protocolUnclaimedFees = _protocolUnclaimedFees;
        uint256 creatorUnclaimedFees = _creatorUnclaimedFees;

        uint256 quoteReserve = _quoteReserve;
        (, uint256 minQuoteAmount) = _getQuoteAmount(0, _totalSupply() - _baseReserve, false);

        if (quoteReserve > minQuoteAmount) {
            uint256 totalUnclaimedFees = protocolUnclaimedFees + creatorUnclaimedFees;
            uint256 totalFees = quoteReserve - minQuoteAmount;

            if (totalFees > totalUnclaimedFees) {
                uint256 protocolShare = factory.getProtocolShareOf(address(this));
                uint256 protocolFees = totalFees * protocolShare / 1e18;

                protocolUnclaimedFees += protocolFees;
                creatorUnclaimedFees += totalFees - protocolFees;
            }
        }

        return (quoteReserve, protocolUnclaimedFees, creatorUnclaimedFees);
    }

    function _getReserves() internal view returns (uint256, uint256) {
        return (_baseReserve, _quoteReserve);
    }

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

    function _factory() internal pure returns (address) {
        return _getAddress(0);
    }

    function _baseToken() internal pure returns (address) {
        return _getAddress(20);
    }

    function _quoteToken() internal pure returns (address) {
        return _getAddress(40);
    }

    function _basePrecision() internal pure override returns (uint256) {
        return _getUint(60, 64);
    }

    function _quotePrecision() internal pure override returns (uint256) {
        return _getUint(68, 64);
    }

    function _totalSupply() internal pure override returns (uint256) {
        return _getUint(76, 128);
    }

    function _widthScaled() internal pure override returns (uint256) {
        return _getUint(92, 128);
    }

    function _pricePointsLength() internal pure override returns (uint256) {
        return _getUint(108, 16);
    }

    function _pricePoints(uint256 i, bool fillBid) internal pure override returns (uint256) {
        return _getUint((fillBid ? 110 : 126) + i * 32, 128);
    }
}
