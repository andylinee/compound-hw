// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract AndyToken is ERC20 {
    constructor() ERC20("Andy Token", "ANDY") {
        _mint(msg.sender, 1000000000000000000000000000);
    }
}