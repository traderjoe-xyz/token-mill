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
import {IWNative} from "./interfaces/IWNative.sol";
import {IRouter} from "./interfaces/IRouter.sol";

/**
 * @title Router Contract
 * @dev The contract that routes swaps through the different versions of the contracts.
 * Uses the packed route to determine the path of the swap. See `PackedRoute.sol` for more information.
 */
contract Router is IRouter {
    using SafeERC20 for IERC20;

    IV1Factory internal immutable _v1Factory;
    IV2_0Factory internal immutable _v2_0Factory;
    IV2_0Router internal immutable _v2_0Router;
    IV2_1Factory internal immutable _v2_1Factory;
    IV2_2Factory internal immutable _v2_2Factory;
    ITMFactory internal immutable _tmFactory;

    IWNative internal immutable _wnative;

    /**
     * @dev Constructor for the Router contract.
     * @param v1Factory The address of the V1 factory contract.
     * @param v2_0Router The address of the V2.0 router contract.
     * @param v2_1Factory The address of the V2.1 factory contract.
     * @param v2_2Factory The address of the V2.2 factory contract.
     * @param tmFactory The address of the TM factory contract.
     * @param wnative The address of the WNative contract.
     */
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

        _wnative = IWNative(wnative);
    }

    /**
     * @dev Allows the contract to receive native tokens only from the WNative contract.
     */
    receive() external payable {
        if (msg.sender != address(_wnative)) revert Router__OnlyWNative();
    }

    /**
     * @dev Returns the factory contract for the specified version and sub-version.
     * @param v The version of the factory contract.
     * @param sv The sub-version of the factory contract.
     */
    function getFactory(uint256 v, uint256 sv) external view returns (address) {
        if (v == 1) {
            if (sv == 0) {
                return address(_v1Factory);
            }
        } else if (v == 2) {
            if (sv == 0) {
                return address(_v2_0Factory);
            } else if (sv == 1) {
                return address(_v2_1Factory);
            } else if (sv == 2) {
                return address(_v2_2Factory);
            }
        } else if (v == 3) {
            if (sv == 0) {
                return address(_tmFactory);
            }
        }

        return address(0);
    }

    /**
     * @dev Returns the WNative contract.
     */
    function getWNative() external view returns (address) {
        return address(_wnative);
    }

    /**
     * @dev Swaps the exact amount of tokens in the route for the maximum amount of tokens out.
     * Will always make sure that the user receives at least `amountOutMin` tokens.
     * @param route The packed route of the tokens to be swapped.
     * @param to The address to which the tokens will be transferred.
     * @param amountIn The amount of tokens to be swapped.
     * @param amountOutMin The minimum amount of tokens to be received.
     * @param deadline The deadline by which the transaction must be executed.
     * @return The amount of tokens in and out.
     */
    function swapExactIn(bytes memory route, address to, uint256 amountIn, uint256 amountOutMin, uint256 deadline)
        external
        payable
        returns (uint256, uint256)
    {
        _checkDeadline(deadline);
        _checkRecipient(to);

        (address[] memory pairs, uint256[] memory ids, address[] memory tokens) = _getPairsAndIds(route);

        _transfer(tokens[0], msg.sender, pairs[0], amountIn);

        address lastToken = tokens[pairs.length];
        address recipient = lastToken == address(0) ? address(this) : to;

        uint256 amountOut;
        {
            uint256 balanceBefore = _balanceOf(lastToken, recipient);
            _swapExactIn(recipient, pairs, ids, amountIn);
            uint256 balanceAfter = _balanceOf(lastToken, recipient);

            if (balanceBefore + amountOutMin > balanceAfter) revert Router__InsufficientOutputAmount();
            amountOut = balanceAfter - balanceBefore;
        }

        if (recipient == address(this)) _transfer(lastToken, recipient, to, amountOut);

        if (msg.value > 0) {
            uint256 leftOver = address(this).balance;
            if (leftOver > 0) {
                _transferNative(msg.sender, leftOver);
            }
        }

        return (amountIn, amountOut);
    }

    /**
     * @dev Swaps the exact amount of tokens in the route for the maximum amount of tokens out supporting fee-on-transfer tokens.
     * Will always make sure that the user receives at least `amountOutMin` tokens.
     * @param route The packed route of the tokens to be swapped.
     * @param to The address to which the tokens will be transferred.
     * @param amountIn The amount of tokens to be swapped.
     * @param amountOutMin The minimum amount of tokens to be received.
     * @param deadline The deadline by which the transaction must be executed.
     * @return The amount of tokens in and out.
     */
    function swapExactInSupportingFeeOnTransferTokens(
        bytes memory route,
        address to,
        uint256 amountIn,
        uint256 amountOutMin,
        uint256 deadline
    ) external payable returns (uint256, uint256) {
        _checkDeadline(deadline);
        _checkRecipient(to);

        (address[] memory pairs, uint256[] memory ids, address[] memory tokens) = _getPairsAndIds(route);

        address token = tokens[0];
        address recipient = pairs[0];

        uint256 effectiveAmountIn;
        {
            uint256 balanceBefore = _balanceOf(token, recipient);
            _transfer(token, msg.sender, recipient, amountIn);
            effectiveAmountIn = _balanceOf(token, recipient) - balanceBefore;
        }

        token = tokens[pairs.length];
        recipient = token == address(0) ? address(this) : to;

        uint256 amountOut = _swapExactInSupportingFeeOnTransferTokens(recipient, pairs, ids, tokens, effectiveAmountIn);

        if (amountOut < amountOutMin) revert Router__InsufficientOutputAmount();

        if (recipient == address(this)) _transfer(token, recipient, to, amountOut);

        if (msg.value > 0) {
            uint256 leftOver = address(this).balance;
            if (leftOver > 0) {
                _transferNative(msg.sender, leftOver);
            }
        }

        return (amountIn, amountOut);
    }

    /**
     * @dev Swaps the minimum amount of tokens in the route for the exact (or greater) amount of tokens out.
     * Will always make sure that the user swaps at most `amountInMax` tokens.
     * @param route The packed route of the tokens to be swapped.
     * @param to The address to which the tokens will be transferred.
     * @param amountOut The amount of tokens to be received.
     * @param amountInMax The maximum amount of tokens to be swapped.
     * @param deadline The deadline by which the transaction must be executed.
     * @return The amount of tokens in and out.
     */
    function swapExactOut(bytes memory route, address to, uint256 amountOut, uint256 amountInMax, uint256 deadline)
        external
        payable
        returns (uint256, uint256)
    {
        _checkDeadline(deadline);
        _checkRecipient(to);

        (address[] memory pairs, uint256[] memory ids, address[] memory tokens) = _getPairsAndIds(route);
        uint256[] memory amounts = _getAmounts(pairs, ids, tokens, amountOut);

        uint256 amountIn = amounts[0];

        if (amountIn > amountInMax) revert Router__ExceedsMaxInputAmount();

        _transfer(tokens[0], msg.sender, pairs[0], amountIn);

        address lastToken = tokens[pairs.length];
        address recipient = lastToken == address(0) ? address(this) : to;

        {
            uint256 balanceBefore = _balanceOf(lastToken, recipient);
            _swapExactOut(recipient, pairs, ids, amounts);
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

    /**
     * @dev Checks if the deadline has passed.
     * @param deadline The deadline by which the transaction must be executed.
     */
    function _checkDeadline(uint256 deadline) internal view {
        if (deadline < block.timestamp) revert Router__ExceedsDeadline();
    }

    /**
     * @dev Checks if the recipient is not the contract itself.
     * @param recipient The address to check.
     */
    function _checkRecipient(address recipient) internal view {
        if (recipient == address(this)) revert Router__InvalidRecipient();
    }

    /**
     * @dev Get the pairs and ids of the route.
     * @param route The packed route of the tokens to be swapped.
     * @return pairs The pairs of the route.
     * @return ids The ids of the route.
     * @return tokens The tokens of the route.
     */
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

    /**
     * @dev Get the amounts in of the route.
     * @param pairs The pairs of the route.
     * @param ids The ids of the route.
     * @param tokens The tokens of the route.
     * @param amount The amount of tokens to be swapped.
     * @return amounts The amounts of the route.
     */
    function _getAmounts(address[] memory pairs, uint256[] memory ids, address[] memory tokens, uint256 amount)
        internal
        view
        returns (uint256[] memory amounts)
    {
        uint256 length = tokens.length;
        amounts = new uint256[](length);

        uint256 i = length - 1;
        amounts[i] = amount;

        for (; i > 0;) {
            (uint256 v, uint256 sv, uint256 t) = PackedRoute.decodeId(ids[--i]);
            address pair = pairs[i];

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

    /**
     * @dev Swaps the exact amount of tokens in the route for the maximum amount of tokens out.
     * @param to The address to which the tokens will be transferred.
     * @param pairs The pairs of the route.
     * @param ids The ids of the route.
     * @param amount The amount of tokens to be swapped.
     */
    function _swapExactIn(address to, address[] memory pairs, uint256[] memory ids, uint256 amount) internal {
        uint256 length = pairs.length;
        address pair = pairs[0];

        for (uint256 i; i < length;) {
            (uint256 v, uint256 sv, uint256 t) = PackedRoute.decodeId(ids[i]);
            address recipient = ++i == length ? to : pairs[i];

            amount = _swap(pair, recipient, amount, v, sv, t);

            pair = recipient;
        }
    }

    /**
     * @dev Swaps the exact amount of tokens in the route for the maximum amount of tokens out supporting fee-on-transfer tokens.
     * @param to The address to which the tokens will be transferred.
     * @param pairs The pairs of the route.
     * @param ids The ids of the route.
     * @param tokens The tokens of the route.
     * @param amount The amount of tokens to be swapped.
     * @return The amount of tokens out.
     */
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

    /**
     * @dev Swaps the minimum amount of tokens in the route for the exact (or greater) amount of tokens out.
     * @param to The address to which the tokens will be transferred.
     * @param pairs The pairs of the route.
     * @param ids The ids of the route.
     * @param amounts The amounts of the route.
     */
    function _swapExactOut(address to, address[] memory pairs, uint256[] memory ids, uint256[] memory amounts)
        internal
    {
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

    /**
     * @dev Swaps the tokens in the pair.
     * @param pair The pair to swap the tokens in.
     * @param recipient The address to which the tokens will be transferred.
     * @param amount The amount of tokens to be swapped.
     * @param v The version of the pair contract.
     * @param sv The sub-version of the pair contract.
     * @param t The type of the pair contract.
     * @return The amount of tokens out.
     */
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

    /**
     * @dev Get the balance of the account.
     * If the token is `address(0)`, it will return the native balance. Otherwise, it will return the token balance.
     * @param token The token to get the balance of.
     * @param account The account to get the balance of.
     * @return The balance of the account.
     */
    function _balanceOf(address token, address account) internal view returns (uint256) {
        if (token == address(0)) {
            return _wnative.balanceOf(account);
        } else {
            return IERC20(token).balanceOf(account);
        }
    }

    /**
     * @dev Transfers `amount` of `token` from `from` to `to`.
     * If `token` is `address(0)`, it will transfer the native token.
     * @param token The token to transfer.
     * @param from The account to transfer the token from.
     * @param to The account to transfer the token to.
     * @param amount The amount of tokens to transfer.
     */
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
            IERC20(token).safeTransferFrom(from, to, amount);
        }
    }

    /**
     * @dev Transfers `amount` of native tokens to `to`.
     * @param to The account to transfer the native tokens to.
     * @param amount The amount of native tokens to transfer.
     */
    function _transferNative(address to, uint256 amount) internal {
        (bool success,) = to.call{value: amount}(new bytes(0));
        if (!success) revert Router__NativeTransferFailed();
    }
}
