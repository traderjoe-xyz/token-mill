// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";

import {ImmutableHelper} from "../../src/libraries/ImmutableHelper.sol";
import {MockERC20} from "../mocks/MockERC20.sol";

contract ImmutableHelperTest is Test {
    function test_Fuzz_PackPrices(uint256[] memory bidPrices, uint256[] memory askPrices) public pure {
        uint256 length = bidPrices.length < askPrices.length ? bidPrices.length : askPrices.length;
        length = length > ImmutableHelper.MAX_LENGTH ? ImmutableHelper.MAX_LENGTH : length;

        vm.assume(length >= ImmutableHelper.MIN_LENGTH);

        assembly ("memory-safe") {
            mstore(bidPrices, length)
            mstore(askPrices, length)
        }

        uint256 lastBidPrice = bidPrices[0];
        uint256 lastAskPrice = askPrices[0];

        for (uint256 i = 0; i < length; i++) {
            uint256 currentBidPrice = bidPrices[i];
            uint256 currentAskPrice = askPrices[i];

            currentAskPrice =
                bound(currentAskPrice, i == 0 ? 0 : lastAskPrice + 1, ImmutableHelper.MAX_PRICE - (length - 1 - i));
            currentBidPrice = bound(currentBidPrice, i == 0 ? 0 : lastBidPrice + 1, currentAskPrice);

            lastAskPrice = currentAskPrice;
            lastBidPrice = currentBidPrice;

            askPrices[i] = currentAskPrice;
            bidPrices[i] = currentBidPrice;
        }

        uint256[] memory packedPrices = ImmutableHelper.packPrices(bidPrices, askPrices);

        assertEq(packedPrices.length, length, "test_Fuzz_PackPrices::1");

        for (uint256 j = 0; j < length; j++) {
            uint256 packedPrice = packedPrices[j];

            uint256 askPrice = packedPrice >> 128;
            uint256 bidPrice = packedPrice & type(uint128).max;

            assertEq(askPrice, askPrices[j], "test_Fuzz_PackPrices::2");
            assertEq(bidPrice, bidPrices[j], "test_Fuzz_PackPrices::3");
        }
    }

    function test_Fuzz_Revert_PackPrices(uint256[] memory bidPrices, uint256[] memory askPrices) public {
        uint256 lengthAsk = askPrices.length;
        uint256 lengthBid = bidPrices.length;

        vm.assume(lengthBid >= ImmutableHelper.MIN_LENGTH && lengthAsk >= ImmutableHelper.MIN_LENGTH);

        assembly ("memory-safe") {
            mstore(bidPrices, add(lengthAsk, 1))
        }

        vm.expectRevert(
            abi.encodeWithSelector(ImmutableHelper.ImmutableHelper__InvalidLength.selector, lengthAsk + 1, lengthAsk)
        );
        ImmutableHelper.packPrices(bidPrices, askPrices);

        uint256 length = bound(lengthBid, 0, ImmutableHelper.MIN_LENGTH - 1);
        assembly ("memory-safe") {
            mstore(bidPrices, length)
            mstore(askPrices, length)
        }

        vm.expectRevert(abi.encodeWithSelector(ImmutableHelper.ImmutableHelper__InvalidLength.selector, length, length));
        ImmutableHelper.packPrices(bidPrices, askPrices);

        length = bound(lengthBid, ImmutableHelper.MAX_LENGTH + 1, type(uint256).max);
        assembly ("memory-safe") {
            mstore(bidPrices, length)
            mstore(askPrices, length)
        }

        vm.expectRevert(abi.encodeWithSelector(ImmutableHelper.ImmutableHelper__InvalidLength.selector, length, length));
        ImmutableHelper.packPrices(bidPrices, askPrices);

        length = lengthBid < lengthAsk ? lengthBid : lengthAsk;
        length = length > ImmutableHelper.MAX_LENGTH ? ImmutableHelper.MAX_LENGTH : length;

        assembly ("memory-safe") {
            mstore(bidPrices, length)
            mstore(askPrices, length)
        }

        uint256 lastBidPrice = bidPrices[0];
        uint256 lastAskPrice = askPrices[0];

        for (uint256 i = 0; i < length; i++) {
            uint256 currentBidPrice = bidPrices[i];
            uint256 currentAskPrice = askPrices[i];

            currentAskPrice = bound(currentAskPrice, lastAskPrice + 1, ImmutableHelper.MAX_PRICE - (length - i));
            currentBidPrice = bound(currentBidPrice, lastBidPrice + 1, currentAskPrice);

            lastAskPrice = currentAskPrice;
            lastBidPrice = currentBidPrice;

            askPrices[i] = currentAskPrice;
            bidPrices[i] = currentBidPrice;
        }

        uint256 index = bound(length, 0, length - 1);

        uint256 askPrice = askPrices[index];
        askPrices[index] = bidPrices[index] - 1;

        vm.expectRevert(
            abi.encodeWithSelector(
                ImmutableHelper.ImmutableHelper__BidAskMismatch.selector, index, bidPrices[index], askPrices[index]
            )
        );
        ImmutableHelper.packPrices(bidPrices, askPrices);

        askPrices[index] = askPrice;

        index = bound(length, 1, length - 1);

        askPrices[index - 1] = askPrices[index] + 1;

        vm.expectRevert(abi.encodeWithSelector(ImmutableHelper.ImmutableHelper__OnlyIncreasingPrices.selector, index));
        ImmutableHelper.packPrices(bidPrices, askPrices);

        askPrices[index - 1] = askPrices[index] - 1;

        bidPrices[index - 1] = bidPrices[index] + 1;

        vm.expectRevert(abi.encodeWithSelector(ImmutableHelper.ImmutableHelper__OnlyIncreasingPrices.selector, index));
        ImmutableHelper.packPrices(bidPrices, askPrices);

        bidPrices[index - 1] = bidPrices[index] - 1;

        askPrices[length - 1] = bound(askPrices[length - 1], ImmutableHelper.MAX_PRICE + 1, type(uint256).max);

        vm.expectRevert(
            abi.encodeWithSelector(
                ImmutableHelper.ImmutableHelper__PriceTooHigh.selector, askPrices[length - 1], ImmutableHelper.MAX_PRICE
            )
        );
        ImmutableHelper.packPrices(bidPrices, askPrices);
    }

    function test_Fuzz_GetImmutableArgs(
        address factory,
        bytes32 baseSalt,
        uint8 baseDecimals,
        bytes32 quoteSalt,
        uint8 quoteDecimals,
        uint256 totalSupply,
        uint256[] memory packedPrices
    ) public {
        uint256 length = packedPrices.length;
        vm.assume(length >= ImmutableHelper.MIN_LENGTH && baseSalt != quoteSalt);

        length = length > ImmutableHelper.MAX_LENGTH ? ImmutableHelper.MAX_LENGTH : length;

        assembly ("memory-safe") {
            mstore(packedPrices, length)
        }

        uint256 nbIntervals = length - 1;

        baseDecimals = uint8(bound(baseDecimals, 0, ImmutableHelper.MAX_DECIMALS));
        quoteDecimals = uint8(bound(quoteDecimals, 0, ImmutableHelper.MAX_DECIMALS));

        address baseToken = address(new MockERC20{salt: baseSalt}("", "", baseDecimals));
        address quoteToken = address(new MockERC20{salt: quoteSalt}("", "", quoteDecimals));

        totalSupply =
            bound(totalSupply, nbIntervals * 10 ** baseDecimals, uint256(type(uint128).max) * 10 ** baseDecimals / 1e18);
        totalSupply = (totalSupply / nbIntervals) * nbIntervals;

        bytes memory immutableArgs =
            ImmutableHelper.getImmutableArgs(factory, baseToken, quoteToken, totalSupply, packedPrices);

        uint256 ptr;

        {
            address factory_;

            assembly ("memory-safe") {
                ptr := add(immutableArgs, 32)
                factory_ := shr(96, mload(ptr))
            }

            assertEq(factory_, factory, "test_Fuzz_GetImmutableArgs::1");
        }

        {
            address baseToken_;

            assembly ("memory-safe") {
                ptr := add(ptr, 20)
                baseToken_ := shr(96, mload(ptr))
            }

            assertEq(baseToken_, baseToken, "test_Fuzz_GetImmutableArgs::2");
        }

        {
            address quoteToken_;

            assembly ("memory-safe") {
                ptr := add(ptr, 20)
                quoteToken_ := shr(96, mload(ptr))
            }

            assertEq(quoteToken_, quoteToken, "test_Fuzz_GetImmutableArgs::3");
        }

        {
            uint256 basePrecision;

            assembly ("memory-safe") {
                ptr := add(ptr, 20)
                basePrecision := shr(192, mload(ptr))
            }

            assertEq(basePrecision, 10 ** baseDecimals, "test_Fuzz_GetImmutableArgs::4");
        }

        {
            uint256 quotePrecision;

            assembly ("memory-safe") {
                ptr := add(ptr, 8)
                quotePrecision := shr(192, mload(ptr))
            }
        }

        {
            uint256 totalSupply_;

            assembly ("memory-safe") {
                ptr := add(ptr, 8)
                totalSupply_ := shr(128, mload(ptr))
            }

            assertEq(totalSupply_, totalSupply, "test_Fuzz_GetImmutableArgs::5");
        }

        {
            uint256 widthScaled;

            assembly ("memory-safe") {
                ptr := add(ptr, 16)
                widthScaled := shr(128, mload(ptr))
            }

            assertEq(
                widthScaled, (totalSupply / nbIntervals) * 1e18 / 10 ** baseDecimals, "test_Fuzz_GetImmutableArgs::6"
            );
        }

        {
            uint256 length_;

            assembly ("memory-safe") {
                ptr := add(ptr, 16)
                length_ := shr(248, mload(ptr))
            }

            assertEq(length_, length, "test_Fuzz_GetImmutableArgs::7");
        }

        {
            assembly ("memory-safe") {
                ptr := add(ptr, 1)
            }

            for (uint256 i = 0; i < length; i++) {
                uint256 price;

                assembly ("memory-safe") {
                    price := mload(ptr)
                    ptr := add(ptr, 32)
                }

                assertEq(price, packedPrices[i], "test_Fuzz_GetImmutableArgs::8");
            }
        }
    }

    function test_Fuzz_Revert_GetImmutableArgs(
        address factory,
        bytes32 baseSalt,
        uint8 baseDecimals,
        bytes32 quoteSalt,
        uint8 quoteDecimals,
        uint256 totalSupply,
        uint256[] memory packedPrices
    ) public {
        uint256 length = packedPrices.length;
        vm.assume(length >= ImmutableHelper.MIN_LENGTH + 1);

        length = length > ImmutableHelper.MAX_LENGTH ? ImmutableHelper.MAX_LENGTH : length;

        {
            uint256 badLength = bound(length, 0, ImmutableHelper.MIN_LENGTH - 1);
            assembly ("memory-safe") {
                mstore(packedPrices, badLength)
            }

            vm.expectRevert(
                abi.encodeWithSelector(
                    ImmutableHelper.ImmutableHelper__LengthOutOfBounds.selector,
                    ImmutableHelper.MIN_LENGTH,
                    badLength,
                    ImmutableHelper.MAX_LENGTH
                )
            );
            ImmutableHelper.getImmutableArgs(factory, address(0), address(0), totalSupply, packedPrices);

            badLength = bound(length, ImmutableHelper.MAX_LENGTH + 1, type(uint256).max);
            assembly ("memory-safe") {
                mstore(packedPrices, badLength)
            }

            vm.expectRevert(
                abi.encodeWithSelector(
                    ImmutableHelper.ImmutableHelper__LengthOutOfBounds.selector,
                    ImmutableHelper.MIN_LENGTH,
                    badLength,
                    ImmutableHelper.MAX_LENGTH
                )
            );
            ImmutableHelper.getImmutableArgs(factory, address(0), address(0), totalSupply, packedPrices);
        }

        assembly ("memory-safe") {
            mstore(packedPrices, length)
        }

        uint256 nbIntervals = length - 1;

        uint8 wrongDecimals = uint8(bound(baseDecimals, ImmutableHelper.MAX_DECIMALS + 1, type(uint8).max));

        address baseToken = address(new MockERC20{salt: baseSalt}("", "", wrongDecimals));

        vm.expectRevert(
            abi.encodeWithSelector(
                ImmutableHelper.ImmutableHelper__InvalidDecimals.selector, wrongDecimals, wrongDecimals
            )
        );
        this.getImmutableArgs(factory, baseToken, baseToken, totalSupply, packedPrices);

        baseDecimals = uint8(bound(baseDecimals, 0, ImmutableHelper.MAX_DECIMALS));
        wrongDecimals = uint8(bound(quoteDecimals, ImmutableHelper.MAX_DECIMALS + 1, type(uint8).max));

        baseToken = address(new MockERC20{salt: baseSalt}("", "", baseDecimals));
        address quoteToken = address(new MockERC20{salt: quoteSalt}("", "", wrongDecimals));

        vm.expectRevert(
            abi.encodeWithSelector(
                ImmutableHelper.ImmutableHelper__InvalidDecimals.selector, baseDecimals, wrongDecimals
            )
        );
        this.getImmutableArgs(factory, baseToken, quoteToken, totalSupply, packedPrices);

        quoteDecimals = uint8(bound(quoteDecimals, 0, ImmutableHelper.MAX_DECIMALS));
        quoteToken = address(new MockERC20{salt: quoteSalt}("", "", quoteDecimals));

        uint256 badSupply = bound(totalSupply, 0, nbIntervals * 10 ** baseDecimals - 1);
        badSupply = (badSupply / nbIntervals) * nbIntervals;

        vm.expectRevert(
            abi.encodeWithSelector(ImmutableHelper.ImmutableHelper__InvalidTotalSupply.selector, badSupply, length - 1)
        );
        this.getImmutableArgs(factory, baseToken, quoteToken, badSupply, packedPrices);

        badSupply = bound(totalSupply, uint256(type(uint128).max) + 1, type(uint256).max);

        vm.expectRevert(
            abi.encodeWithSelector(ImmutableHelper.ImmutableHelper__InvalidTotalSupply.selector, badSupply, length - 1)
        );
        this.getImmutableArgs(factory, baseToken, quoteToken, badSupply, packedPrices);

        badSupply = bound(totalSupply, 0, uint256(type(uint128).max - 1) * 10 ** baseDecimals / 1e18);
        badSupply = uint128((badSupply / nbIntervals) * nbIntervals) + 1;

        vm.expectRevert(
            abi.encodeWithSelector(ImmutableHelper.ImmutableHelper__InvalidTotalSupply.selector, badSupply, length - 1)
        );
        this.getImmutableArgs(factory, baseToken, quoteToken, badSupply, packedPrices);

        badSupply = ((type(uint128).max - nbIntervals) / nbIntervals) * nbIntervals + nbIntervals;

        {
            uint8 lowDecimals = uint8(bound(baseDecimals, 0, 16));
            address lowDecimalsToken =
                address(new MockERC20{salt: keccak256(abi.encodePacked(baseSalt))}("", "", lowDecimals));

            vm.expectRevert(
                abi.encodeWithSelector(
                    ImmutableHelper.ImmutableHelper__InvalidWidthScaled.selector,
                    (badSupply / nbIntervals) * 1e18 / 10 ** lowDecimals
                )
            );
            this.getImmutableArgs(address(0), lowDecimalsToken, quoteToken, badSupply, packedPrices);
        }
    }

    function getImmutableArgs(
        address factory,
        address baseToken,
        address quoteToken,
        uint256 totalSupply,
        uint256[] memory packedPrices
    ) external view {
        ImmutableHelper.getImmutableArgs(factory, baseToken, quoteToken, totalSupply, packedPrices);
    }
}
