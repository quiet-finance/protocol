// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract MockProtocol {
    IERC20 _asset;

    constructor(IERC20 asset_) {
        _asset = asset_;
    }

    function deposit(uint256 amount) external {
        _asset.transferFrom(msg.sender, address(this), amount);
    }

    function withdraw(uint256 amount) external {
        _asset.transfer(msg.sender, amount);
    }
}
