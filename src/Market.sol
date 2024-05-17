// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {PricePoints} from "./PricePoints.sol";
import {Math} from "../src/libraries/Math.sol";
import {ImmutableContract} from "./libraries/ImmutableContract.sol";
import {ITokenMillCallback} from "./interfaces/ITokenMillCallback.sol";

contract Market is ImmutableContract, PricePoints {
    using SafeERC20 for IERC20;

    error Market__ZeroAmount();
    error Market__InsufficientAmount();

    event Swap(address indexed sender, address indexed recipient, int256 deltaBaseAmount, int256 deltaQuoteAmount);

    uint256 internal _circulatingSupply;

    function getBaseToken() external pure returns (address) {
        return _baseToken();
    }

    function getQuoteToken() external pure returns (address) {
        return _quoteToken();
    }

    function getCirculatingSupply() external view returns (uint256) {
        return _circulatingSupply;
    }

    function getTotalSupply() external pure returns (uint256) {
        return _totalSupply();
    }

    function getPriceAt(uint256 circulatingSupply, bool bid) external pure returns (uint256) {
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

    function getPricePoints(bool bid) external pure returns (uint256[] memory) {
        uint256 length = _pricePointsLength();

        uint256[] memory prices = new uint256[](length);

        for (uint256 i; i < length; ++i) {
            prices[i] = _pricePoints(i, bid);
        }

        return prices;
    }

    // TOKEN/USD -> TOKEN is base, USD is quote
    // fillBid -> in base, out quote
    // fillAsk -> in quote, out base
    //
    // fillBid = true  + dAmount > 0 (true)  -> in: dAmount Base,  out:       -X Quote
    // fillBid = true  + dAmount < 0 (false) -> in:       X Base,  out: -dAmount Quote
    // fillBid = false + dAmount > 0 (true)  -> in: dAmount Quote, out:       -X Base
    // fillBid = false + dAmount < 0 (false) -> in:       X Quote, out: -dAmount Base
    function swap(address recipient, int256 deltaAmount, bool fillBid, bytes calldata data) external {
        uint256 circulatingSupply = _circulatingSupply;

        if (deltaAmount == 0) revert Market__ZeroAmount();

        (int256 deltaBaseAmount, int256 deltaQuoteAmount) = (deltaAmount > 0) == fillBid
            ? getDeltaQuoteAmount(circulatingSupply, deltaAmount)
            : getDeltaBaseAmount(circulatingSupply, deltaAmount);

        _circulatingSupply = Math.addDelta(circulatingSupply, -deltaBaseAmount);

        (uint256 toSend, uint256 toReceive, IERC20 tokenToSend, IERC20 tokenToReceive) = fillBid
            ? (Math.abs(deltaQuoteAmount), Math.abs(deltaBaseAmount), IERC20(_quoteToken()), IERC20(_baseToken()))
            : (Math.abs(deltaBaseAmount), Math.abs(deltaQuoteAmount), IERC20(_baseToken()), IERC20(_quoteToken()));

        if (toSend > 0) IERC20(tokenToSend).safeTransfer(recipient, toSend);

        uint256 balance = tokenToReceive.balanceOf(address(this));

        ITokenMillCallback(msg.sender).tokenMillSwapCallback(deltaBaseAmount, deltaQuoteAmount, data);

        if (balance + toReceive < tokenToReceive.balanceOf(address(this))) revert Market__InsufficientAmount();

        emit Swap(msg.sender, recipient, deltaBaseAmount, deltaQuoteAmount);
    }

    function _baseToken() internal pure returns (address) {
        return _getAddress(0);
    }

    function _quoteToken() internal pure returns (address) {
        return _getAddress(20);
    }

    function _basePrecision() internal pure override returns (uint256) {
        return _getUint(40, 64);
    }

    function _quotePrecision() internal pure override returns (uint256) {
        return _getUint(48, 64);
    }

    function _totalSupply() internal pure override returns (uint256) {
        return _getUint(56, 128);
    }

    function _widthScaled() internal pure override returns (uint256) {
        return _getUint(72, 128);
    }

    function _pricePointsLength() internal pure override returns (uint256) {
        return _getUint(88, 16);
    }

    function _pricePoints(uint256 i, bool bid) internal pure override returns (uint256) {
        return _getUint((bid ? 106 : 90) + i * 32, 128);
    }
}
