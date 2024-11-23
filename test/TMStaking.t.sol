// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/proxy/utils/Initializable.sol";

import "./TestHelper.sol";
import "../src/utils/TMStaking.sol";
import "../src/interfaces/ITMStaking.sol";
import "./mocks/MockERC20.sol";

contract TMStakingTest is TestHelper {
    TMStaking public staking;

    address alice = makeAddr("alice");
    address bob = makeAddr("bob");

    uint80 start0A = uint80(block.timestamp + 365 days);
    uint80 cliffDuration0A = uint80(10 days);
    uint80 vestingDuration0A = uint80(100 days);
    uint128 total0A = 100e18;

    uint80 start0B = uint80(block.timestamp + 50 days);
    uint80 cliffDuration0B = uint80(20 days);
    uint80 vestingDuration0B = start0A + vestingDuration0A - start0B;
    uint128 total0B = 400e18;

    uint80 start1A = uint80(block.timestamp + 100 days);
    uint80 cliffDuration1A = uint80(50 days);
    uint80 vestingDuration1A = uint80(200 days);
    uint128 total1A = 200e6;

    function setUp() public override {
        stakingAddress = _predictContractAddress(6);

        super.setUp();

        address stakingImp = address(new TMStaking(address(factory)));
        staking = TMStaking(
            address(
                new TransparentUpgradeableProxy(stakingImp, address(this), abi.encodeCall(TMStaking.initialize, ()))
            )
        );

        setUpTokens();
    }

    function test_Constructor() public view {
        assertEq(address(staking), stakingAddress, "test_Constructor::1");
        assertEq(staking.FACTORY(), address(factory), "test_Constructor::2");
        assertEq(factory.STAKING(), address(staking), "test_Constructor::3");
    }

    function test_Revert_InitializeTwice() public {
        vm.expectRevert(Initializable.InvalidInitialization.selector);
        staking.initialize();
    }

    function test_Deposit(uint256 amountA, uint256 amountB) public {
        amountA = bound(amountA, 1, type(uint128).max - 1);
        amountB = bound(amountB, 1, type(uint128).max - amountA);

        deal(token0, alice, amountA);
        deal(token0, address(this), amountB);

        (uint256 totalBalance, uint256 totalLocked) = staking.getTotalStake(token0);
        (uint256 balanceA, uint256 lockedA) = staking.getStakeOf(token0, alice);
        (uint256 balanceB, uint256 lockedB) = staking.getStakeOf(token0, bob);

        assertEq(totalBalance, 0, "test_Deposit::1");
        assertEq(totalLocked, 0, "test_Deposit::2");
        assertEq(balanceA, 0, "test_Deposit::3");
        assertEq(lockedA, 0, "test_Deposit::4");
        assertEq(balanceB, 0, "test_Deposit::5");
        assertEq(lockedB, 0, "test_Deposit::6");

        vm.startPrank(alice);
        IERC20(token0).approve(address(staking), amountA);
        staking.deposit(token0, alice, amountA, amountA);
        vm.stopPrank();

        (totalBalance, totalLocked) = staking.getTotalStake(token0);
        (balanceA, lockedA) = staking.getStakeOf(token0, alice);
        (balanceB, lockedB) = staking.getStakeOf(token0, bob);

        assertEq(totalBalance, amountA, "test_Deposit::7");
        assertEq(totalLocked, 0, "test_Deposit::8");
        assertEq(balanceA, amountA, "test_Deposit::9");
        assertEq(lockedA, 0, "test_Deposit::10");
        assertEq(balanceB, 0, "test_Deposit::11");
        assertEq(lockedB, 0, "test_Deposit::12");

        IERC20(token0).approve(address(staking), amountB);
        staking.deposit(token0, bob, amountB, amountB);

        (totalBalance, totalLocked) = staking.getTotalStake(token0);
        (balanceA, lockedA) = staking.getStakeOf(token0, alice);
        (balanceB, lockedB) = staking.getStakeOf(token0, bob);

        assertEq(totalBalance, amountA + amountB, "test_Deposit::13");
        assertEq(totalLocked, 0, "test_Deposit::14");
        assertEq(balanceA, amountA, "test_Deposit::15");
        assertEq(lockedA, 0, "test_Deposit::16");
        assertEq(balanceB, amountB, "test_Deposit::17");
        assertEq(lockedB, 0, "test_Deposit::18");
    }

    function test_Revert_Deposit() public {
        uint256 max = type(uint128).max;

        deal(token0, address(this), max + 1);
        IERC20(token0).approve(address(staking), max + 1);

        vm.expectRevert(ITMStaking.TMStaking__ZeroBeneficiary.selector);
        staking.deposit(token0, address(0), 1, 1);

        vm.expectRevert(ITMStaking.TMStaking__ZeroAmount.selector);
        staking.deposit(token0, address(this), 0, 0);

        vm.expectRevert(ITMStaking.TMStaking__Overflow.selector);
        staking.deposit(token0, address(this), max + 1, max + 1);

        vm.expectRevert(abi.encodeWithSelector(ITMStaking.TMStaking__InsufficientAmountReceived.selector, 1, 2));
        staking.deposit(token0, address(this), 1, 2);

        staking.deposit(token0, address(this), max, max);

        vm.expectRevert(ITMStaking.TMStaking__Overflow.selector);
        staking.deposit(token0, address(this), 1, 1);

        MockERC20 token = new MockERC20("Token", "TKN", 18);

        token.mint(address(this), 1);
        token.approve(address(staking), 1);

        vm.expectRevert(abi.encodeWithSelector(ITMStaking.TMStaking__InvalidToken.selector, address(token)));
        staking.deposit(address(token), address(this), 1, 1);
    }

    function test_Withdraw(uint256 amountA, uint256 amountB, uint256 withdrawA, uint256 withdrawB) public {
        amountA = bound(amountA, 1, type(uint128).max - 1);
        amountB = bound(amountB, 1, type(uint128).max - amountA);
        withdrawA = bound(withdrawA, 1, amountA);
        withdrawB = bound(withdrawB, 1, amountB);

        deal(token0, alice, amountA);
        deal(token0, bob, amountB);

        vm.startPrank(alice);
        IERC20(token0).approve(address(staking), amountA);
        staking.deposit(token0, alice, amountA, amountA);
        vm.stopPrank();

        vm.startPrank(bob);
        IERC20(token0).approve(address(staking), amountB);
        staking.deposit(token0, bob, amountB, amountB);
        vm.stopPrank();

        vm.startPrank(alice);
        staking.withdraw(token0, alice, withdrawA);
        vm.stopPrank();

        (uint256 totalBalance, uint256 totalLocked) = staking.getTotalStake(token0);
        (uint256 balanceA, uint256 lockedA) = staking.getStakeOf(token0, alice);
        (uint256 balanceB, uint256 lockedB) = staking.getStakeOf(token0, bob);

        assertEq(totalBalance, amountA + amountB - withdrawA, "test_Withdraw::1");
        assertEq(totalLocked, 0, "test_Withdraw::2");
        assertEq(balanceA, amountA - withdrawA, "test_Withdraw::3");
        assertEq(lockedA, 0, "test_Withdraw::4");
        assertEq(balanceB, amountB, "test_Withdraw::5");
        assertEq(lockedB, 0, "test_Withdraw::6");
        assertEq(IERC20(token0).balanceOf(alice), withdrawA, "test_Withdraw::7");
        assertEq(IERC20(token0).balanceOf(bob), 0, "test_Withdraw::8");

        vm.startPrank(bob);
        staking.withdraw(token0, bob, withdrawB);
        vm.stopPrank();

        (totalBalance, totalLocked) = staking.getTotalStake(token0);
        (balanceA, lockedA) = staking.getStakeOf(token0, alice);
        (balanceB, lockedB) = staking.getStakeOf(token0, bob);

        assertEq(totalBalance, amountA + amountB - withdrawA - withdrawB, "test_Withdraw::9");
        assertEq(totalLocked, 0, "test_Withdraw::10");
        assertEq(balanceA, amountA - withdrawA, "test_Withdraw::11");
        assertEq(lockedA, 0, "test_Withdraw::12");
        assertEq(balanceB, amountB - withdrawB, "test_Withdraw::13");
        assertEq(lockedB, 0, "test_Withdraw::14");
        assertEq(IERC20(token0).balanceOf(alice), withdrawA, "test_Withdraw::15");
        assertEq(IERC20(token0).balanceOf(bob), withdrawB, "test_Withdraw::16");
    }

    function test_Revert_Withdraw() public {
        uint256 max = type(uint128).max;

        vm.expectRevert(ITMStaking.TMStaking__ZeroAmount.selector);
        staking.withdraw(token0, address(this), 0);

        vm.expectRevert(ITMStaking.TMStaking__Overflow.selector);
        staking.withdraw(token0, address(this), max + 1);

        vm.expectRevert(ITMStaking.TMStaking__ZeroBeneficiary.selector);
        staking.withdraw(token0, address(0), 1);

        vm.expectRevert(abi.encodeWithSelector(ITMStaking.TMStaking__InsufficientStake.selector, -1, 0));
        staking.withdraw(token0, address(this), 1);
    }

    mapping(address => uint256) public totalDeposit;
    mapping(address => uint256) public stakeOf;

    function test_MultiDepositWithdrawal(address[] memory users, uint256[] memory deposits, uint256[] memory withdraws)
        public
    {
        uint256 length = users.length > deposits.length ? deposits.length : users.length;
        length = length > withdraws.length ? withdraws.length : length;
        length = length > 32 ? 32 : length;

        vm.assume(length > 0);

        uint256 max = type(uint128).max;

        deal(token0, address(this), max);

        for (uint256 i = 0; i < length; i++) {
            users[i] = address(uint160(0x10000000 + bound(uint160(users[i]), 0, 7))); // Force some collisions by having a max of 8 unique addresses
            deposits[i] = bound(deposits[i], 1, max + i - length + 1);

            totalDeposit[users[i]] += deposits[i];
            max -= deposits[i];
        }

        for (uint256 i = 0; i < 8; i++) {
            address user = address(uint160(0x10000000 + i));
            uint256 amount = totalDeposit[user];

            IERC20(token0).transfer(user, amount);

            vm.prank(user);
            IERC20(token0).approve(address(staking), amount);

            assertEq(staking.getNumberOfTokensOf(user), 0, "test_MultiDepositWithdrawal::1");
        }

        uint256 total;
        for (uint256 i = 0; i < length; i++) {
            vm.prank(users[i]);
            staking.deposit(token0, users[i], deposits[i], 0);

            stakeOf[users[i]] += deposits[i];
            total += deposits[i];

            (uint256 totalBalance, uint256 totalLocked) = staking.getTotalStake(token0);
            (uint256 balance, uint256 locked) = staking.getStakeOf(token0, users[i]);

            assertEq(totalBalance, total, "test_MultiDepositWithdrawal::2");
            assertEq(totalLocked, 0, "test_MultiDepositWithdrawal::3");
            assertEq(balance, stakeOf[users[i]], "test_MultiDepositWithdrawal::4");
            assertEq(locked, 0, "test_MultiDepositWithdrawal::5");
            assertEq(staking.getNumberOfTokensOf(users[i]), 1, "test_MultiDepositWithdrawal::6");
            assertEq(staking.getTokenOf(users[i], 0), token0, "test_MultiDepositWithdrawal::7");
        }

        for (uint256 i = 0; i < length; i++) {
            withdraws[i] = bound(withdraws[i], 0, stakeOf[users[i]]);

            if (withdraws[i] > 0) {
                vm.prank(users[i]);
                staking.withdraw(token0, users[i], withdraws[i]);

                stakeOf[users[i]] -= withdraws[i];
                total -= withdraws[i];
            }

            if (stakeOf[users[i]] == 0) {
                assertEq(staking.getNumberOfTokensOf(users[i]), 0, "test_MultiDepositWithdrawal::8");
            }

            (uint256 totalBalance, uint256 totalLocked) = staking.getTotalStake(token0);
            (uint256 balance, uint256 locked) = staking.getStakeOf(token0, users[i]);

            assertEq(totalBalance, total, "test_MultiDepositWithdrawal::9");
            assertEq(totalLocked, 0, "test_MultiDepositWithdrawal::10");
            assertEq(balance, stakeOf[users[i]], "test_MultiDepositWithdrawal::11");
            assertEq(locked, 0, "test_MultiDepositWithdrawal::12");
        }
    }

    struct VestingAmounts {
        uint256 amountA;
        uint256 lockedA;
        uint256 amountB;
        uint256 lockedB;
        uint256 totalAmount;
        uint256 totalLocked;
    }

    function test_Release() public {
        deal(token0, address(this), total0A + total0B);
        deal(token1, address(this), total1A);

        IERC20(token0).approve(address(staking), total0A + total0B);
        IERC20(token1).approve(address(staking), total1A);

        assertEq(staking.getNumberOfVestings(token0), 0, "test_Release::1");
        assertEq(staking.getNumberOfVestings(token1), 0, "test_Release::2");

        assertEq(staking.getNumberOfVestingsOf(token0, alice), 0, "test_Release::3");
        assertEq(staking.getNumberOfVestingsOf(token0, bob), 0, "test_Release::4");

        staking.createVestingSchedule(token0, alice, total0A, total0A, start0A, cliffDuration0A, vestingDuration0A);

        assertEq(staking.getNumberOfVestings(token0), 1, "test_Release::5");
        assertEq(staking.getNumberOfVestings(token1), 0, "test_Release::6");

        assertEq(staking.getNumberOfVestingsOf(token0, alice), 1, "test_Release::7");
        assertEq(staking.getNumberOfVestingsOf(token0, bob), 0, "test_Release::8");
        assertEq(staking.getNumberOfVestingsOf(token1, alice), 0, "test_Release::9");
        assertEq(staking.getNumberOfVestingsOf(token1, bob), 0, "test_Release::10");

        staking.createVestingSchedule(token0, bob, total0B, total0B, start0B, cliffDuration0B, vestingDuration0B);

        assertEq(staking.getNumberOfVestings(token0), 2, "test_Release::11");
        assertEq(staking.getNumberOfVestings(token1), 0, "test_Release::12");

        assertEq(staking.getNumberOfVestingsOf(token0, alice), 1, "test_Release::13");
        assertEq(staking.getNumberOfVestingsOf(token0, bob), 1, "test_Release::14");
        assertEq(staking.getNumberOfVestingsOf(token1, alice), 0, "test_Release::15");
        assertEq(staking.getNumberOfVestingsOf(token1, bob), 0, "test_Release::16");

        staking.createVestingSchedule(token1, alice, total1A, total1A, start1A, cliffDuration1A, vestingDuration1A);

        assertEq(staking.getNumberOfVestings(token0), 2, "test_Release::17");
        assertEq(staking.getNumberOfVestings(token1), 1, "test_Release::18");

        assertEq(staking.getNumberOfVestingsOf(token0, alice), 1, "test_Release::19");
        assertEq(staking.getNumberOfVestingsOf(token0, bob), 1, "test_Release::20");
        assertEq(staking.getNumberOfVestingsOf(token1, alice), 1, "test_Release::21");
        assertEq(staking.getNumberOfVestingsOf(token1, bob), 0, "test_Release::22");

        assertEq(staking.getVestingIndexOf(token0, alice, 0), 0, "test_Release::23");
        assertEq(staking.getVestingIndexOf(token0, bob, 0), 1, "test_Release::24");
        assertEq(staking.getVestingIndexOf(token1, alice, 0), 0, "test_Release::25");

        ITMStaking.VestingSchedule memory vesting0A = staking.getVestingScheduleAt(token0, 0);
        ITMStaking.VestingSchedule memory vesting0B = staking.getVestingScheduleAt(token0, 1);
        ITMStaking.VestingSchedule memory vesting1A = staking.getVestingScheduleAt(token1, 0);

        VestingAmounts memory amounts0;
        VestingAmounts memory amounts1;

        (amounts0.amountA, amounts0.lockedA) = staking.getStakeOf(token0, alice);
        (amounts0.amountB, amounts0.lockedB) = staking.getStakeOf(token0, bob);
        (amounts0.totalAmount, amounts0.totalLocked) = staking.getTotalStake(token0);

        (amounts1.amountA, amounts1.lockedA) = staking.getStakeOf(token1, alice);
        (amounts1.amountB, amounts1.lockedB) = staking.getStakeOf(token1, bob);
        (amounts1.totalAmount, amounts1.totalLocked) = staking.getTotalStake(token1);

        assertEq(vesting0A.beneficiary, alice, "test_Release::26");
        assertEq(vesting0A.total, total0A, "test_Release::27");
        assertEq(vesting0A.released, 0, "test_Release::28");
        assertEq(vesting0A.start, start0A, "test_Release::29");
        assertEq(vesting0A.cliffDuration, cliffDuration0A, "test_Release::30");
        assertEq(vesting0A.vestingDuration, vestingDuration0A, "test_Release::31");

        assertEq(vesting0B.beneficiary, bob, "test_Release::32");
        assertEq(vesting0B.total, total0B, "test_Release::33");
        assertEq(vesting0B.released, 0, "test_Release::34");
        assertEq(vesting0B.start, start0B, "test_Release::35");
        assertEq(vesting0B.cliffDuration, cliffDuration0B, "test_Release::36");
        assertEq(vesting0B.vestingDuration, vestingDuration0B, "test_Release::37");

        assertEq(vesting1A.beneficiary, alice, "test_Release::38");
        assertEq(vesting1A.total, total1A, "test_Release::39");
        assertEq(vesting1A.released, 0, "test_Release::40");
        assertEq(vesting1A.start, start1A, "test_Release::41");
        assertEq(vesting1A.cliffDuration, cliffDuration1A, "test_Release::42");
        assertEq(vesting1A.vestingDuration, vestingDuration1A, "test_Release::43");

        assertEq(amounts0.amountA, 0, "test_Release::44");
        assertEq(amounts0.lockedA, total0A, "test_Release::45");
        assertEq(amounts0.amountB, 0, "test_Release::46");
        assertEq(amounts0.lockedB, total0B, "test_Release::47");
        assertEq(amounts0.totalAmount, 0, "test_Release::48");
        assertEq(amounts0.totalLocked, total0A + total0B, "test_Release::49");

        assertEq(amounts1.amountA, 0, "test_Release::50");
        assertEq(amounts1.lockedA, total1A, "test_Release::51");
        assertEq(amounts1.amountB, 0, "test_Release::52");
        assertEq(amounts1.lockedB, 0, "test_Release::53");
        assertEq(amounts1.totalAmount, 0, "test_Release::54");
        assertEq(amounts1.totalLocked, total1A, "test_Release::55");

        vm.warp(start0B - 1);

        assertEq(staking.getVestedAmount(token0, 0, block.timestamp), 0, "test_Release::56");
        assertEq(staking.getVestedAmount(token0, 1, block.timestamp), 0, "test_Release::57");
        assertEq(staking.getVestedAmount(token1, 0, block.timestamp), 0, "test_Release::58");

        assertEq(staking.getReleasableAmount(token0, 0), 0, "test_Release::59");
        assertEq(staking.getReleasableAmount(token0, 1), 0, "test_Release::60");
        assertEq(staking.getReleasableAmount(token1, 0), 0, "test_Release::61");

        vm.expectRevert(ITMStaking.TMStaking__ZeroUnlockedAmount.selector);
        staking.unlock(token0, 0);

        vm.expectRevert(ITMStaking.TMStaking__ZeroUnlockedAmount.selector);
        staking.unlock(token0, 1);

        vm.expectRevert(ITMStaking.TMStaking__ZeroUnlockedAmount.selector);
        staking.unlock(token1, 0);

        vesting0A = staking.getVestingScheduleAt(token0, 0);
        vesting0B = staking.getVestingScheduleAt(token0, 1);
        vesting1A = staking.getVestingScheduleAt(token1, 0);

        assertEq(vesting0A.released, 0, "test_Release::62");
        assertEq(vesting0B.released, 0, "test_Release::63");
        assertEq(vesting1A.released, 0, "test_Release::64");

        vm.warp(start0B);

        assertEq(staking.getVestedAmount(token0, 0, block.timestamp), 0, "test_Release::65");
        assertEq(staking.getVestedAmount(token0, 1, block.timestamp), 0, "test_Release::66");
        assertEq(staking.getVestedAmount(token1, 0, block.timestamp), 0, "test_Release::67");

        assertEq(staking.getReleasableAmount(token0, 0), 0, "test_Release::68");
        assertEq(staking.getReleasableAmount(token0, 1), 0, "test_Release::69");
        assertEq(staking.getReleasableAmount(token1, 0), 0, "test_Release::70");

        vm.expectRevert(ITMStaking.TMStaking__ZeroUnlockedAmount.selector);
        staking.unlock(token0, 0);

        vm.expectRevert(ITMStaking.TMStaking__ZeroUnlockedAmount.selector);
        staking.unlock(token0, 1);

        vm.expectRevert(ITMStaking.TMStaking__ZeroUnlockedAmount.selector);
        staking.unlock(token1, 0);

        vesting0A = staking.getVestingScheduleAt(token0, 0);
        vesting0B = staking.getVestingScheduleAt(token0, 1);
        vesting1A = staking.getVestingScheduleAt(token1, 0);

        assertEq(vesting0A.released, 0, "test_Release::71");
        assertEq(vesting0B.released, 0, "test_Release::72");
        assertEq(vesting1A.released, 0, "test_Release::73");

        vm.warp(start0B + cliffDuration0B - 1);

        assertEq(staking.getVestedAmount(token0, 0, block.timestamp), 0, "test_Release::74");
        assertEq(staking.getVestedAmount(token0, 1, block.timestamp), 0, "test_Release::75");
        assertEq(staking.getVestedAmount(token1, 0, block.timestamp), 0, "test_Release::76");

        assertEq(staking.getReleasableAmount(token0, 0), 0, "test_Release::77");
        assertEq(staking.getReleasableAmount(token0, 1), 0, "test_Release::78");
        assertEq(staking.getReleasableAmount(token1, 0), 0, "test_Release::79");

        vm.expectRevert(ITMStaking.TMStaking__ZeroUnlockedAmount.selector);
        staking.unlock(token0, 0);

        vm.expectRevert(ITMStaking.TMStaking__ZeroUnlockedAmount.selector);
        staking.unlock(token0, 1);

        vm.expectRevert(ITMStaking.TMStaking__ZeroUnlockedAmount.selector);
        staking.unlock(token1, 0);

        vesting0A = staking.getVestingScheduleAt(token0, 0);
        vesting0B = staking.getVestingScheduleAt(token0, 1);
        vesting1A = staking.getVestingScheduleAt(token1, 0);

        assertEq(vesting0A.released, 0, "test_Release::80");
        assertEq(vesting0B.released, 0, "test_Release::81");
        assertEq(vesting1A.released, 0, "test_Release::82");

        (amounts0.amountA, amounts0.lockedA) = staking.getStakeOf(token0, alice);
        (amounts0.amountB, amounts0.lockedB) = staking.getStakeOf(token0, bob);
        (amounts0.totalAmount, amounts0.totalLocked) = staking.getTotalStake(token0);

        (amounts1.amountA, amounts1.lockedA) = staking.getStakeOf(token1, alice);
        (amounts1.amountB, amounts1.lockedB) = staking.getStakeOf(token1, bob);
        (amounts1.totalAmount, amounts1.totalLocked) = staking.getTotalStake(token1);

        assertEq(amounts0.amountA, 0, "test_Release::83");
        assertEq(amounts0.lockedA, total0A, "test_Release::84");
        assertEq(amounts0.amountB, 0, "test_Release::85");
        assertEq(amounts0.lockedB, total0B, "test_Release::86");
        assertEq(amounts0.totalAmount, 0, "test_Release::87");
        assertEq(amounts0.totalLocked, total0A + total0B, "test_Release::88");

        assertEq(amounts1.amountA, 0, "test_Release::89");
        assertEq(amounts1.lockedA, total1A, "test_Release::90");
        assertEq(amounts1.amountB, 0, "test_Release::91");
        assertEq(amounts1.lockedB, 0, "test_Release::92");
        assertEq(amounts1.totalAmount, 0, "test_Release::93");
        assertEq(amounts1.totalLocked, total1A, "test_Release::94");

        vm.warp(start1A);

        uint256 releasable0B_0 = vesting0B.total * (block.timestamp - start0B) / vestingDuration0B;

        assertEq(staking.getVestedAmount(token0, 0, block.timestamp), 0, "test_Release::95");
        assertEq(staking.getVestedAmount(token0, 1, block.timestamp), releasable0B_0, "test_Release::96");
        assertEq(staking.getVestedAmount(token1, 0, block.timestamp), 0, "test_Release::97");

        assertEq(staking.getReleasableAmount(token0, 0), 0, "test_Release::98");
        assertEq(staking.getReleasableAmount(token0, 1), releasable0B_0, "test_Release::99");
        assertEq(staking.getReleasableAmount(token1, 0), 0, "test_Release::100");

        vm.expectRevert(ITMStaking.TMStaking__ZeroUnlockedAmount.selector);
        staking.unlock(token0, 0);

        staking.unlock(token0, 1);

        vm.expectRevert(ITMStaking.TMStaking__ZeroUnlockedAmount.selector);
        staking.unlock(token1, 0);

        vesting0A = staking.getVestingScheduleAt(token0, 0);
        vesting0B = staking.getVestingScheduleAt(token0, 1);
        vesting1A = staking.getVestingScheduleAt(token1, 0);

        (amounts0.amountA, amounts0.lockedA) = staking.getStakeOf(token0, alice);
        (amounts0.amountB, amounts0.lockedB) = staking.getStakeOf(token0, bob);
        (amounts0.totalAmount, amounts0.totalLocked) = staking.getTotalStake(token0);

        (amounts1.amountA, amounts1.lockedA) = staking.getStakeOf(token1, alice);
        (amounts1.amountB, amounts1.lockedB) = staking.getStakeOf(token1, bob);
        (amounts1.totalAmount, amounts1.totalLocked) = staking.getTotalStake(token1);

        assertEq(vesting0A.released, 0, "test_Release::101");
        assertEq(vesting0B.released, releasable0B_0, "test_Release::102");
        assertEq(vesting1A.released, 0, "test_Release::103");

        assertEq(amounts0.amountA, 0, "test_Release::104");
        assertEq(amounts0.lockedA, total0A, "test_Release::105");
        assertEq(amounts0.amountB, releasable0B_0, "test_Release::106");
        assertEq(amounts0.lockedB, total0B - releasable0B_0, "test_Release::107");
        assertEq(amounts0.totalAmount, releasable0B_0, "test_Release::108");
        assertEq(amounts0.totalLocked, total0A + total0B - releasable0B_0, "test_Release::109");

        assertEq(amounts1.amountA, 0, "test_Release::110");
        assertEq(amounts1.lockedA, total1A, "test_Release::111");
        assertEq(amounts1.amountB, 0, "test_Release::112");
        assertEq(amounts1.lockedB, 0, "test_Release::113");
        assertEq(amounts1.totalAmount, 0, "test_Release::114");
        assertEq(amounts1.totalLocked, total1A, "test_Release::115");

        assertEq(IERC20(token0).balanceOf(alice), 0, "test_Release::116");
        assertEq(IERC20(token0).balanceOf(bob), 0, "test_Release::117");
        assertEq(IERC20(token1).balanceOf(alice), 0, "test_Release::118");

        vm.warp(start1A + cliffDuration1A + vestingDuration1A / 2);

        uint256 releasable1A_0 = vesting1A.total * (block.timestamp - start1A) / vestingDuration1A;
        uint256 releasable0B_1 = vesting0B.total * (block.timestamp - start0B) / vestingDuration0B - releasable0B_0;

        assertEq(staking.getVestedAmount(token0, 0, block.timestamp), 0, "test_Release::119");
        assertEq(
            staking.getVestedAmount(token0, 1, block.timestamp), releasable0B_1 + releasable0B_0, "test_Release::120"
        );
        assertEq(staking.getVestedAmount(token1, 0, block.timestamp), releasable1A_0, "test_Release::121");

        assertEq(staking.getReleasableAmount(token0, 0), 0, "test_Release::122");
        assertEq(staking.getReleasableAmount(token0, 1), releasable0B_1, "test_Release::123");
        assertEq(staking.getReleasableAmount(token1, 0), releasable1A_0, "test_Release::124");

        vm.expectRevert(ITMStaking.TMStaking__ZeroUnlockedAmount.selector);
        staking.unlock(token0, 0);

        staking.unlock(token0, 1);

        staking.unlock(token1, 0);

        vesting0A = staking.getVestingScheduleAt(token0, 0);
        vesting0B = staking.getVestingScheduleAt(token0, 1);
        vesting1A = staking.getVestingScheduleAt(token1, 0);

        (amounts0.amountA, amounts0.lockedA) = staking.getStakeOf(token0, alice);
        (amounts0.amountB, amounts0.lockedB) = staking.getStakeOf(token0, bob);
        (amounts0.totalAmount, amounts0.totalLocked) = staking.getTotalStake(token0);

        (amounts1.amountA, amounts1.lockedA) = staking.getStakeOf(token1, alice);
        (amounts1.amountB, amounts1.lockedB) = staking.getStakeOf(token1, bob);
        (amounts1.totalAmount, amounts1.totalLocked) = staking.getTotalStake(token1);

        assertEq(vesting0A.released, 0, "test_Release::125");
        assertEq(vesting0B.released, releasable0B_1 + releasable0B_0, "test_Release::126");
        assertEq(vesting1A.released, releasable1A_0, "test_Release::127");

        assertEq(amounts0.amountA, 0, "test_Release::128");
        assertEq(amounts0.lockedA, total0A, "test_Release::129");
        assertEq(amounts0.amountB, releasable0B_1 + releasable0B_0, "test_Release::130");
        assertEq(amounts0.lockedB, total0B - releasable0B_1 - releasable0B_0, "test_Release::131");
        assertEq(amounts0.totalAmount, releasable0B_1 + releasable0B_0, "test_Release::132");
        assertEq(amounts0.totalLocked, total0A + total0B - releasable0B_1 - releasable0B_0, "test_Release::133");

        assertEq(amounts1.amountA, releasable1A_0, "test_Release::134");
        assertEq(amounts1.lockedA, total1A - releasable1A_0, "test_Release::135");
        assertEq(amounts1.amountB, 0, "test_Release::136");
        assertEq(amounts1.lockedB, 0, "test_Release::137");
        assertEq(amounts1.totalAmount, releasable1A_0, "test_Release::138");
        assertEq(amounts1.totalLocked, total1A - releasable1A_0, "test_Release::139");

        vm.expectRevert(ITMStaking.TMStaking__OnlyBeneficiary.selector);
        vm.prank(bob);
        staking.transferVesting(token1, bob, 0);

        vm.expectRevert(ITMStaking.TMStaking__SameBeneficiary.selector);
        vm.prank(alice);
        staking.transferVesting(token1, alice, 0);

        vm.prank(alice);
        staking.transferVesting(token1, bob, 0);

        assertEq(staking.getNumberOfVestings(token0), 2, "test_Release::140");
        assertEq(staking.getNumberOfVestings(token1), 1, "test_Release::141");

        assertEq(staking.getNumberOfVestingsOf(token0, alice), 1, "test_Release::142");
        assertEq(staking.getNumberOfVestingsOf(token0, bob), 1, "test_Release::143");
        assertEq(staking.getNumberOfVestingsOf(token1, alice), 0, "test_Release::144");
        assertEq(staking.getNumberOfVestingsOf(token1, bob), 1, "test_Release::145");

        assertEq(staking.getVestingIndexOf(token0, alice, 0), 0, "test_Release::146");
        assertEq(staking.getVestingIndexOf(token0, bob, 0), 1, "test_Release::147");
        assertEq(staking.getVestingIndexOf(token1, bob, 0), 0, "test_Release::148");

        vm.warp(start1A + cliffDuration1A + vestingDuration1A + 1);

        uint256 releasable1A_1 = vesting1A.total - releasable1A_0;
        uint256 releasable0B_2 =
            vesting0B.total * (block.timestamp - start0B) / vestingDuration0B - releasable0B_1 - releasable0B_0;

        assertEq(staking.getVestedAmount(token0, 0, block.timestamp), 0, "test_Release::149");
        assertEq(
            staking.getVestedAmount(token0, 1, block.timestamp),
            releasable0B_2 + releasable0B_1 + releasable0B_0,
            "test_Release::150"
        );
        assertEq(
            staking.getVestedAmount(token1, 0, block.timestamp), releasable1A_1 + releasable1A_0, "test_Release::151"
        );

        assertEq(staking.getReleasableAmount(token0, 0), 0, "test_Release::152");
        assertEq(staking.getReleasableAmount(token0, 1), releasable0B_2, "test_Release::153");
        assertEq(staking.getReleasableAmount(token1, 0), releasable1A_1, "test_Release::154");

        vm.expectRevert(ITMStaking.TMStaking__ZeroUnlockedAmount.selector);
        staking.unlock(token0, 0);

        staking.unlock(token0, 1);

        staking.unlock(token1, 0);

        vesting0A = staking.getVestingScheduleAt(token0, 0);
        vesting0B = staking.getVestingScheduleAt(token0, 1);
        vesting1A = staking.getVestingScheduleAt(token1, 0);

        (amounts0.amountA, amounts0.lockedA) = staking.getStakeOf(token0, alice);
        (amounts0.amountB, amounts0.lockedB) = staking.getStakeOf(token0, bob);
        (amounts0.totalAmount, amounts0.totalLocked) = staking.getTotalStake(token0);

        (amounts1.amountA, amounts1.lockedA) = staking.getStakeOf(token1, alice);
        (amounts1.amountB, amounts1.lockedB) = staking.getStakeOf(token1, bob);
        (amounts1.totalAmount, amounts1.totalLocked) = staking.getTotalStake(token1);

        assertEq(vesting0A.released, 0, "test_Release::155");
        assertEq(vesting0B.released, releasable0B_2 + releasable0B_1 + releasable0B_0, "test_Release::156");
        assertEq(vesting1A.beneficiary, bob, "test_Release::157");
        assertEq(vesting1A.released, releasable1A_1 + releasable1A_0, "test_Release::158");

        assertEq(amounts0.amountA, 0, "test_Release::159");
        assertEq(amounts0.lockedA, total0A, "test_Release::160");
        assertEq(amounts0.amountB, releasable0B_2 + releasable0B_1 + releasable0B_0, "test_Release::161");
        assertEq(amounts0.lockedB, total0B - releasable0B_2 - releasable0B_1 - releasable0B_0, "test_Release::162");
        assertEq(amounts0.totalAmount, releasable0B_2 + releasable0B_1 + releasable0B_0, "test_Release::163");
        assertEq(
            amounts0.totalLocked,
            total0A + total0B - releasable0B_2 - releasable0B_1 - releasable0B_0,
            "test_Release::164"
        );

        assertEq(amounts1.amountA, releasable1A_0, "test_Release::165");
        assertEq(amounts1.lockedA, 0, "test_Release::166");
        assertEq(amounts1.amountB, releasable1A_1, "test_Release::167");
        assertEq(amounts1.lockedB, 0, "test_Release::168");
        assertEq(amounts1.totalAmount, releasable1A_0 + releasable1A_1, "test_Release::169");
        assertEq(amounts1.totalLocked, 0, "test_Release::170");

        vm.warp(start0A + cliffDuration0A);

        uint256 releasable0B_3 = vesting0B.total * (block.timestamp - start0B) / vestingDuration0B - releasable0B_2
            - releasable0B_1 - releasable0B_0;
        uint256 releasable0A_0 = vesting0A.total * (block.timestamp - start0A) / vestingDuration0A;

        assertEq(staking.getVestedAmount(token0, 0, block.timestamp), releasable0A_0, "test_Release::171");
        assertEq(
            staking.getVestedAmount(token0, 1, block.timestamp),
            releasable0B_3 + releasable0B_2 + releasable0B_1 + releasable0B_0,
            "test_Release::172"
        );
        assertEq(
            staking.getVestedAmount(token1, 0, block.timestamp), releasable1A_1 + releasable1A_0, "test_Release::173"
        );

        assertEq(staking.getReleasableAmount(token0, 0), releasable0A_0, "test_Release::174");
        assertEq(staking.getReleasableAmount(token0, 1), releasable0B_3, "test_Release::175");
        assertEq(staking.getReleasableAmount(token1, 0), 0, "test_Release::176");

        staking.unlock(token0, 0);

        staking.unlock(token0, 1);

        vm.expectRevert(ITMStaking.TMStaking__ZeroUnlockedAmount.selector);
        staking.unlock(token1, 0);

        vesting0A = staking.getVestingScheduleAt(token0, 0);
        vesting0B = staking.getVestingScheduleAt(token0, 1);
        vesting1A = staking.getVestingScheduleAt(token1, 0);

        (amounts1.amountA, amounts1.lockedA) = staking.getStakeOf(token1, alice);
        (amounts1.amountB, amounts1.lockedB) = staking.getStakeOf(token1, bob);
        (amounts1.totalAmount, amounts1.totalLocked) = staking.getTotalStake(token1);

        (amounts0.amountA, amounts0.lockedA) = staking.getStakeOf(token0, alice);
        (amounts0.amountB, amounts0.lockedB) = staking.getStakeOf(token0, bob);
        (amounts0.totalAmount, amounts0.totalLocked) = staking.getTotalStake(token0);

        assertEq(vesting0A.released, releasable0A_0, "test_Release::177");
        assertEq(
            vesting0B.released, releasable0B_3 + releasable0B_2 + releasable0B_1 + releasable0B_0, "test_Release::178"
        );
        assertEq(vesting1A.released, releasable1A_1 + releasable1A_0, "test_Release::179");

        assertEq(amounts0.amountA, releasable0A_0, "test_Release::180");
        assertEq(amounts0.lockedA, total0A - releasable0A_0, "test_Release::181");
        assertEq(
            amounts0.amountB, releasable0B_3 + releasable0B_2 + releasable0B_1 + releasable0B_0, "test_Release::182"
        );
        assertEq(
            amounts0.lockedB,
            total0B - releasable0B_3 - releasable0B_2 - releasable0B_1 - releasable0B_0,
            "test_Release::183"
        );
        assertEq(
            amounts0.totalAmount,
            releasable0A_0 + releasable0B_3 + releasable0B_2 + releasable0B_1 + releasable0B_0,
            "test_Release::184"
        );
        assertEq(
            amounts0.totalLocked,
            total0A + total0B - releasable0B_3 - releasable0B_2 - releasable0B_1 - releasable0B_0 - releasable0A_0,
            "test_Release::185"
        );

        assertEq(amounts1.amountA, releasable1A_0, "test_Release::186");
        assertEq(amounts1.lockedA, 0, "test_Release::187");
        assertEq(amounts1.amountB, releasable1A_1, "test_Release::188");
        assertEq(amounts1.lockedB, 0, "test_Release::189");
        assertEq(amounts1.totalAmount, releasable1A_0 + releasable1A_1, "test_Release::190");
        assertEq(amounts1.totalLocked, 0, "test_Release::191");

        vm.warp(start0A + cliffDuration0A + vestingDuration0A);

        assertEq(staking.getVestedAmount(token0, 0, block.timestamp), total0A, "test_Release::192");
        assertEq(staking.getVestedAmount(token0, 1, block.timestamp), total0B, "test_Release::193");
        assertEq(staking.getVestedAmount(token1, 0, block.timestamp), total1A, "test_Release::194");

        assertEq(staking.getReleasableAmount(token0, 0), total0A - releasable0A_0, "test_Release::195");
        assertEq(
            staking.getReleasableAmount(token0, 1),
            total0B - releasable0B_3 - releasable0B_2 - releasable0B_1 - releasable0B_0,
            "test_Release::196"
        );
        assertEq(staking.getReleasableAmount(token1, 0), total1A - releasable1A_1 - releasable1A_0, "test_Release::197");

        staking.unlock(token0, 0);

        staking.unlock(token0, 1);

        vm.expectRevert(ITMStaking.TMStaking__ZeroUnlockedAmount.selector);
        staking.unlock(token1, 0);

        vesting0A = staking.getVestingScheduleAt(token0, 0);
        vesting0B = staking.getVestingScheduleAt(token0, 1);
        vesting1A = staking.getVestingScheduleAt(token1, 0);

        (amounts0.amountA, amounts0.lockedA) = staking.getStakeOf(token0, alice);
        (amounts0.amountB, amounts0.lockedB) = staking.getStakeOf(token0, bob);
        (amounts0.totalAmount, amounts0.totalLocked) = staking.getTotalStake(token0);

        (amounts1.amountA, amounts1.lockedA) = staking.getStakeOf(token1, alice);
        (amounts1.amountB, amounts1.lockedB) = staking.getStakeOf(token1, bob);
        (amounts1.totalAmount, amounts1.totalLocked) = staking.getTotalStake(token1);

        assertEq(vesting0A.released, total0A, "test_Release::198");
        assertEq(vesting0B.released, total0B, "test_Release::199");
        assertEq(vesting1A.released, total1A, "test_Release::200");

        assertEq(amounts0.amountA, total0A, "test_Release::201");
        assertEq(amounts0.lockedA, 0, "test_Release::202");
        assertEq(amounts0.amountB, total0B, "test_Release::203");
        assertEq(amounts0.lockedB, 0, "test_Release::204");
        assertEq(amounts0.totalAmount, total0A + total0B, "test_Release::205");
        assertEq(amounts0.totalLocked, 0, "test_Release::206");

        assertEq(amounts1.amountA, releasable1A_0, "test_Release::207");
        assertEq(amounts1.lockedA, 0, "test_Release::208");
        assertEq(amounts1.amountB, releasable1A_1, "test_Release::209");
        assertEq(amounts1.lockedB, 0, "test_Release::210");

        assertEq(IERC20(token0).balanceOf(alice), 0, "test_Release::211");
        assertEq(IERC20(token0).balanceOf(bob), 0, "test_Release::212");
        assertEq(IERC20(token1).balanceOf(alice), 0, "test_Release::213");
        assertEq(IERC20(token1).balanceOf(bob), 0, "test_Release::214");
    }

    function test_Fuzz_Revert_CreateVestingSchedule(
        address beneficiary,
        uint128 amount,
        uint80 start,
        uint80 cliffDuration,
        uint80 vestingDuration
    ) public {
        start = uint80(bound(start, block.timestamp, type(uint80).max - 1));
        vestingDuration = uint80(bound(vestingDuration, 1, type(uint80).max - start));
        cliffDuration = uint80(bound(cliffDuration, 0, vestingDuration));
        amount = uint128(bound(amount, 1, type(uint128).max));

        beneficiary = beneficiary == address(0) ? alice : beneficiary;

        (uint80 badCliffDuration, uint80 badVestingDuration) = vestingDuration == type(uint80).max
            ? (type(uint80).max, 0)
            : (uint80(bound(cliffDuration, vestingDuration + 1, type(uint80).max)), vestingDuration);

        vm.expectRevert(ITMStaking.TMStaking__ZeroBeneficiary.selector);
        staking.createVestingSchedule(token0, address(0), amount, 0, start, cliffDuration, vestingDuration);

        vm.expectRevert(ITMStaking.TMStaking__InvalidCliffDuration.selector);
        staking.createVestingSchedule(token0, beneficiary, amount, amount, start, badCliffDuration, badVestingDuration);

        uint80 badStart = uint80(bound(start, 0, block.timestamp - 1));
        badVestingDuration = uint80(bound(vestingDuration, 0, badStart));

        vm.expectRevert(ITMStaking.TMStaking__InvalidVestingSchedule.selector);
        staking.createVestingSchedule(token0, beneficiary, amount, amount, badStart, 0, badVestingDuration);

        deal(token0, address(this), uint256(type(uint128).max) + 1);
        IERC20(token0).approve(address(staking), uint256(type(uint128).max) + 1);

        vm.expectRevert(ITMStaking.TMStaking__ZeroAmount.selector);
        staking.createVestingSchedule(token0, beneficiary, 0, 0, start, cliffDuration, vestingDuration);

        if (amount == type(uint128).max) --amount;

        vm.expectRevert(
            abi.encodeWithSelector(ITMStaking.TMStaking__InsufficientAmountReceived.selector, amount, amount + 1)
        );
        staking.createVestingSchedule(token0, beneficiary, amount, amount + 1, start, cliffDuration, vestingDuration);
    }

    function test_Fuzz_Revert_transferVesting(uint256 amount) public {
        amount = bound(amount, 1, type(uint128).max);

        deal(token0, address(this), amount);
        IERC20(token0).approve(address(staking), amount);

        uint256 start = block.timestamp + 1;
        uint256 cliffDuration = 10;
        uint256 vestingDuration = 100;

        staking.createVestingSchedule(
            token0,
            alice,
            uint128(amount),
            uint128(amount),
            uint80(start),
            uint80(cliffDuration),
            uint80(vestingDuration)
        );

        vm.prank(alice);
        vm.expectRevert(ITMStaking.TMStaking__ZeroBeneficiary.selector);
        staking.transferVesting(token0, address(0), 0);

        vm.prank(alice);
        vm.expectRevert(ITMStaking.TMStaking__SameBeneficiary.selector);
        staking.transferVesting(token0, alice, 0);

        address newBeneficiary = bob;

        vm.expectRevert(ITMStaking.TMStaking__OnlyBeneficiary.selector);
        vm.prank(newBeneficiary);
        staking.transferVesting(token0, newBeneficiary, 0);

        vm.prank(alice);
        staking.transferVesting(token0, newBeneficiary, 0);

        vm.expectRevert(ITMStaking.TMStaking__OnlyBeneficiary.selector);
        vm.prank(alice);
        staking.transferVesting(token0, alice, 0);

        vm.warp(start + cliffDuration + vestingDuration);

        vm.expectRevert(ITMStaking.TMStaking__VestingExpired.selector);
        vm.prank(newBeneficiary);
        staking.transferVesting(token0, alice, 0);

        staking.unlock(token0, 0);

        vm.expectRevert(ITMStaking.TMStaking__VestingExpired.selector);
        vm.prank(newBeneficiary);
        staking.transferVesting(token0, alice, 0);
    }

    function test_Claim(uint256 amountA, uint256 amountB) public {
        amountA = bound(amountA, 1e12, 1e24); // Limit to this range to prevent annoying rounding issue
        amountB = bound(amountB, 1e12, 1e24);

        uint256 totalAmount = amountA + amountB;

        deal(token0, address(this), totalAmount);
        IERC20(token0).approve(address(staking), amountA + amountB);

        (, uint256 pendingRewards) = ITMMarket(market0w).getPendingFees();

        assertEq(pendingRewards, 0, "test_Claim::1");
        assertEq(staking.getPendingRewards(token0, alice), 0, "test_Claim::2");
        assertEq(staking.getPendingRewards(token0, bob), 0, "test_Claim::3");

        staking.deposit(token0, alice, amountA, amountA);
        staking.createVestingSchedule(token0, bob, uint128(amountB), uint128(amountB), uint80(block.timestamp), 10, 100);

        (, pendingRewards) = ITMMarket(market0w).getPendingFees();

        assertEq(pendingRewards, 0, "test_Claim::4");
        assertEq(staking.getPendingRewards(token0, alice), 0, "test_Claim::5");
        assertEq(staking.getPendingRewards(token0, bob), 0, "test_Claim::6");

        router.swapExactIn{value: 1e18}(
            abi.encodePacked(address(0), uint32(3 << 24), token0), address(this), 1e18, 0, block.timestamp, address(0)
        );

        (, pendingRewards) = ITMMarket(market0w).getPendingFees();
        uint256 pendingRewardsA_1 = staking.getPendingRewards(token0, alice);
        uint256 pendingRewardsB_1 = staking.getPendingRewards(token0, bob);

        assertGt(pendingRewards, 0, "test_Claim::7");
        assertApproxEqRel(pendingRewardsA_1, amountA * pendingRewards / totalAmount, 1e14, "test_Claim::8");
        assertApproxEqRel(pendingRewardsB_1, amountB * pendingRewards / totalAmount, 1e14, "test_Claim::9");

        vm.prank(alice);
        staking.claimRewards(token0, alice);

        assertEq(staking.getPendingRewards(token0, alice), 0, "test_Claim::10");
        assertEq(staking.getPendingRewards(token0, bob), pendingRewardsB_1, "test_Claim::11");

        assertEq(IERC20(wnative).balanceOf(alice), pendingRewardsA_1, "test_Claim::12");
        assertEq(IERC20(wnative).balanceOf(bob), 0, "test_Claim::13");

        router.swapExactIn{value: 10e18}(
            abi.encodePacked(address(0), uint32(3 << 24), token0), address(this), 10e18, 0, block.timestamp, address(0)
        );

        (, pendingRewards) = ITMMarket(market0w).getPendingFees();
        uint256 pendingRewardsA_2 = staking.getPendingRewards(token0, alice);
        uint256 pendingRewardsB_2 = staking.getPendingRewards(token0, bob);

        assertGt(pendingRewards, 0, "test_Claim::14");
        assertApproxEqRel(pendingRewardsA_2, amountA * pendingRewards / totalAmount, 1e14, "test_Claim::15");
        assertApproxEqRel(
            pendingRewardsB_2, pendingRewardsB_1 + amountB * pendingRewards / totalAmount, 1e14, "test_Claim::16"
        );

        vm.prank(bob);
        staking.claimRewards(token0, bob);

        assertEq(staking.getPendingRewards(token0, alice), pendingRewardsA_2, "test_Claim::17");
        assertEq(staking.getPendingRewards(token0, bob), 0, "test_Claim::18");

        assertEq(IERC20(wnative).balanceOf(alice), pendingRewardsA_1, "test_Claim::19");
        assertEq(IERC20(wnative).balanceOf(bob), pendingRewardsB_2, "test_Claim::20");

        vm.warp(block.timestamp + 50);

        staking.unlock(token0, 0);

        router.swapExactIn{value: 1e18}(
            abi.encodePacked(address(0), uint32(3 << 24), token0), address(this), 1e18, 0, block.timestamp, address(0)
        );

        (, pendingRewards) = ITMMarket(market0w).getPendingFees();
        uint256 pendingRewardsA_3 = staking.getPendingRewards(token0, alice);
        uint256 pendingRewardsB_3 = staking.getPendingRewards(token0, bob);

        assertGt(pendingRewards, 0, "test_Claim::21");
        assertApproxEqRel(
            pendingRewardsA_3, pendingRewardsA_2 + amountA * pendingRewards / totalAmount, 1e14, "test_Claim::22"
        );
        assertApproxEqRel(pendingRewardsB_3, amountB * pendingRewards / totalAmount, 1e14, "test_Claim::23");

        vm.prank(alice);
        staking.claimRewards(token0, alice);

        vm.prank(bob);
        staking.claimRewards(token0, bob);

        assertEq(staking.getPendingRewards(token0, alice), 0, "test_Claim::24");
        assertEq(staking.getPendingRewards(token0, bob), 0, "test_Claim::25");

        assertEq(IERC20(wnative).balanceOf(alice), pendingRewardsA_3 + pendingRewardsA_1, "test_Claim::26");
        assertEq(IERC20(wnative).balanceOf(bob), pendingRewardsB_3 + pendingRewardsB_2, "test_Claim::27");

        vm.prank(alice);
        staking.claimRewards(token0, alice);

        vm.prank(bob);
        staking.claimRewards(token0, bob);

        assertEq(staking.getPendingRewards(token0, alice), 0, "test_Claim::28");
        assertEq(staking.getPendingRewards(token0, bob), 0, "test_Claim::29");

        assertEq(IERC20(wnative).balanceOf(alice), pendingRewardsA_3 + pendingRewardsA_1, "test_Claim::30");
        assertEq(IERC20(wnative).balanceOf(bob), pendingRewardsB_3 + pendingRewardsB_2, "test_Claim::31");
    }

    function test_revert_GetPendingRewards() public {
        vm.expectRevert(abi.encodeWithSelector(ITMStaking.TMStaking__InvalidToken.selector, address(0)));
        staking.getPendingRewards(address(0), address(0));
    }
}
