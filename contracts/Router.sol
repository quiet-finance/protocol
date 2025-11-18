// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {IGateway} from "./interfaces/IGateway.sol";

using SafeERC20 for IERC20;

contract Router {
    IGateway gateway;
    IERC20 asset;
    IERC20 qUSD;
    IERC4626 sqUSD;

    struct PermitData {
        uint256 deadline;
        uint8 v;
        bytes32 r;
        bytes32 s;
    }

    constructor(IGateway gateway_) {
        gateway = gateway_;

        asset = gateway.asset();
        asset.forceApprove(address(gateway), type(uint256).max);

        qUSD = gateway.qUSD();
        qUSD.approve(address(sqUSD), type(uint256).max);

        sqUSD = gateway.sqUSD();
    }

    function deposit(uint256 amountIn, bool stake, PermitData calldata permit) public returns (uint256 amountOut) {
        if (permit.deadline != 0) {
            IERC20Permit(address(asset)).permit(
                msg.sender,
                address(this),
                amountIn,
                permit.deadline,
                permit.v,
                permit.r,
                permit.s
            );
        }
        IERC20(asset).safeTransferFrom(msg.sender, address(this), amountIn);

        if (stake) {
            amountOut = sqUSD.mint(gateway.issue(address(this), amountIn), msg.sender);
        } else {
            amountOut = gateway.issue(msg.sender, amountIn);
        }
    }
}
