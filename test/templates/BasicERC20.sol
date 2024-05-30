// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";

import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";
import {Initializable} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";

import {BasicERC20, BaseERC20} from "../../src/templates/BasicERC20.sol";

contract BasicERC20Test is Test {
    address implementation;

    function setUp() public {
        implementation = address(new BasicERC20(address(this)));
    }

    function test_Fuzz_Initialize(string memory name, string memory symbol, uint8 decimals) public {
        BasicERC20 token = BasicERC20(Clones.clone(implementation));

        vm.expectRevert(BasicERC20.BasicERC20__InvalidArgsLength.selector);
        token.initialize(name, symbol, new bytes(0));

        vm.expectRevert(BasicERC20.BasicERC20__InvalidArgsLength.selector);
        token.initialize(name, symbol, new bytes(31));

        token.initialize(name, symbol, abi.encode(decimals));

        assertEq(name, token.name(), "test_Fuzz_Initialize::1");
        assertEq(symbol, token.symbol(), "test_Fuzz_Initialize::2");
        assertEq(decimals, token.decimals(), "test_Fuzz_Initialize::3");

        vm.expectRevert(Initializable.InvalidInitialization.selector);
        token.initialize(name, symbol, abi.encode(decimals));
    }

    function test_Fuzz_FactoryMint(address to, uint256 amount) public {
        BasicERC20 token = BasicERC20(Clones.clone(implementation));
        token.initialize("Test", "TST", abi.encode(18));

        assertEq(address(this), token.factory(), "test_Fuzz_FactoryMint::0");

        token.factoryMint(to, amount);

        assertEq(amount, token.balanceOf(to), "test_Fuzz_FactoryMint::1");

        if (to == address(this)) to = address(1);

        vm.prank(address(to));
        vm.expectRevert(BaseERC20.BaseERC20__OnlyFactory.selector);
        token.factoryMint(to, amount);
    }
}
