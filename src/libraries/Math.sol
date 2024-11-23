// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title Math Library
 * @dev A library for performing various math operations
 */
library Math {
    error Math__UnderOverflow();
    error Math__DivisionByZero();

    uint256 internal constant MAX_INT256 = 0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff;

    /**
     * @notice Adds a uint256 to an int256 with overflow and underflow protection
     * @param x The first number, as uint256
     * @param delta The second number, as int256
     * @return y The sum of the two numbers, as uint256
     */
    function addDelta(uint256 x, int256 delta) internal pure returns (uint256 y) {
        uint256 success;

        assembly ("memory-safe") {
            y := add(x, delta)

            success := iszero(or(gt(x, MAX_INT256), gt(y, MAX_INT256)))
        }

        if (success == 0) revert Math__UnderOverflow();
    }

    /**
     * @notice Returns the most significant bit of x
     * @dev Credit to OpenZeppelin's Math library under MIT license
     * @param x The number to find the most significant bit of
     * @return msb The most significant bit of x
     */
    function mostSignificantBit(uint256 x) internal pure returns (uint256 msb) {
        assembly ("memory-safe") {
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
     * @param x The number to find the square root of
     * @param roundUp Whether to round up the result
     * @return sqrtX The square root of x
     */
    function sqrt(uint256 x, bool roundUp) internal pure returns (uint256 sqrtX) {
        if (x == 0) return 0;

        uint256 msb = mostSignificantBit(x);

        assembly ("memory-safe") {
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

    /**
     * @notice Returns the minimum of two numbers
     * @param x The first number
     * @param y The second number
     * @return r The minimum of the two numbers
     */
    function min(uint256 x, uint256 y) internal pure returns (uint256 r) {
        assembly ("memory-safe") {
            r := xor(y, mul(xor(x, y), lt(x, y)))
        }
    }

    /**
     * @notice Returns the maximum of two numbers
     * @param x The first number
     * @param y The second number
     * @return r The maximum of the two numbers
     */
    function max(uint256 x, uint256 y) internal pure returns (uint256 r) {
        assembly ("memory-safe") {
            r := xor(y, mul(xor(x, y), gt(x, y)))
        }
    }

    /**
     * @notice Returns the absolute value of x
     * @param x The number to find the absolute value of
     * @return r The absolute value of x
     */
    function abs(int256 x) internal pure returns (uint256 r) {
        assembly ("memory-safe") {
            let mask := sar(255, x)
            r := xor(add(x, mask), mask)
        }
    }

    /**
     * @notice Calculates x/y rounding up if roundUp is true
     * @param x The numerator as an uint256
     * @param y The denominator as an uint256
     * @param roundUp Whether to round up the result
     * @return z The result as an uint256
     */
    function div(uint256 x, uint256 y, bool roundUp) internal pure returns (uint256 z) {
        if (y == 0) revert Math__DivisionByZero();

        assembly ("memory-safe") {
            z := add(div(x, y), iszero(or(iszero(mod(x, y)), iszero(roundUp))))
        }
    }

    /**
     * @notice Calculates `x*y/denominator` with full precision and rounding up (if roundUp is true) or down (if roundUp is false)
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
        // the Chinese Remainder Theorem to reconstruct the 512 bit result. The result is stored in two 256
        // variables such that product = prod1 * 2^256 + prod0.
        assembly ("memory-safe") {
            let mm := mulmod(x, y, not(0))
            let prod0 := mul(x, y)
            let prod1 := sub(sub(mm, prod0), lt(mm, prod0))

            // Handle non-overflow cases, 256 by 256 division
            switch iszero(prod1)
            case 1 {
                result := add(div(prod0, denominator), iszero(or(iszero(mod(prod0, denominator)), iszero(roundUp))))
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
                let resultRoundedDown := mul(prod0, inverse)
                result := add(resultRoundedDown, iszero(or(iszero(remainder), iszero(roundUp))))

                // Check if the result didn't overflow
                if lt(result, resultRoundedDown) {
                    mstore(0x00, 0x11528576)
                    revert(0x1c, 0x04) // revert with Math__UnderOverflow
                }
            }
        }
    }

    /**
     * @notice Calculates `x * y` as a 512 bit number
     * @param x The first number
     * @param y The second number
     * @return z0 The lower 256 bits of the result
     * @return z1 The higher 256 bits of the result
     */
    function mul512(uint256 x, uint256 y) internal pure returns (uint256 z0, uint256 z1) {
        assembly ("memory-safe") {
            let mm := mulmod(x, y, not(0))
            z0 := mul(x, y)
            z1 := sub(sub(mm, z0), lt(mm, z0))
        }
    }

    /**
     * @notice Adds two 512 bit numbers with overflow protection
     * @param x0 The lower 256 bits of the first number
     * @param x1 The higher 256 bits of the first number
     * @param y0 The lower 256 bits of the second number
     * @param y1 The higher 256 bits of the second number
     * @return z0 The lower 256 bits of the sum
     * @return z1 The higher 256 bits of the sum
     */
    function add512(uint256 x0, uint256 x1, uint256 y0, uint256 y1) internal pure returns (uint256 z0, uint256 z1) {
        uint256 success;

        assembly ("memory-safe") {
            let rz1 := add(x1, y1)

            z0 := add(x0, y0)
            z1 := add(rz1, lt(z0, x0))

            success := iszero(or(lt(rz1, x1), lt(z1, rz1))) // rz1 >= x1 && z1 >= rz1
        }

        if (success == 0) revert Math__UnderOverflow();
    }

    /**
     * @dev Credit to SimonSuckut for the implementation of the Karatsuba Square Root method
     * See https://hal.inria.fr/inria-00072854/document for details.
     * n = x1 * 2^256 + x0
     * n = x1 * b^2 + x0
     * n = (a_3 * b + a_2) * b^2 + a_1 * b + a_0
     * n = a_3 * b^3 + a_2 * b^2 + a_1 * b + a_0
     * where `x1 = a_3 * b + a_2`, `x0 = a_1 * b + a_0` and `b = 2^128`
     * @param x0 The lower 256 bits of the number
     * @param x1 The higher 256 bits of the number
     * @param roundUp Whether to round up the result
     * @return s The square root of the number
     */
    function sqrt512(uint256 x0, uint256 x1, bool roundUp) internal pure returns (uint256 s) {
        if (x1 == 0) return sqrt(x0, roundUp);
        if (x1 == type(uint256).max) revert Math__UnderOverflow(); // max allowed is sqrt((2^256-1)^2), orelse round up would overflow

        uint256 mx0 = x0; // Cache x0

        uint256 shift;

        // Condition: a_3 >= b / 4
        // => x_1 >= b^2 / 4 = 2^254
        assembly ("memory-safe") {
            let n := mul(lt(x1, 0x100000000000000000000000000000000), 128)
            x1 := shl(n, x1)
            shift := n

            n := mul(lt(x1, 0x1000000000000000000000000000000000000000000000000), 64)
            x1 := shl(n, x1)
            shift := add(shift, n)

            n := mul(lt(x1, 0x100000000000000000000000000000000000000000000000000000000), 32)
            x1 := shl(n, x1)
            shift := add(shift, n)

            n := mul(lt(x1, 0x1000000000000000000000000000000000000000000000000000000000000), 16)
            x1 := shl(n, x1)
            shift := add(shift, n)

            n := mul(lt(x1, 0x100000000000000000000000000000000000000000000000000000000000000), 8)
            x1 := shl(n, x1)
            shift := add(shift, n)

            n := mul(lt(x1, 0x1000000000000000000000000000000000000000000000000000000000000000), 4)
            x1 := shl(n, x1)
            shift := add(shift, n)

            n := mul(lt(x1, 0x4000000000000000000000000000000000000000000000000000000000000000), 2)
            x1 := shl(n, x1)
            shift := add(shift, n)

            x1 := or(x1, shr(sub(256, shift), x0))
            x0 := shl(shift, x0)
        }

        uint256 sp = sqrt(x1, false); // s' = sqrt(x1)

        assembly ("memory-safe") {
            let rp := sub(x1, mul(sp, sp)) // r' = x1 - s^2

            let nom := or(shl(128, rp), shr(128, x0)) // r'b + a_1
            let denom := shl(1, sp) // 2s'
            let q := div(nom, denom) // q = floor(nom / denom)
            let u := mod(nom, denom) // u = nom % denom

            {
                // The nominator can be bigger than 2**256. We know that rp < (sp+1) * (sp+1). As sp can be
                // at most floor(sqrt(2**256 - 1)) we can conclude that the nominator has at most 257 bits
                // set. An expensive 512x256 bit division can be avoided by treating the bit at position 257 manually
                let carry := shr(128, rp)
                let x := mul(carry, 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff)
                q := add(q, div(x, denom))
                u := add(u, add(carry, mod(x, denom)))
                q := add(q, div(u, denom))
                u := mod(u, denom)

                s := add(shl(128, sp), q) // s'b + q
            }

            // r = u'b + a_0 - q^2
            // r = (u_1 * b + u_0) * b + a_0 - (q_1 * b + q_0)^2
            // r = u_1 * b^2 + u_0 * b + a_0 - q_1^2 * b^2 - 2 * q_1 * q_0 * b - q_0^2
            // r < 0 <=> u_1 < q_1 or (u_1 == q_1 and u_0 * b + a_0 - 2 * q_1 * q_0 * b - q_0^2)
            let rl := or(shl(128, u), and(x0, 0xffffffffffffffffffffffffffffffff)) // u_0 *b + a_0
            let rr := mul(q, q) // q^2
            let q1 := shr(128, q)
            let u1 := shr(128, u)
            s := sub(s, or(lt(u1, q1), and(eq(u1, q1), lt(rl, rr)))) // if r < 0 { s -= 1 }
            s := shr(shr(1, shift), s) // s >>= (shift / 2)

            s := add(s, iszero(or(eq(mul(s, s), mx0), iszero(roundUp)))) // round up if necessary
        }
    }
}
