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
        /// Arrange
        bearTokenA.approve(address(cTokenA), type(uint256).max);
        // Act
        cTokenA.mint(100 ether);
        /// Assert
        assertEq(bearTokenA.balanceOf(user1), initialBalance - 100 ether);
        assertEq(cTokenA.balanceOf(user1), 100 ether);

        // Redeem
        /// Act
        cTokenA.redeem(100 ether);
        /// Assert
        assertEq(bearTokenA.balanceOf(user1), initialBalance);
        assertEq(cTokenA.balanceOf(user1), 0);

        vm.stopPrank();
    }

    // 第 3 題
    function testBorrowAndRepay() public {
        _borrow();

        vm.startPrank(user1);
        bearTokenA.approve(address(cTokenA), type(uint256).max);
        cTokenA.repayBorrow(50 ether);
        assertEq(bearTokenA.balanceOf(user1), initialBalance);
        vm.stopPrank();
    }

    // 第 4 題
    function testBorrowAndLiquidateQ4() public {
        _borrow();

        vm.startPrank(admin);
        ComptrollerG7(address(unitroller))._setCollateralFactor(CToken(address(cTokenB)), 2e17);
        vm.stopPrank();

        vm.startPrank(user2);
        bearTokenA.approve(address(cTokenA), type(uint256).max);

        (, , uint256 shortfall) = ComptrollerG7(address(unitroller)).getAccountLiquidity(user1);
        require(shortfall > 0, "No shortfall");
        uint256 borrowBalance = cTokenA.borrowBalanceStored(user1);

        cTokenA.liquidateBorrow(user1, borrowBalance / 2, cTokenB);
        assertEq(bearTokenA.balanceOf(user2), initialBalance - borrowBalance / 2);

        (, uint256 seizeTokens) = ComptrollerG7(address(unitroller)).liquidateCalculateSeizeTokens(
            address(cTokenA), address(cTokenB), borrowBalance / 2 
        );

        uint256 finalBalance = seizeTokens * (1e18 - cTokenA.protocolSeizeShareMantissa()) / 1e18;
        assertEq(cTokenB.balanceOf(user2), finalBalance);
        vm.stopPrank();
    }

    function testBorrowAndLiquidateQ5() public {
        _borrow();

        vm.startPrank(admin);
        oracle.setUnderlyingPrice(CToken(address(cTokenB)), 5e19);
        vm.stopPrank();

        vm.startPrank(user2);
        bearTokenA.approve(address(cTokenA), type(uint256).max);

        (, , uint256 shortfall) = ComptrollerG7(address(unitroller)).getAccountLiquidity(user1);
        require(shortfall > 0, "No shortfall");
        uint256 borrowBalance = cTokenA.borrowBalanceStored(user1);

        cTokenA.liquidateBorrow(user1, borrowBalance / 2, cTokenB);
        assertEq(bearTokenA.balanceOf(user2), initialBalance - borrowBalance / 2);

        (, uint256 seizeTokens) = ComptrollerG7(address(unitroller)).liquidateCalculateSeizeTokens(
            address(cTokenA), address(cTokenB), borrowBalance / 2 
        );
        uint256 finalBalance = seizeTokens * (1e18 - cTokenA.protocolSeizeShareMantissa()) / 1e18;
        assertEq(cTokenB.balanceOf(user2), finalBalance);
        vm.stopPrank();
    }

    function _borrow() private {
        // 
        vm.startPrank(user3);
        bearTokenA.approve(address(cTokenA), type(uint256).max);
        cTokenA.mint(100 ether);
        vm.stopPrank();

        // User1 使用 1 顆 token B 來 mint cToken
        vm.startPrank(user1);
        bearTokenB.approve(address(cTokenB), type(uint256).max);
        cTokenB.mint(1 ether);
        assertEq(cTokenB.balanceOf(user1), 1 ether);

        // User1 使用 token B 作為抵押品來借出 50 顆 token A
        address[] memory cTokens = new address[](1);
        cTokens[0] = address(cTokenB);
        ComptrollerG7(address(unitroller)).enterMarkets(cTokens);
        cTokenA.borrow(50 ether);
        assertEq(bearTokenA.balanceOf(user1), initialBalance + 50 ether);
        vm.stopPrank();
    }

}