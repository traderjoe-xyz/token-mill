// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

library Math {
    error Math__UnderOverflow();
    error Math__DivisionByZero();

    uint256 internal constant MAX_INT256 = 0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff;

    function addDelta(uint256 x, int256 delta) internal pure returns (uint256 y) {
        uint256 success;

        assembly {
            y := add(x, delta)

            success := iszero(or(gt(x, MAX_INT256), gt(y, MAX_INT256)))
        }

        if (success == 0) revert Math__UnderOverflow();
    }

    function sub(uint256 x, uint256 y) internal pure returns (int256 delta) {
        uint256 success;

        assembly {
            delta := sub(x, y)

            success := iszero(or(gt(x, MAX_INT256), gt(y, MAX_INT256)))
        }

        if (success == 0) revert Math__UnderOverflow();
    }

    function mostSignificantBit(uint256 x) internal pure returns (uint256 msb) {
        assembly {
            let n := mul(128, gt(x, 0xffffffffffffffffffffffffffffffff))
            x := shr(n, x)
            msb := add(msb, n)

            n := mul(64, gt(x, 0xffffffffffffffff))
            x := shr(n, x)
            msb := add(msb, n)

            n := mul(32, gt(x, 0xffffffff))
            x := shr(n, x)
            msb := add(msb, n)

            n := mul(16, gt(x, 0xffff))
            x := shr(n, x)
            msb := add(msb, n)

            n := mul(8, gt(x, 0xff))
            x := shr(n, x)
            msb := add(msb, n)

            n := mul(4, gt(x, 0xf))
            x := shr(n, x)
            msb := add(msb, n)

            n := mul(2, gt(x, 0x3))
            x := shr(n, x)
            msb := add(msb, n)

            msb := add(msb, gt(x, 0x1))
        }
    }

    /**
     * @notice Calculates the square root of x
     * @dev Credit to OpenZeppelin's Math library under MIT license
     */
    function sqrt(uint256 x, bool roundUp) internal pure returns (uint256 sqrtX) {
        if (x == 0) return 0;

        uint256 msb = mostSignificantBit(x);

        assembly {
            sqrtX := shl(shr(1, msb), 1)

            sqrtX := shr(1, add(sqrtX, div(x, sqrtX)))
            sqrtX := shr(1, add(sqrtX, div(x, sqrtX)))
            sqrtX := shr(1, add(sqrtX, div(x, sqrtX)))
            sqrtX := shr(1, add(sqrtX, div(x, sqrtX)))
            sqrtX := shr(1, add(sqrtX, div(x, sqrtX)))
            sqrtX := shr(1, add(sqrtX, div(x, sqrtX)))
            sqrtX := shr(1, add(sqrtX, div(x, sqrtX)))

            sqrtX := sub(sqrtX, gt(sqrtX, div(x, sqrtX)))
            sqrtX := add(sqrtX, mul(iszero(iszero(roundUp)), lt(mul(sqrtX, sqrtX), x)))
        }
    }

    function min(uint256 x, uint256 y) internal pure returns (uint256 r) {
        return x < y ? x : y;
    }

    function max(uint256 x, uint256 y) internal pure returns (uint256 r) {
        return x > y ? x : y;
    }

    function abs(int256 x) internal pure returns (uint256 r) {
        return x < 0 ? uint256(-x) : uint256(x);
    }

    function div(uint256 x, uint256 y, bool roundUp) internal pure returns (uint256 z) {
        if (y == 0) revert Math__DivisionByZero();

        assembly {
            z := add(div(x, y), iszero(or(iszero(mod(x, y)), iszero(roundUp))))
        }
    }

    function div(int256 x, int256 y, bool roundUp) internal pure returns (int256 z) {
        if (y == 0) revert Math__DivisionByZero();

        assembly {
            switch roundUp
            case 0 { z := sdiv(x, y) }
            default {
                switch sgt(x, 0)
                    // todo optimize
                case 0 { z := sub(sdiv(x, y), iszero(iszero(smod(x, y)))) }
                default { z := add(sdiv(x, y), iszero(iszero(smod(x, y)))) }
            }
        }
    }

    /**
     * @notice Calculates floor(x*y/denominator) with full precision
     * The result will be rounded following the roundUp parameter
     * @dev Credit to Remco Bloemen under MIT license https://xn--2-umb.com/21/muldiv
     * Requirements:
     * - The denominator cannot be zero
     * - The result must fit within uint256
     * Caveats:
     * - This function does not work with fixed-point numbers
     * @param x The multiplicand as an uint256
     * @param y The multiplier as an uint256
     * @param denominator The divisor as an uint256
     * @return result The result as an uint256
     */
    function mulDiv(uint256 x, uint256 y, uint256 denominator, bool roundUp) internal pure returns (uint256 result) {
        if (denominator == 0) revert Math__DivisionByZero();

        // 512-bit multiply [prod1 prod0] = x * y. Compute the product mod 2^256 and mod 2^256 - 1, then use
        // use the Chinese Remainder Theorem to reconstruct the 512 bit result. The result is stored in two 256
        // variables such that product = prod1 * 2^256 + prod0.
        assembly {
            let mm := mulmod(x, y, not(0))
            let prod0 := mul(x, y)
            let prod1 := sub(sub(mm, prod0), lt(mm, prod0))

            // Handle non-overflow cases, 256 by 256 division
            switch iszero(prod1)
            case 1 {
                result := div(prod0, denominator)

                if roundUp { result := add(result, iszero(iszero(mod(prod0, denominator)))) }
            }
            default {
                // Make sure the result is less than 2^256. Also prevents denominator == 0
                if iszero(lt(prod1, denominator)) {
                    mstore(0x00, 0x11528576)
                    revert(0x1c, 0x04) // revert with Math__UnderOverflow
                }

                // Make division exact by subtracting the remainder from [prod1 prod0].
                // Compute remainder using mulmod.
                let remainder := mulmod(x, y, denominator)

                // Subtract 256 bit number from 512 bit number.
                prod1 := sub(prod1, gt(remainder, prod0))
                prod0 := sub(prod0, remainder)

                // Factor powers of two out of denominator and compute largest power of two divisor of denominator. Always >= 1
                // See https://cs.stackexchange.com/q/138556/92363
                let lpotdod := and(denominator, sub(0, denominator))

                // Divide denominator by lpotdod.
                denominator := div(denominator, lpotdod)

                // Divide [prod1 prod0] by lpotdod.
                prod0 := div(prod0, lpotdod)

                // Flip lpotdod such that it is 2^256 / lpotdod. If lpotdod is zero, then it becomes one
                lpotdod := add(div(sub(0, lpotdod), lpotdod), 1)

                // Shift in bits from prod1 into prod0
                prod0 := or(prod0, mul(prod1, lpotdod))

                // Invert denominator mod 2^256. Now that denominator is an odd number, it has an inverse modulo 2^256 such
                // that denominator * inv = 1 mod 2^256. Compute the inverse by starting with a seed that is correct for
                // four bits. That is, denominator * inv = 1 mod 2^4
                let inverse := xor(mul(3, denominator), 2)

                // Use the Newton-Raphson iteration to improve the precision. Thanks to Hensel's lifting lemma, this also works
                // in modular arithmetic, doubling the correct bits in each step
                inverse := mul(inverse, sub(2, mul(denominator, inverse))) // inverse mod 2^8
                inverse := mul(inverse, sub(2, mul(denominator, inverse))) // inverse mod 2^16
                inverse := mul(inverse, sub(2, mul(denominator, inverse))) // inverse mod 2^32
                inverse := mul(inverse, sub(2, mul(denominator, inverse))) // inverse mod 2^64
                inverse := mul(inverse, sub(2, mul(denominator, inverse))) // inverse mod 2^128
                inverse := mul(inverse, sub(2, mul(denominator, inverse))) // inverse mod 2^256

                // Because the division is now exact we can divide by multiplying with the modular inverse of denominator.
                // This will give us the correct result modulo 2^256. Since the preconditions guarantee that the outcome is
                // less than 2^256, this is the final result. We don't need to compute the high bits of the result and prod1
                // is no longer required.
                result := mul(prod0, inverse)
            }
        }
    }

    /**
     * @notice Calculates floor(x * y / 2**offset) with full precision
     * The result will be rounded following the roundUp parameter
     * @dev Credit to Remco Bloemen under MIT license https://xn--2-umb.com/21/muldiv
     * Requirements:
     * - The offset needs to be strictly lower than 256
     * - The result must fit within uint256
     * Caveats:
     * - This function does not work with fixed-point numbers
     * @param x The multiplicand as an uint256
     * @param y The multiplier as an uint256
     * @param offset The offset as an uint256, can't be greater than 256
     * @param roundUp Whether to round up or down
     * @return result The result as an uint256
     */
    function mulShift(uint256 x, uint256 y, uint8 offset, bool roundUp) internal pure returns (uint256 result) {
        // 512-bit multiply [prod1 prod0] = x * y. Compute the product mod 2^256 and mod 2^256 - 1, then use
        // use the Chinese Remainder Theorem to reconstruct the 512 bit result. The result is stored in two 256
        // variables such that product = prod1 * 2^256 + prod0.
        assembly {
            let mm := mulmod(x, y, not(0))
            let prod0 := mul(x, y)
            let prod1 := sub(sub(mm, prod0), lt(mm, prod0))

            if prod0 {
                let rounding := iszero(iszero(roundUp))

                result := add(shr(offset, sub(prod0, rounding)), rounding)
            }

            if prod1 {
                // Make sure the result is less than 2^256.
                if shr(offset, prod1) {
                    mstore(0x00, 0x11528576)
                    revert(0x1c, 0x04) // revert with Math__UnderOverflow
                }

                result := add(result, shl(sub(256, offset), prod1))
            }
        }
    }
}
