// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import {ICliffVestingContract} from "./interfaces/ICliffVestingContract.sol";

/**
 * @title Cliff Vesting Contract
 * @dev This contract implements a vesting contract. Only the owner of the factory contract can set the beneficiary
 * and only the beneficiary can release the vested tokens.
 * The vesting contract can be revoked by the owner of the factory contract.
 * The vesting schedule is as follows:
 * - tokens vest linearly from the `start` to the `start + vestingDuration` timestamp
 * - vested tokens can only be claimed after the `start + lockDuration` timestamp
 */
contract CliffVestingContract is ICliffVestingContract, ReentrancyGuard {
    using SafeERC20 for IERC20;

    mapping(address token => VestingSchedule[]) private _vestingSchedules;

    /**
     * @dev Returns the number of vestings of the specified token.
     * @param token The address of the token.
     * @return The number of vesting schedules of the specified token.
     */
    function getNumberOfVestings(address token) public view override returns (uint256) {
        return _vestingSchedules[token].length;
    }

    /**
     * @dev Returns the vesting schedule of the specified token at the specified index.
     * @param token The address of the token.
     * @param index The index of the vesting schedule.
     * @return The vesting schedule of the specified token at the specified index.
     */
    function getVestingSchedule(address token, uint256 index) public view override returns (VestingSchedule memory) {
        return _vestingSchedules[token][index];
    }

    /**
     * @dev Returns the amount of tokens that can be released by the specified token at the specified index at the
     * specified timestamp.
     * @param token The address of the token.
     * @param index The index of the vesting schedule.
     * @param timestamp The timestamp at which the amount of releasable tokens will be calculated.
     * @return The amount of tokens that can be released by the specified token at the specified index at the
     */
    function getVestedAmount(address token, uint256 index, uint256 timestamp) public view override returns (uint256) {
        VestingSchedule storage vesting = _vestingSchedules[token][index];

        return _vestingSchedule(vesting.total, vesting.start, vesting.cliffDuration, vesting.vestingDuration, timestamp);
    }

    /**
     * @dev Returns the amount of tokens that can be released by the specified token at the specified index.
     * @param token The address of the token.
     * @param index The index of the vesting schedule.
     * @return The amount of tokens that can be released by the specified token at the specified index.
     */
    function getReleasableAmount(address token, uint256 index) public view override returns (uint256) {
        return getVestedAmount(token, index, block.timestamp) - _vestingSchedules[token][index].released;
    }

    /**
     * @dev Creates a new vesting schedule for the specified token and beneficiary.
     * @param token The address of the token.
     * @param amount The total amount of tokens to be vested.
     * @param minAmount The minimum amount of tokens to be received.
     * @param start The timestamp at which the vesting starts.
     * @param cliffDuration The duration of the cliff.
     * @param vestingDuration The duration of the vesting.
     */
    function createVestingSchedule(
        address token,
        address beneficiary,
        uint128 amount,
        uint128 minAmount,
        uint80 start,
        uint80 cliffDuration,
        uint80 vestingDuration
    ) public nonReentrant {
        if (cliffDuration > vestingDuration) revert CliffVestingContract__InvalidCliffDuration();
        if (start + vestingDuration <= block.timestamp) revert CliffVestingContract__InvalidVestingSchedule();
        if (minAmount == 0) revert CliffVestingContract__ZeroMinAmount();

        uint256 balance = IERC20(token).balanceOf(address(this));
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
        uint256 received = IERC20(token).balanceOf(address(this)) - balance;

        if (received < minAmount) revert CliffVestingContract__InsufficientAmountReceived(received, minAmount);

        uint256 index = _vestingSchedules[token].length;
        _vestingSchedules[token].push(VestingSchedule(beneficiary, amount, 0, start, cliffDuration, vestingDuration));

        emit VestingScheduleCreated(
            token, msg.sender, beneficiary, index, amount, start, cliffDuration, vestingDuration
        );
    }

    /**
     * @dev Releases the vested tokens for the specified token at the specified index for the sender.
     * @param token The address of the token.
     * @param index The index of the vesting schedule.
     */
    function release(address token, uint256 index) public nonReentrant {
        VestingSchedule storage vesting = _vestingSchedules[token][index];

        if (vesting.beneficiary != msg.sender) revert CliffVestingContract__OnlyBeneficiary();

        uint256 amount = getReleasableAmount(token, index);

        if (amount > 0) {
            vesting.released += uint128(amount);

            IERC20(token).safeTransfer(msg.sender, amount);

            emit Released(token, msg.sender, index, amount);
        }
    }

    /**
     * @dev Transfers the vesting schedule of the specified token and index to the new beneficiary.
     * @param newBeneficiary The address of the new beneficiary.
     */
    function transferVestingSchedule(address token, address newBeneficiary, uint256 index) public nonReentrant {
        VestingSchedule storage vesting = _vestingSchedules[token][index];

        if (vesting.beneficiary != msg.sender) revert CliffVestingContract__OnlyBeneficiary();

        vesting.beneficiary = newBeneficiary;

        emit VestingScheduleTransferred(token, msg.sender, newBeneficiary, index);
    }

    /**
     * @dev Calculates the amount of tokens that have been vested at the specified timestamp without taking into account
     * whether the vesting contract has a cliff or has been revoked.
     * @param total The total amount of tokens to be vested.
     * @param start The timestamp at which the vesting starts.
     * @param vestingDuration The duration of the vesting.
     * @param timestamp The timestamp at which the amount of vested tokens will be calculated.
     * @return The amount of tokens that have been vested at the specified timestamp.
     */
    function _vestingSchedule(
        uint256 total,
        uint256 start,
        uint256 cliffDuration,
        uint256 vestingDuration,
        uint256 timestamp
    ) internal view virtual returns (uint256) {
        unchecked {
            if (timestamp <= start + cliffDuration) {
                return 0;
            } else if (timestamp >= start + vestingDuration) {
                return total;
            } else {
                return (total * (timestamp - start)) / vestingDuration;
            }
        }
    }
}
