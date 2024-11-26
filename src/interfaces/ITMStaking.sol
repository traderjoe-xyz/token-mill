// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

interface ITMStaking {
    error TMStaking__ZeroAmount();
    error TMStaking__ZeroAddress();
    error TMStaking__Overflow();
    error TMStaking__InvalidToken(address token);
    error TMStaking__InsufficientStake(int256 amount, int256 lockedAmount);
    error TMStaking__InvalidVestingSchedule();
    error TMStaking__InvalidCliffDuration();
    error TMStaking__ZeroBeneficiary();
    error TMStaking__InsufficientAmountReceived(uint256 received, uint256 minAmount);
    error TMStaking__OnlyBeneficiary();
    error TMStaking__ZeroUnlockedAmount();
    error TMStaking__SameBeneficiary();
    error TMStaking__VestingExpired();

    event Update(address indexed account, address indexed token, int256 deltaAmount, int256 deltaLockedAmount);
    event Unlock(address indexed account, address indexed token, uint256 indexed index, uint256 unlocked);
    event Claim(address indexed account, address indexed token, address indexed rewardToken, uint256 amount);
    event EmergencyUpdate(address indexed account, address indexed token, int256 deltaAmount, int256 deltaLockedAmount);
    event VestingScheduleCreated(
        address indexed token,
        address indexed creator,
        address indexed beneficiary,
        uint256 index,
        uint256 amount,
        uint80 start,
        uint80 cliffDuration,
        uint80 vestingDuration
    );
    event VestingScheduleTransferred(
        address indexed token, uint256 indexed index, address oldBeneficiary, address newBeneficiary
    );

    struct User {
        uint128 amount;
        uint128 lockedAmount;
        uint256 pending;
        uint256 accRewardPerShare;
        EnumerableSet.UintSet vestingIndices;
    }

    struct VestingSchedule {
        address beneficiary;
        uint128 total;
        uint128 released;
        uint80 start;
        uint80 cliffDuration;
        uint80 vestingDuration;
    }

    struct Staking {
        uint128 totalStaked;
        uint128 totalLocked;
        uint256 accRewardPerShare;
        mapping(address => User) users;
        VestingSchedule[] vestingSchedules;
    }

    function FACTORY() external view returns (address);
    function claimRewards(address token, address to) external returns (uint256);
    function createVestingSchedule(
        address token,
        address beneficiary,
        uint128 amount,
        uint128 minAmount,
        uint80 start,
        uint80 cliffDuration,
        uint80 vestingDuration
    ) external returns (uint256 index);
    function deposit(address token, address to, uint256 amount, uint256 minAmount)
        external
        returns (uint256 actualAmount);
    function getNumberOfTokensOf(address account) external view returns (uint256);
    function getNumberOfVestings(address token) external view returns (uint256);
    function getNumberOfVestingsOf(address token, address account) external view returns (uint256);
    function getPendingRewards(address token, address account) external view returns (uint256 pending);
    function getReleasableAmount(address token, uint256 index) external view returns (uint256);
    function getStakeOf(address token, address account) external view returns (uint256 amount, uint256 lockedAmount);
    function getTokenOf(address account, uint256 index) external view returns (address);
    function getTotalStake(address token) external view returns (uint256 totalStaked, uint256 totalLocked);
    function getVestedAmount(address token, uint256 index, uint256 timestamp) external view returns (uint256);
    function getVestingIndexOf(address token, address account, uint256 index) external view returns (uint256);
    function getVestingScheduleAt(address token, uint256 index) external view returns (VestingSchedule memory);
    function initialize() external;
    function transferVesting(address token, address newBeneficiary, uint256 index) external returns (uint256);
    function unlock(address token, uint256 index) external returns (uint256 unlocked);
    function withdraw(address token, address to, uint256 amount) external returns (uint256);
}
