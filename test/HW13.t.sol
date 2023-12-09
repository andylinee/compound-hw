// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import { console2 } from "forge-std/Script.sol";
import "../script/HW13.s.sol";

contract HW13Test is Test, HW13Script {
    address admin = makeAddr("admin");
    address user1 = makeAddr("user1");
    address user2 = makeAddr("user2");
    address user3 = makeAddr("user3");
    uint256 initialBalance = 100 ether;

    function setUp() public {
        vm.startPrank(admin);
        _deploy(admin);
        vm.stopPrank();

        deal(address(bearTokenA), user1, initialBalance);
        deal(address(bearTokenA), user2, initialBalance);
        deal(address(bearTokenA), user3, initialBalance);
        deal(address(bearTokenB), user1, initialBalance);
        deal(address(bearTokenB), user2, initialBalance);
        deal(address(bearTokenB), user3, initialBalance);
    }

    // 第 2 題
    function testMintAndRedeem() public {
        vm.startPrank(user1);

        // Mint
        // Arrange
        bearTokenA.approve(address(cTokenA), type(uint256).max);
        // Act
        cTokenA.mint(100 ether);
        // Assert
        assertEq(bearTokenA.balanceOf(user1), initialBalance - 100 ether);
        assertEq(cTokenA.balanceOf(user1), 100 ether);

        // Redeem
        // Act
        cTokenA.redeem(100 ether);
        // Assert
        assertEq(bearTokenA.balanceOf(user1), initialBalance);
        assertEq(cTokenA.balanceOf(user1), 0);

        vm.stopPrank();
    }
    
}