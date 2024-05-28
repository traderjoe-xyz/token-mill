// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ICliffVestingContract {
    error CliffVestingContract__InvalidCliffDuration();
    error CliffVestingContract__InvalidVestingSchedule();
    error CliffVestingContract__InsufficientAmountReceived(uint256 received, uint256 minAmount);
    error CliffVestingContract__OnlyBeneficiary();
    error CliffVestingContract__OnlyFactoryOwner();
    error CliffVestingContract__ExceedsReserves();
    error CliffVestingContract__ZeroMinAmount();

    event VestingScheduleCreated(
        address indexed token,
        address indexed sender,
        address indexed beneficiary,
        uint256 vesting,
        uint128 amount,
        uint80 start,
        uint80 cliffDuration,
        uint80 vestingDuration
    );

    event VestingScheduleTransferred(address indexed token, address indexed from, address indexed to, uint256 index);

    event Released(address indexed token, address indexed beneficiary, uint256 amount);

    struct VestingSchedule {
        address beneficiary;
        uint128 total;
        uint128 released;
        uint80 start;
        uint80 cliffDuration;
        uint80 vestingDuration;
    }

    function getFactory() external view returns (address);

    function getNumberOfVestings(address token) external view returns (uint256);

    function getVestingSchedule(address token, uint256 index) external view returns (VestingSchedule memory);

    function getReleasableAmount(address token, uint256 index) external view returns (uint256);

    function getVestedAmount(address token, uint256 index, uint256 timestamp) external view returns (uint256);

    function createVestingSchedule(
        address token,
        address beneficiary,
        uint128 amount,
        uint128 minAmount,
        uint80 start,
        uint80 cliffDuration,
        uint80 vestingDuration
    ) external;

    function release(address token, uint256 index) external;

    function transferVestingSchedule(address token, address newBeneficiary, uint256 index) external;
}
