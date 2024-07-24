// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";

import "../src/CliffVestingContract.sol";
import "./mocks/MockERC20.sol";

contract CliffVestingContractTest is Test {
    CliffVestingContract vesting;

    address alice = makeAddr("alice");
    address bob = makeAddr("bob");

    MockERC20 token0;
    MockERC20 token1;

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

    function setUp() public {
        token0 = new MockERC20("token0", "TKN0", 18);
        token1 = new MockERC20("token1", "TKN1", 6);

        vesting = new CliffVestingContract();
    }

    function test_Release() public {
        token0.mint(address(this), total0A + total0B);
        token1.mint(address(this), total1A);

        token0.approve(address(vesting), total0A + total0B);
        token1.approve(address(vesting), total1A);

        vesting.createVestingSchedule(
            address(token0), alice, total0A, total0A, start0A, cliffDuration0A, vestingDuration0A
        );

        vesting.createVestingSchedule(
            address(token0), bob, total0B, total0B, start0B, cliffDuration0B, vestingDuration0B
        );

        vesting.createVestingSchedule(
            address(token1), alice, total1A, total1A, start1A, cliffDuration1A, vestingDuration1A
        );

        assertEq(vesting.getNumberOfVestings(address(token0)), 2, "test_Release::1");
        assertEq(vesting.getNumberOfVestings(address(token1)), 1, "test_Release::2");

        ICliffVestingContract.VestingSchedule memory vesting0A = vesting.getVestingSchedule(address(token0), 0);
        ICliffVestingContract.VestingSchedule memory vesting0B = vesting.getVestingSchedule(address(token0), 1);
        ICliffVestingContract.VestingSchedule memory vesting1A = vesting.getVestingSchedule(address(token1), 0);

        assertEq(vesting0A.beneficiary, alice, "test_Release::3");
        assertEq(vesting0A.total, total0A, "test_Release::4");
        assertEq(vesting0A.released, 0, "test_Release::5");
        assertEq(vesting0A.start, start0A, "test_Release::6");
        assertEq(vesting0A.cliffDuration, cliffDuration0A, "test_Release::7");
        assertEq(vesting0A.vestingDuration, vestingDuration0A, "test_Release::8");

        assertEq(vesting0B.beneficiary, bob, "test_Release::9");
        assertEq(vesting0B.total, total0B, "test_Release::10");
        assertEq(vesting0B.released, 0, "test_Release::11");
        assertEq(vesting0B.start, start0B, "test_Release::12");
        assertEq(vesting0B.cliffDuration, cliffDuration0B, "test_Release::13");
        assertEq(vesting0B.vestingDuration, vestingDuration0B, "test_Release::14");

        assertEq(vesting1A.beneficiary, alice, "test_Release::15");
        assertEq(vesting1A.total, total1A, "test_Release::16");
        assertEq(vesting1A.released, 0, "test_Release::17");
        assertEq(vesting1A.start, start1A, "test_Release::18");
        assertEq(vesting1A.cliffDuration, cliffDuration1A, "test_Release::19");
        assertEq(vesting1A.vestingDuration, vestingDuration1A, "test_Release::20");

        vm.expectRevert(ICliffVestingContract.CliffVestingContract__OnlyBeneficiary.selector);
        vm.prank(bob);
        vesting.release(address(token0), 0);

        vm.expectRevert(ICliffVestingContract.CliffVestingContract__OnlyBeneficiary.selector);
        vm.prank(alice);
        vesting.release(address(token0), 1);

        vm.expectRevert(ICliffVestingContract.CliffVestingContract__OnlyBeneficiary.selector);
        vm.prank(bob);
        vesting.release(address(token1), 0);

        vm.warp(start0B - 1);

        assertEq(vesting.getReleasableAmount(address(token0), 0), 0, "test_Release::21");
        assertEq(vesting.getReleasableAmount(address(token0), 1), 0, "test_Release::22");
        assertEq(vesting.getReleasableAmount(address(token1), 0), 0, "test_Release::23");

        vm.prank(alice);
        vm.expectRevert(ICliffVestingContract.CliffVestingContract__NoVestedAmount.selector);
        vesting.release(address(token0), 0);

        vm.prank(bob);
        vm.expectRevert(ICliffVestingContract.CliffVestingContract__NoVestedAmount.selector);
        vesting.release(address(token0), 1);

        vm.prank(alice);
        vm.expectRevert(ICliffVestingContract.CliffVestingContract__NoVestedAmount.selector);
        vesting.release(address(token1), 0);

        vesting0A = vesting.getVestingSchedule(address(token0), 0);
        vesting0B = vesting.getVestingSchedule(address(token0), 1);
        vesting1A = vesting.getVestingSchedule(address(token1), 0);

        assertEq(vesting0A.released, 0, "test_Release::24");
        assertEq(vesting0B.released, 0, "test_Release::25");
        assertEq(vesting1A.released, 0, "test_Release::26");

        vm.warp(start0B);

        vm.prank(alice);
        vm.expectRevert(ICliffVestingContract.CliffVestingContract__NoVestedAmount.selector);
        vesting.release(address(token0), 0);

        vm.prank(bob);
        vm.expectRevert(ICliffVestingContract.CliffVestingContract__NoVestedAmount.selector);
        vesting.release(address(token0), 1);

        vm.prank(alice);
        vm.expectRevert(ICliffVestingContract.CliffVestingContract__NoVestedAmount.selector);
        vesting.release(address(token1), 0);

        vesting0A = vesting.getVestingSchedule(address(token0), 0);
        vesting0B = vesting.getVestingSchedule(address(token0), 1);
        vesting1A = vesting.getVestingSchedule(address(token1), 0);

        assertEq(vesting0A.released, 0, "test_Release::27");
        assertEq(vesting0B.released, 0, "test_Release::28");
        assertEq(vesting1A.released, 0, "test_Release::29");

        vm.warp(start0B + cliffDuration0B);

        vm.prank(alice);
        vm.expectRevert(ICliffVestingContract.CliffVestingContract__NoVestedAmount.selector);
        vesting.release(address(token0), 0);

        vm.prank(bob);
        vm.expectRevert(ICliffVestingContract.CliffVestingContract__NoVestedAmount.selector);
        vesting.release(address(token0), 1);

        vm.prank(alice);
        vm.expectRevert(ICliffVestingContract.CliffVestingContract__NoVestedAmount.selector);
        vesting.release(address(token1), 0);

        vesting0A = vesting.getVestingSchedule(address(token0), 0);
        vesting0B = vesting.getVestingSchedule(address(token0), 1);
        vesting1A = vesting.getVestingSchedule(address(token1), 0);

        assertEq(vesting0A.released, 0, "test_Release::30");
        assertEq(vesting0B.released, 0, "test_Release::31");
        assertEq(vesting1A.released, 0, "test_Release::32");

        vm.warp(start1A);

        uint256 releasable0B_0 = vesting0B.total * (block.timestamp - start0B) / vestingDuration0B;

        vm.prank(alice);
        vm.expectRevert(ICliffVestingContract.CliffVestingContract__NoVestedAmount.selector);
        vesting.release(address(token0), 0);

        vm.prank(bob);
        vesting.release(address(token0), 1);

        vm.prank(alice);
        vm.expectRevert(ICliffVestingContract.CliffVestingContract__NoVestedAmount.selector);
        vesting.release(address(token1), 0);

        vesting0A = vesting.getVestingSchedule(address(token0), 0);
        vesting0B = vesting.getVestingSchedule(address(token0), 1);
        vesting1A = vesting.getVestingSchedule(address(token1), 0);

        assertEq(vesting0A.released, 0, "test_Release::33");
        assertEq(vesting0B.released, releasable0B_0, "test_Release::34");
        assertEq(vesting1A.released, 0, "test_Release::35");

        assertEq(token0.balanceOf(alice), 0, "test_Release::36");
        assertEq(token0.balanceOf(bob), releasable0B_0, "test_Release::37");
        assertEq(token1.balanceOf(alice), 0, "test_Release::38");

        vm.warp(start1A + cliffDuration1A + vestingDuration1A / 2);

        uint256 releasable1A_0 = vesting1A.total * (block.timestamp - start1A) / vestingDuration1A;
        uint256 releasable0B_1 = vesting0B.total * (block.timestamp - start0B) / vestingDuration0B - releasable0B_0;

        vm.prank(alice);
        vm.expectRevert(ICliffVestingContract.CliffVestingContract__NoVestedAmount.selector);
        vesting.release(address(token0), 0);

        vm.prank(bob);
        vesting.release(address(token0), 1);

        vm.prank(alice);
        vesting.release(address(token1), 0);

        vesting0A = vesting.getVestingSchedule(address(token0), 0);
        vesting0B = vesting.getVestingSchedule(address(token0), 1);
        vesting1A = vesting.getVestingSchedule(address(token1), 0);

        assertEq(vesting0A.released, 0, "test_Release::39");
        assertEq(vesting0B.released, releasable0B_1 + releasable0B_0, "test_Release::40");
        assertEq(vesting1A.released, releasable1A_0, "test_Release::41");

        assertEq(token0.balanceOf(alice), 0, "test_Release::42");
        assertEq(token0.balanceOf(bob), releasable0B_1 + releasable0B_0, "test_Release::43");
        assertEq(token1.balanceOf(alice), releasable1A_0, "test_Release::44");

        vm.warp(start1A + cliffDuration1A + vestingDuration1A + 1);

        vm.prank(alice);
        vesting.transferVestingSchedule(address(token1), bob, 0);

        uint256 releasable1A_1 = vesting1A.total - releasable1A_0;
        uint256 releasable0B_2 =
            vesting0B.total * (block.timestamp - start0B) / vestingDuration0B - releasable0B_1 - releasable0B_0;

        vm.prank(alice);
        vm.expectRevert(ICliffVestingContract.CliffVestingContract__NoVestedAmount.selector);
        vesting.release(address(token0), 0);

        vm.prank(bob);
        vesting.release(address(token0), 1);

        vm.expectRevert(ICliffVestingContract.CliffVestingContract__OnlyBeneficiary.selector);
        vm.prank(alice);
        vesting.release(address(token1), 0);

        vm.prank(bob);
        vesting.release(address(token1), 0);

        vesting0A = vesting.getVestingSchedule(address(token0), 0);
        vesting0B = vesting.getVestingSchedule(address(token0), 1);
        vesting1A = vesting.getVestingSchedule(address(token1), 0);

        assertEq(vesting0A.released, 0, "test_Release::45");
        assertEq(vesting0B.released, releasable0B_2 + releasable0B_1 + releasable0B_0, "test_Release::46");
        assertEq(vesting1A.beneficiary, bob, "test_Release::47");
        assertEq(vesting1A.released, releasable1A_1 + releasable1A_0, "test_Release::48");

        assertEq(token0.balanceOf(alice), 0, "test_Release::49");
        assertEq(token0.balanceOf(bob), releasable0B_2 + releasable0B_1 + releasable0B_0, "test_Release::50");
        assertEq(token1.balanceOf(alice), releasable1A_0, "test_Release::51");
        assertEq(token1.balanceOf(bob), releasable1A_1, "test_Release::52");

        vm.warp(start0A + cliffDuration0A);

        uint256 releasable0B_3 = vesting0B.total * (block.timestamp - start0B) / vestingDuration0B - releasable0B_2
            - releasable0B_1 - releasable0B_0;

        vm.prank(alice);
        vm.expectRevert(ICliffVestingContract.CliffVestingContract__NoVestedAmount.selector);
        vesting.release(address(token0), 0);

        vm.prank(bob);
        vesting.release(address(token0), 1);

        vm.prank(bob);
        vm.expectRevert(ICliffVestingContract.CliffVestingContract__NoVestedAmount.selector);
        vesting.release(address(token1), 0);

        vesting0A = vesting.getVestingSchedule(address(token0), 0);
        vesting0B = vesting.getVestingSchedule(address(token0), 1);
        vesting1A = vesting.getVestingSchedule(address(token1), 0);

        assertEq(vesting0A.released, 0, "test_Release::53");
        assertEq(
            vesting0B.released, releasable0B_3 + releasable0B_2 + releasable0B_1 + releasable0B_0, "test_Release::54"
        );
        assertEq(vesting1A.released, releasable1A_1 + releasable1A_0, "test_Release::55");

        assertEq(token0.balanceOf(alice), 0, "test_Release::56");
        assertEq(
            token0.balanceOf(bob), releasable0B_3 + releasable0B_2 + releasable0B_1 + releasable0B_0, "test_Release::57"
        );
        assertEq(token1.balanceOf(alice), releasable1A_0, "test_Release::58");

        vm.warp(start0A + cliffDuration0A + vestingDuration0A);

        vm.prank(alice);
        vesting.release(address(token0), 0);

        vm.prank(bob);
        vesting.release(address(token0), 1);

        vm.prank(bob);
        vm.expectRevert(ICliffVestingContract.CliffVestingContract__NoVestedAmount.selector);
        vesting.release(address(token1), 0);

        vesting0A = vesting.getVestingSchedule(address(token0), 0);
        vesting0B = vesting.getVestingSchedule(address(token0), 1);
        vesting1A = vesting.getVestingSchedule(address(token1), 0);

        assertEq(vesting0A.released, total0A, "test_Release::59");
        assertEq(vesting0B.released, total0B, "test_Release::60");
        assertEq(vesting1A.released, total1A, "test_Release::61");

        assertEq(token0.balanceOf(alice), total0A, "test_Release::62");
        assertEq(token0.balanceOf(bob), total0B, "test_Release::63");
        assertEq(token1.balanceOf(alice), releasable1A_0, "test_Release::64");
        assertEq(token1.balanceOf(bob), total1A - releasable1A_0, "test_Release::65");
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

        (uint80 badCliffDuration, uint80 badVestingDuration) = vestingDuration == type(uint80).max
            ? (type(uint80).max, 0)
            : (uint80(bound(cliffDuration, vestingDuration + 1, type(uint80).max)), vestingDuration);

        vm.expectRevert(ICliffVestingContract.CliffVestingContract__InvalidCliffDuration.selector);
        vesting.createVestingSchedule(
            address(token0), beneficiary, amount, amount, start, badCliffDuration, badVestingDuration
        );

        uint80 badStart = uint80(bound(start, 0, block.timestamp - 1));
        badVestingDuration = uint80(bound(vestingDuration, 0, badStart));

        vm.expectRevert(ICliffVestingContract.CliffVestingContract__InvalidVestingSchedule.selector);
        vesting.createVestingSchedule(address(token0), beneficiary, amount, amount, badStart, 0, badVestingDuration);

        vm.expectRevert(ICliffVestingContract.CliffVestingContract__ZeroMinAmount.selector);
        vesting.createVestingSchedule(address(token0), beneficiary, amount, 0, start, cliffDuration, vestingDuration);
    }

    function test_Fuzz_Revert_TransferVestingSchedule(address newBeneficiary, uint256 amount) public {
        amount = bound(amount, 1, type(uint128).max);

        token0.mint(address(this), amount);

        token0.approve(address(vesting), amount);

        vesting.createVestingSchedule(
            address(token0), alice, uint128(amount), uint128(amount), uint80(block.timestamp), 0, 1
        );

        newBeneficiary = newBeneficiary == alice ? bob : newBeneficiary;

        vm.expectRevert(ICliffVestingContract.CliffVestingContract__OnlyBeneficiary.selector);
        vm.prank(newBeneficiary);
        vesting.transferVestingSchedule(address(token0), newBeneficiary, 0);

        vm.prank(alice);
        vesting.transferVestingSchedule(address(token0), newBeneficiary, 0);

        vm.expectRevert(ICliffVestingContract.CliffVestingContract__OnlyBeneficiary.selector);
        vm.prank(alice);
        vesting.transferVestingSchedule(address(token0), newBeneficiary, 0);
    }
}
