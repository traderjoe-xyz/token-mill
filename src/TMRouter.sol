// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {PackedRoute} from "./libraries/PackedRoute.sol";
import {ITokenMillCallback} from "./interfaces/ITokenMillCallback.sol";
import {ITMFactory} from "./interfaces/ITMFactory.sol";
import {ITMMarket} from "./interfaces/ITMMarket.sol";
import {IWNATIVE} from "./interfaces/IWNATIVE.sol";

contract TMRouter {
    using SafeERC20 for IERC20;

    error TMRouter__OnlyWNative();
    error TMRouter__InvalidMarket();
    error TMRouter__ZeroAmounts();
    error TMRouter__InvalidRecipient();
    error TMRouter__InvalidValue();
    error TMRouter__InsufficientOutputAmount();
    error TMRouter__NativeTransferFailed();
    error TMRouter__InvalidRoute();
    error TMRouter__InvalidAmounts();
    error TMRouter__ReentrantCall();
    error TMRouter__ExceedsMaxInputAmount();
    error TMRouter__InvalidId();

    ITMFactory internal immutable _factory;
    IWNATIVE internal immutable _wnative;

    address internal _market;
    uint256 internal _amountIn;

    constructor(address factory, address wnative) {
        _factory = ITMFactory(factory);
        _wnative = IWNATIVE(wnative);
    }

    receive() external payable {
        if (msg.sender != address(_wnative)) revert TMRouter__OnlyWNative();
    }

    function getFactory() external view returns (address) {
        return address(_factory);
    }

    function getWNative() external view returns (address) {
        return address(_wnative);
    }

    // function tokenMillSwapCallback(int256 deltaBaseAmount, int256 deltaQuoteAmount, bytes calldata data)
    //     external
    //     override
    //     returns (bytes32)
    // {
    //     if (msg.sender != _market) revert TMRouter__InvalidMarket();
    //     if (deltaBaseAmount == 0 || deltaQuoteAmount == 0) revert TMRouter__ZeroAmounts();

    //     if (data.length > 0) {
    //         (address sender, address tokenIn, bytes memory route) = abi.decode(data, (address, address, bytes));

    //         if (route.length == 0) {
    //             uint256 amount = uint256(deltaBaseAmount > 0 ? deltaBaseAmount : deltaQuoteAmount);
    //             _amountIn = amount;

    //             if (tokenIn == address(0)) {
    //                 _wrapNative(amount);
    //                 IERC20(address(_wnative)).safeTransfer(msg.sender, amount);
    //             } else {
    //                 IERC20(tokenIn).safeTransferFrom(sender, msg.sender, amount);
    //             }
    //         } else {
    //             address tokenOut = tokenIn;
    //             (route, tokenIn) = PackedRoute.pop(route);

    //             (bool fillBid, address market) =
    //                 _factory.getMarket(tokenIn == address(0) ? address(_wnative) : tokenIn, tokenOut);
    //             if (market == address(0)) revert TMRouter__InvalidMarket();

    //             _market = market;

    //             ITMMarket(market).swap(
    //                 msg.sender,
    //                 deltaBaseAmount > 0 ? -int256(deltaBaseAmount) : -int256(deltaQuoteAmount),
    //                 fillBid,
    //                 abi.encode(sender, tokenIn, route)
    //             );
    //         }
    //     }

    //     return ITokenMillCallback.tokenMillSwapCallback.selector;
    // }

    // function swapExactIn(bytes memory route, address to, uint256 amountIn, uint256 amountOutMin)
    //     external
    //     payable
    //     returns (uint256 amountOut)
    // {
    //     return _cswapExactIn(to, amountOutMin, amountIn, route);
    // }

    // function swapExactOut(bytes memory route, address to, uint256 amountOut, uint256 amountInMax)
    //     external
    //     payable
    //     returns (uint256 amountIn)
    // {
    //     return _swapExactOut(to, amountInMax, amountOut, route);
    // }

    // function _cswapExactIn(address to, uint256 amountOutMin, uint256 amountIn, bytes memory route)
    //     internal
    //     returns (uint256 amountOut)
    // {
    //     if (_market != address(0)) revert TMRouter__ReentrantCall();

    //     uint256 length = PackedRoute.length(route);
    //     if (length < 2) revert TMRouter__InvalidRoute();

    //     address tokenIn = PackedRoute.at(route, 0);
    //     address tokenOut = PackedRoute.at(route, 1);

    //     address firstToken = tokenIn;
    //     tokenIn = tokenIn == address(0) ? address(_wnative) : tokenIn;
    //     tokenOut = tokenOut == address(0) ? address(_wnative) : tokenOut;

    //     (bool fillBid, address market) = _factory.getMarket(tokenIn, tokenOut);
    //     if (market == address(0)) revert TMRouter__InvalidMarket();
    //     _market = market;

    //     uint256 balance = IERC20(tokenIn).balanceOf(market);

    //     if (firstToken == address(0)) {
    //         if (msg.value != amountIn) revert TMRouter__InvalidValue();

    //         _wrapNative(amountIn);
    //         IERC20(tokenIn).safeTransfer(market, amountIn);
    //     } else {
    //         if (msg.value != 0) revert TMRouter__InvalidValue();

    //         IERC20(tokenIn).safeTransferFrom(msg.sender, market, amountIn);
    //     }

    //     amountIn = IERC20(tokenIn).balanceOf(market) - balance;

    //     bool nextFillBid;
    //     address recipient;
    //     uint256 ain = amountIn;
    //     for (uint256 i = 2;; ++i) {
    //         tokenIn = tokenOut;

    //         if (length == i) {
    //             recipient = PackedRoute.at(route, i - 1) == address(0) ? address(this) : to;
    //         } else {
    //             tokenOut = PackedRoute.at(route, i);
    //             tokenOut = tokenOut == address(0) ? address(_wnative) : tokenOut;

    //             (nextFillBid, recipient) = _factory.getMarket(tokenIn, tokenOut);
    //             if (recipient == address(0)) revert TMRouter__InvalidMarket();
    //         }

    //         balance = IERC20(tokenIn).balanceOf(recipient);

    //         (int256 deltaBaseAmount, int256 deltaQuoteAmount) =
    //             ITMMarket(market).swap(recipient, int256(ain), fillBid, new bytes(0));

    //         if (deltaBaseAmount > 0 ? uint256(deltaBaseAmount) != ain : uint256(deltaQuoteAmount) != ain) {
    //             revert TMRouter__InvalidAmounts();
    //         }

    //         amountOut = IERC20(tokenIn).balanceOf(recipient) - balance;

    //         if (length == i) break;

    //         (ain, fillBid, market) = (amountOut, nextFillBid, recipient);
    //         _market = market;
    //     }

    //     if (amountOut < amountOutMin) revert TMRouter__InsufficientOutputAmount();

    //     _market = address(0);

    //     if (recipient == address(this)) {
    //         _unwrapNative(amountOut);
    //         _transferNative(to, amountOut);
    //     }

    //     if (msg.value > 0) {
    //         uint256 leftOver = address(this).balance;
    //         if (leftOver > 0) {
    //             _transferNative(msg.sender, leftOver);
    //         }
    //     }
    // }

    // function _swapExactOut(address to, uint256 amountInMax, uint256 amountOut, bytes memory route)
    //     internal
    //     returns (uint256 amountIn)
    // {
    //     if (_market != address(0)) revert TMRouter__ReentrantCall();
    //     if (PackedRoute.length(route) < 2) revert TMRouter__InvalidRoute();

    //     address tokenIn;
    //     address tokenOut;

    //     (route, tokenOut) = PackedRoute.pop(route);
    //     (route, tokenIn) = PackedRoute.pop(route);

    //     address lastToken = tokenOut;
    //     tokenOut = tokenOut == address(0) ? address(_wnative) : tokenOut;

    //     bool fillBid;
    //     address market;
    //     if (tokenIn == address(0)) {
    //         if (msg.value != amountInMax) revert TMRouter__InvalidValue();

    //         (fillBid, market) = _factory.getMarket(address(_wnative), tokenOut);
    //     } else {
    //         if (msg.value != 0) revert TMRouter__InvalidValue();

    //         (fillBid, market) = _factory.getMarket(tokenIn, tokenOut);
    //     }

    //     if (market == address(0)) revert TMRouter__InvalidMarket();
    //     _market = market;

    //     (int256 deltaBaseAmount, int256 deltaQuoteAmount) = ITMMarket(market).swap(
    //         lastToken == address(0) ? address(this) : to,
    //         -int256(amountOut),
    //         fillBid,
    //         abi.encode(msg.sender, tokenIn, route)
    //     );

    //     if (deltaBaseAmount < 0 ? uint256(-deltaBaseAmount) != amountOut : uint256(-deltaQuoteAmount) != amountOut) {
    //         revert TMRouter__InvalidAmounts();
    //     }

    //     amountIn = _amountIn;
    //     if (amountIn > amountInMax) revert TMRouter__ExceedsMaxInputAmount();

    //     _market = address(0);

    //     if (lastToken == address(0)) {
    //         _unwrapNative(amountOut);
    //         _transferNative(to, amountOut);
    //     }

    //     if (msg.value > 0) {
    //         uint256 leftOver = address(this).balance;
    //         if (leftOver > 0) {
    //             _transferNative(msg.sender, leftOver);
    //         }
    //     }
    // }

    function swapExactIn(bytes memory route, address to, uint256 amountIn, uint256 amountOutMin)
        external
        payable
        returns (uint256, uint256)
    {
        (address[] memory pairs, uint256[] memory ids, address[] memory tokens) = _getPairsAndIds(route);

        _transfer(tokens[0], msg.sender, pairs[0], amountIn);

        address lastToken = tokens[pairs.length];
        address recipient = lastToken == address(0) ? address(this) : to;

        uint256 balanceBefore = _balanceOf(lastToken, recipient);
        _swapExactIn(pairs, ids, tokens, amountIn, recipient);
        uint256 balanceAfter = _balanceOf(lastToken, recipient);

        if (balanceBefore + amountOutMin > balanceAfter) revert TMRouter__InsufficientOutputAmount();
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

    function swapExactOut(bytes memory route, address to, uint256 amountOut, uint256 amountInMax)
        external
        payable
        returns (uint256, uint256)
    {
        (address[] memory pairs, uint256[] memory ids, address[] memory tokens) = _getPairsAndIds(route);
        uint256[] memory amounts = _getAmounts(pairs, ids, tokens, amountOut);

        uint256 amountIn = amounts[0];

        if (amountIn > amountInMax) revert TMRouter__ExceedsMaxInputAmount();

        _transfer(tokens[0], msg.sender, pairs[0], amountIn);

        address lastToken = tokens[pairs.length];
        address recipient = lastToken == address(0) ? address(this) : to;

        {
            uint256 balanceBefore = _balanceOf(lastToken, recipient);
            _swapExactOut(pairs, ids, tokens, amounts, recipient);
            uint256 balanceAfter = _balanceOf(lastToken, recipient);

            if (balanceBefore + amountOut > balanceAfter) revert TMRouter__InsufficientOutputAmount();
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
        if (length < 2) revert TMRouter__InvalidRoute();

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

                (uint256 v, uint256 sv, uint256 t) = _decodeId(id);

                address pair;
                if (v == 1) {} else if (v == 2) {} else if (v == 3) {
                    bool fillBid;
                    (fillBid, pair) = _factory.getMarket(tokenIn, tokenOut == address(0) ? address(_wnative) : tokenOut);
                    if (pair == address(0)) revert TMRouter__InvalidMarket();
                    if ((sv | t) != 0) revert TMRouter__InvalidId();

                    assembly {
                        id := or(id, iszero(iszero(fillBid)))
                    }
                } else {
                    revert("PANIC");
                }

                pairs[i] = pair;
                ids[i] = id;
                tokens[++i] = tokenOut;

                tokenIn = tokenOut;
            }
        }
    }

    function _getAmounts(address[] memory pairs, uint256[] memory ids, address[] memory tokens, uint256 amountOut)
        internal
        view
        returns (uint256[] memory amounts)
    {
        uint256 length = tokens.length;
        amounts = new uint256[](length);

        uint256 i = length - 1;
        amounts[i] = amountOut;

        for (; i > 0;) {
            (uint256 v, uint256 sv, uint256 t) = _decodeId(ids[--i]);

            if (v == 1) {} else if (v == 2) {} else if (v == 3) {
                (int256 deltaBaseAmount, int256 deltaQuoteAmount) =
                    ITMMarket(pairs[i]).getDeltaAmounts(-int256(amountOut), t == 1);

                if (t == 1) {
                    if (uint256(-deltaQuoteAmount) != amountOut) revert TMRouter__InvalidAmounts();
                    amountOut = uint256(deltaBaseAmount);
                } else {
                    if (uint256(-deltaBaseAmount) != amountOut) revert TMRouter__InvalidAmounts();
                    amountOut = uint256(deltaQuoteAmount);
                }

                amounts[i] = amountOut;
            } else {
                revert("PANIC");
            }
        }
    }

    function _swapExactIn(
        address[] memory pairs,
        uint256[] memory ids,
        address[] memory tokens,
        uint256 amount,
        address to
    ) internal {
        uint256 length = pairs.length;
        address pair = pairs[0];

        for (uint256 i; i < length;) {
            (uint256 v, uint256 sv, uint256 t) = _decodeId(ids[i]);
            address recipient = ++i == length ? to : pairs[i];

            if (v == 1) {} else if (v == 2) {} else if (v == 3) {
                (int256 deltaBaseAmount, int256 deltaQuoteAmount) =
                    ITMMarket(pair).swap(recipient, int256(amount), t == 1, new bytes(0));

                (uint256 amountIn, uint256 amountOut) = t == 1
                    ? (uint256(deltaBaseAmount), uint256(-deltaQuoteAmount))
                    : (uint256(deltaQuoteAmount), uint256(-deltaBaseAmount));

                if (amountIn != amount) revert TMRouter__InvalidAmounts();

                amount = amountOut;
            } else {
                revert("PANIC");
            }

            pair = recipient;
        }
    }

    function _swapExactOut(
        address[] memory pairs,
        uint256[] memory ids,
        address[] memory tokens,
        uint256[] memory amounts,
        address to
    ) internal {
        uint256 length = pairs.length;
        address pair = pairs[0];

        for (uint256 i; i < length;) {
            (uint256 v, uint256 sv, uint256 t) = _decodeId(ids[i]);
            uint256 amountIn = amounts[i];

            address recipient = ++i == length ? to : pairs[i];

            if (v == 1) {} else if (v == 2) {} else if (v == 3) {
                (int256 deltaBaseAmount, int256 deltaQuoteAmount) =
                    ITMMarket(pair).swap(recipient, int256(amountIn), t == 1, new bytes(0));

                if (t == 1 ? uint256(deltaBaseAmount) != amountIn : uint256(deltaQuoteAmount) != amountIn) {
                    revert TMRouter__InvalidAmounts();
                }
            } else {
                revert("PANIC");
            }

            pair = recipient;
        }
    }

    function _decodeId(uint256 id) internal pure returns (uint256 v, uint256 sv, uint256 t) {
        assembly {
            v := and(shr(24, id), 0xff)
            sv := and(shr(16, id), 0xff)
            t := and(id, 0xffff)
        }
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
        if (!success) revert TMRouter__NativeTransferFailed();
    }
}
