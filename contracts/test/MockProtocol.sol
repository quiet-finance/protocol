// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract MockProtocol {
    IERC20 _token;

    constructor(IERC20 token_) {
        _token = token_;
    }

    function deposit(uint256 amount) external {
        _token.transferFrom(msg.sender, address(this), amount);
    }

    function withdraw(uint256 amount) external {
        _token.transfer(msg.sender, amount);
    }
}
