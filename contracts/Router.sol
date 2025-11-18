// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {IGateway} from "./interfaces/IGateway.sol";

using SafeERC20 for IERC20;

contract Router {
    function issue(IGateway gateway, uint256 amount) external {
        IERC20 asset = gateway.asset();

        asset.safeTransferFrom(msg.sender, address(this), amount);
        asset.forceApprove(address(gateway), amount);
        gateway.issue(msg.sender, amount);
    }

    function issueAndStake(IGateway gateway, uint256 amount) external {
        IERC20 asset = gateway.asset();
        IERC4626 sqUSD = gateway.sqUSD();

        asset.safeTransferFrom(msg.sender, address(this), amount);
        asset.forceApprove(address(gateway), amount);
        uint256 issueAmount = gateway.issue(address(this), amount);

        gateway.qUSD().approve(address(sqUSD), issueAmount);
        sqUSD.deposit(issueAmount, msg.sender);
    }
}
