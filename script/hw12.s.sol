// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { Script, console2 } from "forge-std/Script.sol";
import { CErc20Delegator } from "../contracts/CErc20Delegator.sol";
import { CErc20Delegate } from "../contracts/CErc20Delegate.sol";
import { WhitePaperInterestRateModel } from "../contracts/WhitePaperInterestRateModel.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { AndyToken } from "../contracts/AndyToken.sol";
import { ComptrollerG7 } from "../contracts/ComptrollerG7.sol";
import { SimplePriceOracle } from "../contracts/SimplePriceOracle.sol";
import { Unitroller } from "../contracts/Unitroller.sol";

contract HW12Script is Script {
    ERC20 token;
    ComptrollerG7 comptroller;
    CErc20Delegate impl;
    WhitePaperInterestRateModel model;
    Unitroller unitroller;
    SimplePriceOracle oracle;

    function run() external {
        vm.startBroadcast();

        token = new AndyToken();
        impl = new CErc20Delegate();
        model = new WhitePaperInterestRateModel(0, 0);
        comptroller = new ComptrollerG7();
        unitroller = new Unitroller();
        oracle = new SimplePriceOracle();

        unitroller._setPendingImplementation(address(comptroller));
        comptroller._become(unitroller);
        ComptrollerG7 comptrollerProxy = ComptrollerG7(address(unitroller));
        comptrollerProxy._setPriceOracle(oracle);

        new CErc20Delegator(
            address(token),
            comptrollerProxy,
            model,
            1e18,
            "Compound Andy Token",
            "cANDY",
            18,
            payable(0x0813CFFbDa292c1bC3D42868ff2b0f8c43F64da6),
            address(impl),
            new bytes(0)
        );

        vm.stopBroadcast();
    }
}