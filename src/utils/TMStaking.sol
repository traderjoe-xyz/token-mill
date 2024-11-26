// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import {ITMMarket} from "../interfaces/ITMMarket.sol";
import {ITMFactory} from "../interfaces/ITMFactory.sol";
import {ITMStaking} from "../interfaces/ITMStaking.sol";

/**
 * @title Token Mill Staking Contract
 * @dev This contract implements a staking contract. Users can stake/unstake tokens and create vesting schedules for tokens
 * that can be unlocked over time by the beneficiary.
 * Both staked and locked tokens are considered when calculating the pending rewards.
 * The staking contract supports multiple tokens, and multiple vesting schedules for each token.
 * Each vesting schedule is as follows:
 * - tokens vest linearly from the `start` to the `start + vestingDuration` timestamp
 * - vested tokens can only be claimed after the `start + cliffDuration` timestamp
 */
contract TMStaking is ReentrancyGuardUpgradeable, ITMStaking {
    using SafeERC20 for IERC20;
    using EnumerableSet for EnumerableSet.UintSet;
    using EnumerableSet for EnumerableSet.AddressSet;

    address public immutable override FACTORY;

    uint256 internal constant BPS = 10_000;
    uint256 internal constant PRECISION = 1e32;

    mapping(address token => Staking) private _stakings;
    mapping(address user => EnumerableSet.AddressSet) private _userTokens;

    constructor(address _factory) {
        _disableInitializers();

        FACTORY = _factory;
    }

    /**
     * @dev Initializes ReentrancyGuard dependency.
     */
    function initialize() external override initializer {
        __ReentrancyGuard_init();
    }

    /**
     * @dev Returns the total staked and total locked amounts of the specified token.
     * @param token The address of the token.
     * @return totalStaked The total staked amount of the specified token.
     * @return totalLocked The total locked amount of the specified token.
     */
    function getTotalStake(address token) external view override returns (uint256 totalStaked, uint256 totalLocked) {
        Staking storage staking = _stakings[token];
        return (staking.totalStaked, staking.totalLocked);
    }

    /**
     * @dev Returns the stake and locked amounts of the specified account for the specified token.
     * @param token The address of the token.
     * @param account The address of the account.
     * @return amount The stake amount of the specified account for the specified token.
     * @return lockedAmount The locked amount of the specified account for the specified token.
     */
    function getStakeOf(address token, address account)
        external
        view
        override
        returns (uint256 amount, uint256 lockedAmount)
    {
        User storage user = _stakings[token].users[account];
        return (user.amount, user.lockedAmount);
    }

    /**
     * @dev Returns the number of tokens staked by the specified account.
     * @param account The address of the account.
     * @return The number of tokens staked by the specified account.
     */
    function getNumberOfTokensOf(address account) external view override returns (uint256) {
        return _userTokens[account].length();
    }

    /**
     * @dev Returns the token staked by the specified account at the specified index.
     * The order of the tokens is not guaranteed.
     * @param account The address of the account.
     * @param index The index of the token.
     * @return The token staked by the specified account at the specified index.
     */
    function getTokenOf(address account, uint256 index) external view override returns (address) {
        return _userTokens[account].at(index);
    }

    /**
     * @dev Returns the total number of vestings of the specified token.
     * @param token The address of the token.
     * @return The total number of vesting schedules of the specified token.
     */
    function getNumberOfVestings(address token) external view override returns (uint256) {
        return _stakings[token].vestingSchedules.length;
    }

    /**
     * @dev Returns the vesting schedule of the specified token at the specified index.
     * @param token The address of the token.
     * @param index The index of the vesting schedule.
     * @return The vesting schedule of the specified token at the specified index.
     */
    function getVestingScheduleAt(address token, uint256 index)
        external
        view
        override
        returns (VestingSchedule memory)
    {
        return _stakings[token].vestingSchedules[index];
    }

    /**
     * @dev Returns the number of vestings of the specified token for the specified account.
     * @param token The address of the token.
     * @param account The address of the account.
     * @return The number of vesting schedules of the specified token for the specified account.
     */
    function getNumberOfVestingsOf(address token, address account) external view override returns (uint256) {
        return _stakings[token].users[account].vestingIndices.length();
    }

    /**
     * @dev Returns the global index of the vesting schedule of the specified token for the specified account
     * at the specified index.
     * @param token The address of the token.
     * @param account The address of the account.
     * @param index The index of the vesting schedule.
     * @return The global index of the vesting schedule of the specified token for the specified account at the specified index.
     */
    function getVestingIndexOf(address token, address account, uint256 index)
        external
        view
        override
        returns (uint256)
    {
        return _stakings[token].users[account].vestingIndices.at(index);
    }

    /**
     * @dev Returns the total vested amount of tokens by the specified token at the specified index at the
     * specified timestamp.
     * @param token The address of the token.
     * @param index The index of the vesting schedule.
     * @param timestamp The timestamp at which the amount of releasable tokens will be calculated.
     * @return The total vested amount of tokens by the specified token at the specified index at the specified timestamp.
     */
    function getVestedAmount(address token, uint256 index, uint256 timestamp)
        external
        view
        override
        returns (uint256)
    {
        VestingSchedule storage vesting = _stakings[token].vestingSchedules[index];

        return _vestingSchedule(vesting.total, vesting.start, vesting.cliffDuration, vesting.vestingDuration, timestamp);
    }

    /**
     * @dev Returns the amount of tokens that can be released by the specified token at the specified index.
     * @param token The address of the token.
     * @param index The index of the vesting schedule.
     * @return The amount of tokens that can be released by the specified token at the specified index.
     */
    function getReleasableAmount(address token, uint256 index) external view override returns (uint256) {
        VestingSchedule storage vesting = _stakings[token].vestingSchedules[index];

        return _vestingSchedule(
            vesting.total, vesting.start, vesting.cliffDuration, vesting.vestingDuration, block.timestamp
        ) - vesting.released;
    }

    /**
     * @dev Returns the pending rewards of the specified account for the specified token.
     * The reward token is the quote token of the market of the specified token.
     * @param token The address of the token.
     * @param account The address of the account.
     * @return pending The pending rewards of the specified account for the specified token.
     */
    function getPendingRewards(address token, address account) external view override returns (uint256 pending) {
        Staking storage staking = _stakings[token];
        User storage user = staking.users[account];

        address market = ITMFactory(FACTORY).getMarketOf(token);
        if (market == address(0)) revert TMStaking__InvalidToken(token);

        uint256 shares = user.amount + user.lockedAmount;
        uint256 totalShares = staking.totalStaked + staking.totalLocked;

        pending = user.pending;

        if (totalShares > 0) {
            (, uint256 stakingFees) = ITMMarket(market).getPendingFees();

            uint256 accRewardPerShare = staking.accRewardPerShare + (stakingFees * PRECISION) / totalShares;

            pending += (shares * (accRewardPerShare - user.accRewardPerShare)) / PRECISION;
        }
    }

    /**
     * @dev Deposits the specified amount of tokens to the specified account.
     * The amount of tokens received must be greater than or equal to the specified minimum amount.
     * Note that the first deposit / vesting will receive all the fees accumulated until that point.
     * @param token The address of the token.
     * @param to The address of the account.
     * @param amount The amount of tokens to be deposited.
     * @param minAmount The minimum amount of tokens to be received.
     * @return actualAmount The actual amount of tokens received.
     */
    function deposit(address token, address to, uint256 amount, uint256 minAmount)
        external
        override
        nonReentrant
        returns (uint256 actualAmount)
    {
        if (to == address(0)) revert TMStaking__ZeroBeneficiary();

        Staking storage staking = _stakings[token];
        User storage user = staking.users[to];

        actualAmount = _transferFrom(token, msg.sender, amount, minAmount);
        _update(staking, user, token, to, int256(actualAmount), 0);
    }

    /**
     * @dev Withdraws the specified amount of tokens from the specified account.
     * The amount of tokens withdrawn must be greater than 0.
     * @param token The address of the token.
     * @param to The address of the account.
     * @param amount The amount of tokens to be withdrawn.
     * @return The amount of tokens withdrawn.
     */
    function withdraw(address token, address to, uint256 amount) external override nonReentrant returns (uint256) {
        if (amount == 0) revert TMStaking__ZeroAmount();
        if (amount > type(uint128).max) revert TMStaking__Overflow();
        if (to == address(0)) revert TMStaking__ZeroBeneficiary();

        Staking storage staking = _stakings[token];
        User storage user = staking.users[msg.sender];

        _update(staking, user, token, msg.sender, -int256(amount), 0);

        IERC20(token).safeTransfer(to, amount);

        return amount;
    }

    /**
     * @dev Claims the rewards of the specified account for the specified token.
     * @param token The address of the token.
     * @param to The address that will receive the rewards.
     * @return The amount of tokens claimed.
     */
    function claimRewards(address token, address to) external override nonReentrant returns (uint256) {
        if (to == address(0)) revert TMStaking__ZeroAddress();

        Staking storage staking = _stakings[token];
        User storage user = staking.users[msg.sender];

        (address market, uint256 pending) = _update(staking, user, token, msg.sender, 0, 0);

        if (pending > 0) {
            user.pending = 0;

            address rewardToken = ITMMarket(market).getQuoteToken();
            IERC20(rewardToken).safeTransfer(to, pending);

            emit Claim(msg.sender, token, rewardToken, pending);
        }

        return pending;
    }

    /**
     * @dev Creates a vesting schedule for the specified token.
     * The amount of tokens received must be greater than or equal to the specified minimum amount.
     * Note that the first deposit / vesting will receive all the fees accumulated until that point.
     * @param token The address of the token.
     * @param beneficiary The address of the beneficiary.
     * @param amount The amount of tokens to be vested.
     * @param minAmount The minimum amount of tokens to be received.
     * @param start The timestamp at which the vesting will start.
     * @param cliffDuration The duration of the cliff in seconds.
     * @param vestingDuration The duration of the vesting in seconds.
     * @return index The index of the vesting schedule.
     */
    function createVestingSchedule(
        address token,
        address beneficiary,
        uint128 amount,
        uint128 minAmount,
        uint80 start,
        uint80 cliffDuration,
        uint80 vestingDuration
    ) external override nonReentrant returns (uint256 index) {
        if (cliffDuration > vestingDuration) revert TMStaking__InvalidCliffDuration();
        if (start + vestingDuration <= block.timestamp) revert TMStaking__InvalidVestingSchedule();
        if (beneficiary == address(0)) revert TMStaking__ZeroBeneficiary();

        uint256 actualAmount = _transferFrom(token, msg.sender, amount, minAmount);

        Staking storage staking = _stakings[token];
        User storage user = staking.users[beneficiary];

        index = staking.vestingSchedules.length;

        staking.vestingSchedules.push(
            VestingSchedule(beneficiary, uint128(actualAmount), 0, start, cliffDuration, vestingDuration)
        );

        user.vestingIndices.add(index);

        _update(staking, user, token, beneficiary, 0, int256(actualAmount));

        emit VestingScheduleCreated(
            token, msg.sender, beneficiary, index, actualAmount, start, cliffDuration, vestingDuration
        );
    }

    /**
     * @dev Unlocks the vested tokens of the specified token at the specified index for the specified account.
     * Anyone can call this function on behalf of the beneficiary as the unlocked tokens are immediately staked.
     * @param token The address of the token.
     * @param index The index of the vesting schedule.
     * @return unlocked The amount of tokens unlocked.
     */
    function unlock(address token, uint256 index) external override nonReentrant returns (uint256 unlocked) {
        Staking storage staking = _stakings[token];
        VestingSchedule storage vesting = staking.vestingSchedules[index];

        address beneficiary = vesting.beneficiary;
        User storage user = staking.users[beneficiary];

        uint256 total = vesting.total;
        uint256 vested =
            _vestingSchedule(total, vesting.start, vesting.cliffDuration, vesting.vestingDuration, block.timestamp);

        unlocked = vested - vesting.released;
        if (unlocked == 0) revert TMStaking__ZeroUnlockedAmount();

        vesting.released = uint128(vested);

        if (total == vested) user.vestingIndices.remove(index);

        _update(staking, user, token, beneficiary, int256(unlocked), -int256(unlocked));

        emit Unlock(beneficiary, token, index, unlocked);
    }

    /**
     * @dev Transfers the vesting schedule of the specified token at the specified index from the sender to the new beneficiary.
     * @param token The address of the token.
     * @param newBeneficiary The address of the new beneficiary.
     * @param index The index of the vesting schedule.
     * @return The remaining locked amount of tokens.
     */
    function transferVesting(address token, address newBeneficiary, uint256 index)
        external
        override
        nonReentrant
        returns (uint256)
    {
        if (newBeneficiary == address(0)) revert TMStaking__ZeroBeneficiary();

        Staking storage staking = _stakings[token];
        VestingSchedule storage vesting = staking.vestingSchedules[index];

        address oldBeneficiary = vesting.beneficiary;

        if (oldBeneficiary != msg.sender) revert TMStaking__OnlyBeneficiary();
        if (oldBeneficiary == newBeneficiary) revert TMStaking__SameBeneficiary();

        User storage oldUser = staking.users[oldBeneficiary];
        User storage newUser = staking.users[newBeneficiary];

        uint256 total = vesting.total;
        uint256 vested =
            _vestingSchedule(total, vesting.start, vesting.cliffDuration, vesting.vestingDuration, block.timestamp);

        uint256 releasable = vested - vesting.released;
        uint256 locked = total - vested;

        if (locked == 0) revert TMStaking__VestingExpired();

        vesting.beneficiary = newBeneficiary;
        vesting.released = uint128(vested);

        oldUser.vestingIndices.remove(index);
        newUser.vestingIndices.add(index);

        _update(staking, oldUser, token, oldBeneficiary, int256(releasable), -int256(locked + releasable));
        _update(staking, newUser, token, newBeneficiary, 0, int256(locked));

        emit Unlock(oldBeneficiary, token, index, releasable);
        emit VestingScheduleTransferred(token, index, oldBeneficiary, newBeneficiary);

        return locked;
    }

    /**
     * @dev Returns the vested amount of tokens at the specified timestamp using the specified vesting schedule.
     * @param total The total amount of tokens to be vested.
     * @param start The timestamp at which the vesting starts.
     * @param cliffDuration The duration of the cliff.
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
        return timestamp < start + vestingDuration
            ? (timestamp < start + cliffDuration ? 0 : (total * (timestamp - start)) / vestingDuration)
            : total;
    }

    /**
     * @dev Transfers the specified amount of tokens from the specified account to this contract.
     * The amount of tokens received must be greater than or equal to the specified minimum amount.
     * @param token The address of the token.
     * @param from The address of the account.
     * @param amount The amount of tokens to be transferred.
     * @param minAmount The minimum amount of tokens to be received.
     * @return actualAmount The actual amount of tokens received.
     */
    function _transferFrom(address token, address from, uint256 amount, uint256 minAmount)
        private
        returns (uint256 actualAmount)
    {
        uint256 balance = IERC20(token).balanceOf(address(this));
        IERC20(token).safeTransferFrom(from, address(this), amount);
        actualAmount = IERC20(token).balanceOf(address(this)) - balance;

        if (actualAmount == 0) revert TMStaking__ZeroAmount();
        if (actualAmount > type(uint128).max) revert TMStaking__Overflow();
        if (actualAmount < minAmount) revert TMStaking__InsufficientAmountReceived(actualAmount, minAmount);
    }

    /**
     * @dev Updates the stake and locked amounts of the specified account for the specified token.
     * The pending rewards are calculated and updated.
     * The following conditions must be verified before calling this function:
     * The staking storage pointer must be equal to `staking[token]`.
     * The user storage pointer must be equal to `staking.users[account]`.
     * The deltaAmount and deltaLockedAmount must be within the [- max(uint128), max(uint128)] range.
     * @param staking The storage pointer to the staking data structure.
     * @param user The storage pointer to the user data structure.
     * @param token The address of the token.
     * @param account The address of the account.
     * @param deltaAmount The change in the stake amount.
     * @param deltaLockedAmount The change in the locked amount.
     * @return The market of the specified token and the pending rewards of the specified account.
     */
    function _update(
        Staking storage staking,
        User storage user,
        address token,
        address account,
        int256 deltaAmount,
        int256 deltaLockedAmount
    ) private returns (address, uint256 pending) {
        (address market, uint256 totalStaked, uint256 totalLocked, uint256 accRewardPerShare) =
            _updateReward(staking, token);

        uint256 amount = user.amount;
        uint256 lockedAmount = user.lockedAmount;

        uint256 shares = amount + lockedAmount;

        if (shares > 0) pending = (user.pending += (shares * (accRewardPerShare - user.accRewardPerShare)) / PRECISION);
        else pending = user.pending;

        user.accRewardPerShare = accRewardPerShare;

        if ((deltaAmount | deltaLockedAmount) != 0) {
            // The sum of the deltas and their respective amounts will be checked to be positive, so we can assume
            // that if both previous amounts are 0, the deltas will be positive. So we need to add the token to the
            // user's token set.
            if (amount == 0 && lockedAmount == 0) _userTokens[account].add(token);

            unchecked {
                amount += uint256(deltaAmount);
                lockedAmount += uint256(deltaLockedAmount);
            }

            // As deltas are constrained to be within the [- max(uint128), max(uint128)] range, the int256 sums can't
            // overflow. So if the sums are negative, we can assume that one, or both, of the deltas were negative and
            // that one, or both, of the absolute values of the deltas are greater than the respective amounts so we
            // need to revert.
            if (int256(amount | lockedAmount) < 0) {
                revert TMStaking__InsufficientStake(int256(amount), int256(lockedAmount));
            }

            unchecked {
                totalStaked += uint256(deltaAmount);
                totalLocked += uint256(deltaLockedAmount);
            }

            // As the total are the sum of all the previous amounts, and that we checked that the amounts are both positive,
            // adding the deltas to the total will not overflow as the deltas are constrained to be within the
            // [- max(uint128), max(uint128)] range. However, if one of the totals is bigger than the maximum uint128 value,
            // we need to revert.
            if ((totalStaked | totalLocked) > type(uint128).max) revert TMStaking__Overflow();

            // If the new amounts are 0, the user no longer has any stake in the token, so we need to remove the token
            // from the user's token set.
            if (amount == 0 && lockedAmount == 0) _userTokens[account].remove(token);

            user.amount = uint128(amount);
            user.lockedAmount = uint128(lockedAmount);

            staking.totalStaked = uint128(totalStaked);
            staking.totalLocked = uint128(totalLocked);

            emit Update(account, token, deltaAmount, deltaLockedAmount);
        }

        return (market, pending);
    }

    /**
     * @dev Updates the reward of the specified token.
     * The following conditions must be verified before calling this function:
     * The staking storage pointer must be equal to `staking[token]`.
     * @param staking The storage pointer to the staking data structure.
     * @param token The address of the token.
     * @return market The market of the specified token.
     * @return totalStaked The total staked amount of the specified token.
     * @return totalLocked The total locked amount of the specified token.
     * @return accRewardPerShare The updated accumulated reward per share of the specified token.
     */
    function _updateReward(Staking storage staking, address token)
        private
        returns (address market, uint256 totalStaked, uint256 totalLocked, uint256 accRewardPerShare)
    {
        market = ITMFactory(FACTORY).getMarketOf(token);
        if (market == address(0)) revert TMStaking__InvalidToken(token);

        totalStaked = staking.totalStaked;
        totalLocked = staking.totalLocked;

        accRewardPerShare = staking.accRewardPerShare;

        uint256 totalShares = totalStaked + totalLocked;

        if (totalShares > 0) {
            uint256 stakingFees = ITMFactory(FACTORY).claimFees(market);

            if (stakingFees > 0) {
                accRewardPerShare += (stakingFees * PRECISION) / totalShares;
                staking.accRewardPerShare = accRewardPerShare;
            }
        }
    }
}
