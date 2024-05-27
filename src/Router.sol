// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {PackedRoute} from "./libraries/PackedRoute.sol";
import {Math} from "./libraries/Math.sol";
import {IV1Factory} from "./interfaces/IV1Factory.sol";
import {IV1Pair} from "./interfaces/IV1Pair.sol";
import {IV2_0Factory} from "./interfaces/IV2_0Factory.sol";
import {IV2_0Router} from "./interfaces/IV2_0Router.sol";
import {IV2_0Pair} from "./interfaces/IV2_0Pair.sol";
import {IV2_1Factory} from "./interfaces/IV2_1Factory.sol";
import {IV2_1Pair} from "./interfaces/IV2_1Pair.sol";
import {IV2_2Factory} from "./interfaces/IV2_2Factory.sol";
import {IV2_2Pair} from "./interfaces/IV2_2Pair.sol";
import {ITMFactory} from "./interfaces/ITMFactory.sol";
import {ITMMarket} from "./interfaces/ITMMarket.sol";
import {IWNATIVE} from "./interfaces/IWNATIVE.sol";

contract Router {
    using SafeERC20 for IERC20;

    error Router__OnlyWNative();
    error Router__InvalidMarket();
    error Router__InvalidRecipient();
    error Router__InsufficientOutputAmount();
    error Router__NativeTransferFailed();
    error Router__InvalidAmounts();
    error Router__ExceedsMaxInputAmount();
    error Router__InvalidId();

    IV1Factory internal immutable _v1Factory;
    IV2_0Factory internal immutable _v2_0Factory;
    IV2_0Router internal immutable _v2_0Router;
    IV2_1Factory internal immutable _v2_1Factory;
    IV2_2Factory internal immutable _v2_2Factory;
    ITMFactory internal immutable _tmFactory;

    IWNATIVE internal immutable _wnative;

    constructor(
        address v1Factory,
        address v2_0Router,
        address v2_1Factory,
        address v2_2Factory,
        address tmFactory,
        address wnative
    ) {
        _v1Factory = IV1Factory(v1Factory);

        address factory = v2_0Router == address(0) ? address(0) : IV2_0Router(v2_0Router).factory();
        _v2_0Factory = IV2_0Factory(factory);
        _v2_0Router = IV2_0Router(v2_0Router);

        _v2_1Factory = IV2_1Factory(v2_1Factory);
        _v2_2Factory = IV2_2Factory(v2_2Factory);
        _tmFactory = ITMFactory(tmFactory);

        _wnative = IWNATIVE(wnative);
    }

    receive() external payable {
        if (msg.sender != address(_wnative)) revert Router__OnlyWNative();
    }

    function getFactory(uint256 v, uint256 sv) external view returns (address) {
        if (v == 1) {
            return address(_v1Factory);
        } else if (v == 2) {
            if (sv == 0) {
                return address(_v2_0Factory);
            } else if (sv == 1) {
                return address(_v2_1Factory);
            } else if (sv == 2) {
                return address(_v2_2Factory);
            }
        } else if (v == 3) {
            return address(_tmFactory);
        }

        return address(0);
    }

    function getWNative() external view returns (address) {
        return address(_wnative);
    }

    function swapExactIn(bytes memory route, address to, uint256 amountIn, uint256 amountOutMin)
        external
        payable
        returns (uint256, uint256)
    {
        if (to == address(this)) revert Router__InvalidRecipient();

        (address[] memory pairs, uint256[] memory ids, address[] memory tokens) = _getPairsAndIds(route);

        _transfer(tokens[0], msg.sender, pairs[0], amountIn);

        address lastToken = tokens[pairs.length];
        address recipient = lastToken == address(0) ? address(this) : to;

        uint256 balanceBefore = _balanceOf(lastToken, recipient);
        _swapExactIn(recipient, pairs, ids, tokens, amountIn);
        uint256 balanceAfter = _balanceOf(lastToken, recipient);

        if (balanceBefore + amountOutMin > balanceAfter) revert Router__InsufficientOutputAmount();
        uint256 amountOut = balanceAfter - balanceBefore;

        if (recipient == address(this)) _transfer(lastToken, recipient, to, amountOut);

        if (msg.value > 0) {
            uint256 leftOver = address(this).balance;
            if (leftOver > 0) {
                _transferNative(msg.sender, leftOver);
            }
        }

        return (amountIn, amountOut);
    }

    function swapExactInSupportingFeeOnTransferTokens(
        bytes memory route,
        address to,
        uint256 amountIn,
        uint256 amountOutMin
    ) external payable returns (uint256, uint256) {
        if (to == address(this)) revert Router__InvalidRecipient();

        (address[] memory pairs, uint256[] memory ids, address[] memory tokens) = _getPairsAndIds(route);

        uint256 balanceBefore = _balanceOf(tokens[0], msg.sender);
        _transfer(tokens[0], msg.sender, pairs[0], amountIn);
        amountIn = _balanceOf(tokens[0], msg.sender) - balanceBefore;

        address lastToken = tokens[pairs.length];
        address recipient = lastToken == address(0) ? address(this) : to;

        uint256 amountOut = _swapExactInSupportingFeeOnTransferTokens(recipient, pairs, ids, tokens, amountIn);

        if (amountOut < amountOutMin) revert Router__InsufficientOutputAmount();

        if (recipient == address(this)) _transfer(lastToken, recipient, to, amountOut);

        if (msg.value > 0) {
            uint256 leftOver = address(this).balance;
            if (leftOver > 0) {
                _transferNative(msg.sender, leftOver);
            }
        }

        return (amountIn, amountOut);
    }

    function swapExactOut(bytes memory route, address to, uint256 amountOut, uint256 amountInMax)
        external
        payable
        returns (uint256, uint256)
    {
        if (to == address(this)) revert Router__InvalidRecipient();

        (address[] memory pairs, uint256[] memory ids, address[] memory tokens) = _getPairsAndIds(route);
        uint256[] memory amounts = _getAmounts(pairs, ids, tokens, amountOut);

        uint256 amountIn = amounts[0];

        if (amountIn > amountInMax) revert Router__ExceedsMaxInputAmount();

        _transfer(tokens[0], msg.sender, pairs[0], amountIn);

        address lastToken = tokens[pairs.length];
        address recipient = lastToken == address(0) ? address(this) : to;

        {
            uint256 balanceBefore = _balanceOf(lastToken, recipient);
            _swapExactOut(recipient, pairs, ids, tokens, amounts);
            uint256 balanceAfter = _balanceOf(lastToken, recipient);

            if (balanceBefore + amountOut > balanceAfter) revert Router__InsufficientOutputAmount();
            amountOut = balanceAfter - balanceBefore;
        }

        if (lastToken == address(0)) _transfer(lastToken, address(this), to, amountOut);

        if (msg.value > 0) {
            uint256 leftOver = address(this).balance;
            if (leftOver > 0) {
                _transferNative(msg.sender, leftOver);
            }
        }

        return (amountIn, amountOut);
    }

    function _getPairsAndIds(bytes memory route)
        internal
        view
        returns (address[] memory pairs, uint256[] memory ids, address[] memory tokens)
    {
        uint256 length = PackedRoute.length(route);

        tokens = new address[](length);
        pairs = new address[](--length);
        ids = new uint256[](length);

        address tokenIn = PackedRoute.at(route, 0);
        address tokenOut;

        tokens[0] = tokenIn;
        tokenIn = tokenIn == address(0) ? address(_wnative) : tokenIn;

        unchecked {
            for (uint256 i; i < length;) {
                uint256 id = PackedRoute.id(route, i);
                tokenOut = PackedRoute.at(route, i + 1);

                (uint256 v, uint256 sv, uint256 t) = PackedRoute.decodeId(id);

                address pair;
                if (v == 1) {
                    pair = _v1Factory.getPair(tokenIn, tokenOut);
                    if (pair == address(0)) revert Router__InvalidMarket();
                    if ((sv | t) != 0) revert Router__InvalidId();

                    assembly {
                        id := or(id, lt(tokenIn, tokenOut))
                    }
                } else if (v == 2) {
                    bool swapForY;

                    if (sv == 0) {
                        pair = _v2_0Factory.getLBPairInformation(tokenIn, tokenOut, t).LBPair;
                        if (pair == address(0)) revert Router__InvalidMarket();

                        swapForY = tokenOut == IV2_0Pair(pair).tokenY();
                    } else if (sv == 1) {
                        pair = _v2_1Factory.getLBPairInformation(tokenIn, tokenOut, t).LBPair;
                        if (pair == address(0)) revert Router__InvalidMarket();

                        swapForY = tokenOut == IV2_1Pair(pair).getTokenY();
                    } else if (sv == 2) {
                        pair = _v2_2Factory.getLBPairInformation(tokenIn, tokenOut, t).LBPair;
                        if (pair == address(0)) revert Router__InvalidMarket();

                        swapForY = tokenOut == IV2_2Pair(pair).getTokenY();
                    } else {
                        revert Router__InvalidId();
                    }

                    assembly {
                        id := or(sub(id, t), swapForY)
                    }
                } else if (v == 3) {
                    bool fillBid;
                    (fillBid, pair) =
                        _tmFactory.getMarket(tokenIn, tokenOut == address(0) ? address(_wnative) : tokenOut);
                    if (pair == address(0)) revert Router__InvalidMarket();
                    if ((sv | t) != 0) revert Router__InvalidId();

                    assembly {
                        id := or(id, iszero(iszero(fillBid)))
                    }
                } else {
                    revert Router__InvalidId();
                }

                pairs[i] = pair;
                ids[i] = id;
                tokens[++i] = tokenOut;

                tokenIn = tokenOut;
            }
        }
    }

    function _getAmounts(address[] memory pairs, uint256[] memory ids, address[] memory tokens, uint256 amount)
        internal
        view
        returns (uint256[] memory amounts)
    {
        uint256 length = tokens.length;
        amounts = new uint256[](length);

        uint256 i = length - 1;
        amounts[i] = amount;

        address tokenOut = tokens[i];

        for (; i > 0;) {
            (uint256 v, uint256 sv, uint256 t) = PackedRoute.decodeId(ids[--i]);
            address pair = pairs[i];
            address tokenIn = tokens[i];

            if (v == 1) {
                (uint256 reserveIn, uint256 reserveOut,) = IV1Pair(pair).getReserves();
                (reserveIn, reserveOut) = t == 1 ? (reserveIn, reserveOut) : (reserveOut, reserveIn);

                uint256 numerator = reserveIn * amount * 1000;
                uint256 denominator = (reserveOut - amount) * 997;

                amount = Math.div(numerator, denominator, true);
            } else if (v == 2) {
                if (sv == 0) {
                    (amount,) = _v2_0Router.getSwapIn(pair, uint128(amount), t == 1);
                } else if (sv < 3) {
                    (amount,,) = IV2_1Pair(pair).getSwapIn(uint128(amount), t == 1);
                } else {
                    revert Router__InvalidId();
                }
            } else if (v == 3) {
                (int256 deltaBaseAmount, int256 deltaQuoteAmount) =
                    ITMMarket(pair).getDeltaAmounts(-int256(amount), t == 1);

                if (t == 1) {
                    if (uint256(-deltaQuoteAmount) != amount) revert Router__InvalidAmounts();
                    amount = uint256(deltaBaseAmount);
                } else {
                    if (uint256(-deltaBaseAmount) != amount) revert Router__InvalidAmounts();
                    amount = uint256(deltaQuoteAmount);
                }
            } else {
                revert Router__InvalidId();
            }

            amounts[i] = amount;
        }
    }

    function _swapExactIn(
        address to,
        address[] memory pairs,
        uint256[] memory ids,
        address[] memory tokens,
        uint256 amount
    ) internal {
        uint256 length = pairs.length;
        address pair = pairs[0];

        for (uint256 i; i < length;) {
            (uint256 v, uint256 sv, uint256 t) = PackedRoute.decodeId(ids[i]);
            address recipient = ++i == length ? to : pairs[i];

            amount = _swap(pair, recipient, amount, v, sv, t);

            pair = recipient;
        }
    }

    function _swapExactInSupportingFeeOnTransferTokens(
        address to,
        address[] memory pairs,
        uint256[] memory ids,
        address[] memory tokens,
        uint256 amount
    ) internal returns (uint256) {
        uint256 length = pairs.length;
        address pair = pairs[0];

        for (uint256 i; i < length;) {
            (uint256 v, uint256 sv, uint256 t) = PackedRoute.decodeId(ids[i]);
            address recipient = ++i == length ? to : pairs[i];
            address tokenOut = tokens[i];

            uint256 balance = _balanceOf(tokenOut, recipient);
            _swap(pair, recipient, amount, v, sv, t);
            amount = _balanceOf(tokenOut, recipient) - balance;

            pair = recipient;
        }

        return amount;
    }

    function _swapExactOut(
        address to,
        address[] memory pairs,
        uint256[] memory ids,
        address[] memory tokens,
        uint256[] memory amounts
    ) internal {
        uint256 length = pairs.length;
        address pair = pairs[0];

        for (uint256 i; i < length;) {
            (uint256 v, uint256 sv, uint256 t) = PackedRoute.decodeId(ids[i]);
            uint256 amountIn = amounts[i];

            address recipient = ++i == length ? to : pairs[i];

            _swap(pair, recipient, amountIn, v, sv, t);

            pair = recipient;
        }
    }

    function _swap(address pair, address recipient, uint256 amount, uint256 v, uint256 sv, uint256 t)
        internal
        returns (uint256)
    {
        if (v == 1) {
            (uint256 reserveIn, uint256 reserveOut,) = IV1Pair(pair).getReserves();
            (reserveIn, reserveOut) = t == 1 ? (reserveIn, reserveOut) : (reserveOut, reserveIn);

            {
                uint256 amountInWithFee = amount * 997;
                uint256 numerator = amountInWithFee * reserveOut;
                uint256 denominator = reserveIn * 1000 + amountInWithFee;

                amount = numerator / denominator;
            }

            (uint256 amount0, uint256 amount1) = t == 1 ? (uint256(0), amount) : (amount, uint256(0));
            IV1Pair(pair).swap(amount0, amount1, recipient, new bytes(0));
        } else if (v == 2) {
            if (sv == 0) {
                bool swapForY = t == 1;
                (uint256 amountXOut, uint256 amountYOut) = IV2_0Pair(pair).swap(swapForY, recipient);
                amount = swapForY ? amountYOut : amountXOut;
            } else if (sv < 3) {
                bool swapForY = t == 1;
                bytes32 amounts = IV2_1Pair(pair).swap(swapForY, recipient);
                amount = swapForY ? uint256(amounts >> 128) : uint256(uint128(uint256(amounts)));
            }
        } else if (v == 3) {
            (int256 deltaBaseAmount, int256 deltaQuoteAmount) =
                ITMMarket(pair).swap(recipient, int256(amount), t == 1, new bytes(0));

            (uint256 amountIn, uint256 amountOut) = t == 1
                ? (uint256(deltaBaseAmount), uint256(-deltaQuoteAmount))
                : (uint256(deltaQuoteAmount), uint256(-deltaBaseAmount));

            if (amountIn != amount) revert Router__InvalidAmounts();

            amount = amountOut;
        }

        return amount;
    }

    function _balanceOf(address token, address account) internal view returns (uint256) {
        if (token == address(0)) {
            return _wnative.balanceOf(account);
        } else {
            return IERC20(token).balanceOf(account);
        }
    }

    function _transfer(address token, address from, address to, uint256 amount) internal {
        if (amount == 0) return;

        if (token == address(0)) {
            if (from == address(this)) {
                _wnative.withdraw(amount);
                _transferNative(to, amount);
            } else {
                _wnative.deposit{value: amount}();
                IERC20(address(_wnative)).safeTransfer(to, amount);
            }
        } else {
            if (from == address(this)) {
                IERC20(token).safeTransfer(to, amount);
            } else {
                IERC20(token).safeTransferFrom(from, to, amount);
            }
        }
    }

    function _transferNative(address to, uint256 amount) internal {
        (bool success,) = to.call{value: amount}(new bytes(0));
        if (!success) revert Router__NativeTransferFailed();
    }
}
