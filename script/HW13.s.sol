// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { Script, console2 } from "forge-std/Script.sol";
import { CErc20Delegator } from "../contracts/CErc20Delegator.sol";
import { CErc20Delegate } from "../contracts/CErc20Delegate.sol";
import { CToken } from "../contracts/CToken.sol";
import { WhitePaperInterestRateModel } from "../contracts/WhitePaperInterestRateModel.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { BearTokenA, BearTokenB } from "../contracts/BearToken.sol";
import { ComptrollerG7 } from "../contracts/ComptrollerG7.sol";
import { SimplePriceOracle } from "../contracts/SimplePriceOracle.sol";
import { Unitroller } from "../contracts/Unitroller.sol";

contract HW13Script is Script {
    ERC20 bearTokenA;
    ERC20 bearTokenB;
    ComptrollerG7 comptroller;
    CErc20Delegate impl;
    CErc20Delegator cTokenA;
    CErc20Delegator cTokenB;
    WhitePaperInterestRateModel model;
    uint256 initialExchangeRateMantissa;
    uint256 newExchangeRateMantissa;
    uint256 liquidationIncentiveMantissa;
    
    Unitroller unitroller;
    SimplePriceOracle oracle;

    function run() external {
        vm.startBroadcast();
        _deploy(address(this));
        vm.stopBroadcast();
    }

    function _deploy(address sender) internal {
        bearTokenA = new BearTokenA();
        bearTokenB = new BearTokenB();
        impl = new CErc20Delegate();
        model = new WhitePaperInterestRateModel(0, 0);
        initialExchangeRateMantissa = 1e18;
        newExchangeRateMantissa = 5e17;
        liquidationIncentiveMantissa = 1.08e18;
        comptroller = new ComptrollerG7();
        unitroller = new Unitroller();
        oracle = new SimplePriceOracle();

        unitroller._setPendingImplementation(address(comptroller));
        comptroller._become(unitroller);
        ComptrollerG7 comptrollerProxy = ComptrollerG7(address(unitroller));
        comptrollerProxy._setPriceOracle(oracle);

        cTokenA = new CErc20Delegator(
            address(bearTokenA),
            comptrollerProxy,
            model,
            initialExchangeRateMantissa,
            "Compound Bear Token TokenA",
            "cBearTokenA",
            18,
            payable(sender),
            address(impl),
            new bytes(0)
        );

        cTokenB = new CErc20Delegator(
            address(bearTokenB),
            comptrollerProxy,
            model,
            initialExchangeRateMantissa,
            "Compound Bear Token TokenB",
            "cBearTokenB",
            18,
            payable(sender),
            address(impl),
            new bytes(0)
        );

        comptrollerProxy._supportMarket(CToken(address(cTokenA)));
        comptrollerProxy._supportMarket(CToken(address(cTokenB)));

        comptrollerProxy._setPriceOracle(oracle);
        oracle.setUnderlyingPrice(CToken(address(cTokenA)), initialExchangeRateMantissa);
        oracle.setUnderlyingPrice(CToken(address(cTokenB)), 100 * initialExchangeRateMantissa);

        comptrollerProxy._setCollateralFactor(CToken(address(cTokenB)), newExchangeRateMantissa);
        comptrollerProxy._setCloseFactor(newExchangeRateMantissa);
        comptrollerProxy._setLiquidationIncentive(liquidationIncentiveMantissa);
    }
}