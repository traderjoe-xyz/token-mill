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
    uint128 internal _circulatingSupply;

    uint256 internal _protocolClaimedFees;
    uint256 internal _protocolTotalFees;

    uint256 internal _creatorClaimedFees;
    uint256 internal _creatorTotalFees;

    modifier nonReentrant() {
        if (_locked) revert Market__ReentrantCall();
        _locked = true;
        _;
        _locked = false;
    }

    function getBaseToken() external pure override returns (address) {
        return _baseToken();
    }

    function getQuoteToken() external pure override returns (address) {
        return _quoteToken();
    }

    function getCirculatingSupply() external view override returns (uint256) {
        return _circulatingSupply;
    }

    function getTotalSupply() external pure override returns (uint256) {
        return _totalSupply();
    }

    function getPriceAt(uint256 circulatingSupply, bool bid) external pure override returns (uint256) {
        uint256 totalSupply = _totalSupply();

        if (circulatingSupply >= totalSupply) return _pricePoints(_pricePointsLength() - 1, bid);

        circulatingSupply = circulatingSupply * 1e18 / _basePrecision();
        uint256 widthScaled = _widthScaled();

        uint256 i = circulatingSupply / widthScaled;
        uint256 supply = circulatingSupply % widthScaled;

        uint256 p0 = _pricePoints(i, bid);
        uint256 p1 = _pricePoints(i + 1, bid);

        return p0 + (p1 - p0) * supply / widthScaled;
    }

    function getPricePoints(bool bid) external pure override returns (uint256[] memory) {
        uint256 length = _pricePointsLength();

        uint256[] memory prices = new uint256[](length);

        for (uint256 i; i < length; ++i) {
            prices[i] = _pricePoints(i, bid);
        }

        return prices;
    }

    function getPendingFees() external view override returns (uint256 protocolFees, uint256 creatorFees) {
        (uint256 pendingProtocolFees, uint256 pendingCreatorFees) =
            _getPendingFees(ITMFactory(_factory()), IERC20(_quoteToken()));

        return (
            _protocolTotalFees + pendingProtocolFees - _protocolClaimedFees,
            _creatorTotalFees + pendingCreatorFees - _creatorClaimedFees
        );
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
        if (recipient == address(0)) revert Market__InvalidRecipient();
        if (deltaAmount == 0) revert Market__ZeroAmount();

        uint256 circulatingSupply = _circulatingSupply;

        (deltaBaseAmount, deltaQuoteAmount) = (deltaAmount > 0) == fillBid
            ? getDeltaQuoteAmount(circulatingSupply, deltaAmount)
            : getDeltaBaseAmount(circulatingSupply, deltaAmount);

        _circulatingSupply = uint128(Math.addDelta(circulatingSupply, -deltaBaseAmount));

        (uint256 toSend, uint256 toReceive, IERC20 tokenToSend, IERC20 tokenToReceive) = fillBid
            ? (Math.abs(deltaQuoteAmount), Math.abs(deltaBaseAmount), IERC20(_quoteToken()), IERC20(_baseToken()))
            : (Math.abs(deltaBaseAmount), Math.abs(deltaQuoteAmount), IERC20(_baseToken()), IERC20(_quoteToken()));

        if (toSend > 0) IERC20(tokenToSend).safeTransfer(recipient, toSend);

        uint256 balance = tokenToReceive.balanceOf(address(this));

        if (
            ITokenMillCallback(msg.sender).tokenMillSwapCallback(deltaBaseAmount, deltaQuoteAmount, data)
                != ITokenMillCallback.tokenMillSwapCallback.selector
        ) {
            revert Market__InvalidSwapCallback();
        }

        if (balance + toReceive < tokenToReceive.balanceOf(address(this))) revert Market__InsufficientAmount();

        emit Swap(msg.sender, recipient, deltaBaseAmount, deltaQuoteAmount);
    }

    function claimFees(address caller, address recipient, bool isCreator, bool isProtocol)
        external
        override
        nonReentrant
        returns (uint256 fees)
    {
        ITMFactory factory = ITMFactory(_factory());

        if (msg.sender != address(factory)) revert Market__OnlyFactory();

        IERC20 quoteToken = IERC20(_quoteToken());

        (uint256 pendingProtocolFees, uint256 pendingCreatorFees) = _getPendingFees(factory, quoteToken);

        uint256 protocolTotalFees = _protocolTotalFees + pendingProtocolFees;
        uint256 creatorTotalFees = _creatorTotalFees + pendingCreatorFees;

        if (pendingProtocolFees > 0) _protocolTotalFees = protocolTotalFees;
        if (pendingCreatorFees > 0) _creatorTotalFees = creatorTotalFees;

        if (isProtocol) {
            fees = protocolTotalFees - _protocolClaimedFees;
            _protocolClaimedFees = protocolTotalFees;
        }

        if (isCreator) {
            fees += creatorTotalFees - _creatorClaimedFees;
            _creatorClaimedFees = creatorTotalFees;
        }

        if (fees > 0) {
            quoteToken.safeTransfer(recipient, fees);

            emit FeesClaimed(caller, recipient, fees);
        }
    }

    function _getPendingFees(ITMFactory factory, IERC20 quoteToken)
        internal
        view
        returns (uint256 protocolFees, uint256 creatorFees)
    {
        uint256 quoteBalance = quoteToken.balanceOf(address(this));
        (, uint256 minQuoteAmount) = _getQuoteAmount(0, _circulatingSupply, false);

        if (quoteBalance <= minQuoteAmount) return (0, 0);

        uint256 totalFees = quoteBalance - minQuoteAmount;
        uint256 protocolShare = factory.getProtocolShareOf(address(this));

        uint256 pendingProtocolFees = totalFees * protocolShare / 1e18;
        uint256 pendingCreatorFees = totalFees - pendingProtocolFees;

        return (pendingProtocolFees, pendingCreatorFees);
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

    function _pricePoints(uint256 i, bool bid) internal pure override returns (uint256) {
        return _getUint((bid ? 126 : 110) + i * 32, 128);
    }
}
