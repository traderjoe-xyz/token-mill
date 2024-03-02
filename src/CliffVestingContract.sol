// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

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
contract CliffVestingContract is ICliffVestingContract {
    using SafeERC20 for IERC20;

    address private immutable _factory;

    IERC20 private immutable _token;
    uint256 private immutable _start;
    uint256 private immutable _cliffDuration;
    uint256 private immutable _vestingDuration;

    uint256 private _released;

    address private _beneficiary;
    bool private _revoked;

    modifier onlyFactoryOwner() {
        if (msg.sender != Ownable(factory()).owner()) revert CliffVestingContract__NotFactoryOwner();
        _;
    }

    /**
     * @dev Constructor for the Vesting Contract.
     * @param factory_ The address of the factory contract.
     * @param token_ The address of the token contract.
     * @param start_ The timestamp at which the vesting starts.
     * @param cliffDuration_ The duration of the lock.
     * @param vestingDuration_ The duration of the vesting.
     */
    constructor(address factory_, IERC20 token_, uint256 start_, uint256 cliffDuration_, uint256 vestingDuration_) {
        if (cliffDuration_ > vestingDuration_) revert CliffVestingContract__InvalidCliffDuration();

        _factory = factory_;
        _token = token_;
        _start = start_;
        _cliffDuration = cliffDuration_;
        _vestingDuration = vestingDuration_;
    }

    /**
     * @dev Returns the address of the factory contract.
     * @return The address of the factory contract.
     */
    function factory() public view virtual override returns (address) {
        return _factory;
    }

    /**
     * @dev Returns the address of the token contract.
     * @return The address of the token contract.
     */
    function token() public view virtual override returns (IERC20) {
        return _token;
    }

    /**
     * @dev Returns the timestamp at which the vesting starts.
     * @return The timestamp at which the vesting starts.
     */
    function start() public view virtual override returns (uint256) {
        return _start;
    }

    /**
     * @dev Returns the duration of the lock.
     * @return The duration of the lock.
     */
    function cliffDuration() public view virtual override returns (uint256) {
        return _cliffDuration;
    }

    /**
     * @dev Returns the duration of the vesting.
     * @return The duration of the vesting.
     */
    function vestingDuration() public view virtual override returns (uint256) {
        return _vestingDuration;
    }

    /**
     * @dev Returns the timestamp at which the vesting ends.
     * @return The timestamp at which the vesting ends.
     */
    function end() public view virtual override returns (uint256) {
        return start() + vestingDuration();
    }

    /**
     * @dev Returns the address of the beneficiary.
     * @return The address of the beneficiary.
     */
    function beneficiary() public view virtual override returns (address) {
        return _beneficiary;
    }

    /**
     * @dev Returns whether the vesting contract has been revoked.
     * @return Whether the vesting contract has been revoked.
     */
    function revoked() public view virtual override returns (bool) {
        return _revoked;
    }

    /**
     * @dev Returns the amount of tokens that have been released.
     * @return The amount of tokens that have been released.
     */
    function released() public view virtual override returns (uint256) {
        return _released;
    }

    /**
     * @dev Returns the amount of tokens that can be released.
     * @return The amount of tokens that can be released.
     */
    function releasable() public view virtual override returns (uint256) {
        return vestedAmount(block.timestamp) - released();
    }

    /**
     * @dev Returns the amount of tokens that have been vested at the specified timestamp.
     * @param timestamp The timestamp at which the amount of vested tokens will be calculated.
     * @return The amount of tokens that have been vested at the specified timestamp.
     */
    function vestedAmount(uint256 timestamp) public view virtual override returns (uint256) {
        return _vestingSchedule(_token.balanceOf(address(this)) + released(), timestamp);
    }

    /**
     * @dev Releases the vested tokens to the beneficiary.
     */
    function release() public virtual override {
        if (msg.sender != beneficiary()) revert CliffVestingContract__NotBeneficiary();

        uint256 amount = releasable();
        _released += amount;

        _token.safeTransfer(msg.sender, amount);

        emit Released(msg.sender, amount);
    }

    /**
     * @dev Sets the beneficiary.
     * @param newBeneficiary The address of the new beneficiary.
     */
    function setBeneficiary(address newBeneficiary) public virtual override onlyFactoryOwner {
        _beneficiary = newBeneficiary;

        emit BeneficiarySet(newBeneficiary);
    }

    /**
     * @dev Revokes the vesting contract.
     */
    function revoke() public virtual onlyFactoryOwner {
        if (revoked()) revert CliffVestingContract__AlreadyRevoked();

        uint256 released_ = released();
        uint256 balance = _token.balanceOf(address(this));
        uint256 vested = _rawVestingSchedule(balance + released_, start(), vestingDuration(), block.timestamp);

        _revoked = true;

        _token.safeTransfer(msg.sender, balance + released_ - vested);

        emit Revoked();
    }

    /**
     * @dev Calculates the amount of tokens that have been vested at the specified timestamp.
     * @param total The total amount of tokens to be vested.
     * @param timestamp The timestamp at which the amount of vested tokens will be calculated.
     * @return The amount of tokens that have been vested at the specified timestamp.
     */
    function _vestingSchedule(uint256 total, uint256 timestamp) internal view virtual returns (uint256) {
        uint256 start_ = start();
        uint256 cliffDuration_ = cliffDuration();
        uint256 vestingDuration_ = vestingDuration();

        if (timestamp <= start_ + cliffDuration_) return 0;
        if (revoked()) return total;

        return _rawVestingSchedule(total, start_, vestingDuration_, timestamp);
    }

    /**
     * @dev Calculates the amount of tokens that have been vested at the specified timestamp without taking into account
     * whether the vesting contract has a cliff or has been revoked.
     * @param total The total amount of tokens to be vested.
     * @param start_ The timestamp at which the vesting starts.
     * @param vestingDuration_ The duration of the vesting.
     * @param timestamp The timestamp at which the amount of vested tokens will be calculated.
     * @return The amount of tokens that have been vested at the specified timestamp.
     */
    function _rawVestingSchedule(uint256 total, uint256 start_, uint256 vestingDuration_, uint256 timestamp)
        internal
        view
        virtual
        returns (uint256)
    {
        if (timestamp <= start_) {
            return 0;
        } else if (timestamp >= start_ + vestingDuration_) {
            return total;
        } else {
            return (total * (timestamp - start_)) / vestingDuration_;
        }
    }
}
