// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import {CToken} from "../contracts/CToken.sol";
import {CErc20Delegator} from "../contracts/CErc20Delegator.sol";
import {CErc20Delegate} from "../contracts/CErc20Delegate.sol";
import {WhitePaperInterestRateModel} from "../contracts/WhitePaperInterestRateModel.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ComptrollerG7} from "../contracts/ComptrollerG7.sol";
import {SimplePriceOracle} from "../contracts/SimplePriceOracle.sol";
import {Unitroller} from "../contracts/Unitroller.sol";
import {FlashLoanLiquidate} from "../contracts/FlashLoanLiquidate.sol";

contract HW14Test is Test {
    // Use $USDC 以及 $UNI as token A and Token B relatively
    ERC20 USDC = ERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
    ERC20 UNI = ERC20(0x1f9840a85d5aF5bf1D1762F925BDADdC4201F984);
    ComptrollerG7 comptroller;
    CErc20Delegator cUSDC;
    CErc20Delegator cUNI;
    CErc20Delegate impl;
    WhitePaperInterestRateModel model;
    Unitroller unitroller;
    SimplePriceOracle oracle;
    FlashLoanLiquidate flashLoanLiquidate;
    ComptrollerG7 comptrollerProxy;

    address admin = makeAddr("admin");
    address user1 = makeAddr("user1");
    address user2 = makeAddr("user2");
    address user3 = makeAddr("user3");
    uint256 initialUSDC = 5000 * 1e6;
    uint256 initialUNI = 5000 * 1e18;

    function setUp() public {
        // 1. Fork Ethereum mainnet at block 17465000
        vm.createSelectFork(vm.envString("MAINNET_RPC_URL"), 17465000);

        vm.startPrank(admin);
        impl = new CErc20Delegate();
        model = new WhitePaperInterestRateModel(0, 0);
        comptroller = new ComptrollerG7();
        unitroller = new Unitroller();
        oracle = new SimplePriceOracle();

        unitroller._setPendingImplementation(address(comptroller));

        comptroller._become(unitroller);

        comptrollerProxy = ComptrollerG7(address(unitroller));

        // 2. cERC20 的 decimals 皆為 18，初始 exchangeRate 為 1:1
        cUSDC = new CErc20Delegator(
            address(USDC),
            comptrollerProxy,
            model,
            1e6,
            "Compound USDC",
            "cUSDC",
            18,
            payable(admin),
            address(impl),
            new bytes(0)
        );
        cUNI = new CErc20Delegator(
            address(UNI),
            comptrollerProxy,
            model,
            1e18,
            "Compound UNI",
            "cUNI",
            18,
            payable(admin),
            address(impl),
            new bytes(0)
        );
        comptrollerProxy._supportMarket(CToken(address(cUSDC)));
        comptrollerProxy._supportMarket(CToken(address(cUNI)));
        // 3. Close factor 設定為 50%
        comptrollerProxy._setCloseFactor(5e17);
        // 4. Liquidation incentive 設為 8% (1.08 * 1e18)
        comptrollerProxy._setLiquidationIncentive(1.08 * 1e18);
        // 5. 在 Oracle 中設定 USDC 的價格為 $1，UNI 的價格為 $5
        comptrollerProxy._setPriceOracle(oracle);
        oracle.setUnderlyingPrice(CToken(address(cUSDC)), 1e30);
        oracle.setUnderlyingPrice(CToken(address(cUNI)), 5e18);
        // 6. 設定 UNI 的 collateral factor 為 50%
        comptrollerProxy._setCollateralFactor(CToken(address(cUNI)), 5e17);
        comptrollerProxy._supportMarket(CToken(address(cUSDC)));
        comptrollerProxy._supportMarket(CToken(address(cUNI)));

        vm.stopPrank();

        deal(address(USDC), user1, initialUSDC);
        deal(address(USDC), user3, initialUSDC);
        deal(address(UNI), user1, initialUNI);
        deal(address(UNI), user3, initialUNI);
    }

    function testHW14() public {
        // 先使用 User3 存 USDC 讓 User1 有 USDC 可以借出
        vm.startPrank(user3);
        USDC.approve(address(cUSDC), initialUSDC);
        cUSDC.mint(initialUSDC);
        vm.stopPrank();

        // 7. User1 使用 1000 顆 UNI 作為抵押品借出 2500 顆 USDC
        vm.startPrank(user1);
        UNI.approve(address(cUNI), type(uint256).max);
        cUNI.mint(1000 * 1e18);
        address[] memory cTokens = new address[](1);
        cTokens[0] = address(cUNI);
        comptrollerProxy.enterMarkets(cTokens);
        cUSDC.borrow(2500 * 1e6);
        assertEq(USDC.balanceOf(user1), initialUSDC + 2500 * 1e6);
        vm.stopPrank();

        // 8. 將 UNI 價格改為 $4 使 User1 產生 Shortfall，並讓 User2 透過 AAVE 的 Flash loan 來借錢清算 User1
        oracle.setUnderlyingPrice(CToken(address(cUNI)), 4e18);
        (,, uint256 shortfall) = comptrollerProxy.getAccountLiquidity(user1);
        require(shortfall > 0, "no shortfall");

        vm.startPrank(user2);

        uint256 borrowBalance = cUSDC.borrowBalanceStored(user1);
        uint256 repalyAmount = borrowBalance / 2;
        bytes memory data = abi.encode(cUSDC, cUNI, user1);
        
        flashLoanLiquidate = new FlashLoanLiquidate();
        flashLoanLiquidate.requestFlashLoan(address(USDC), repalyAmount, data);
        flashLoanLiquidate.withdraw(address(USDC));

        // 9. 可以自行檢查清算 50% 後是不是大約可以賺 63 USDC
        assertGe(USDC.balanceOf(user2), 63 * 1e6);
        assertLt(USDC.balanceOf(user2), 64 * 1e6);

        vm.stopPrank();
    }
}