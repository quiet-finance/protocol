// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {ILiquidityHub} from "./interfaces/ILiquidityHub.sol";

using SafeERC20 for IERC20;

contract Router {
    ILiquidityHub liquidityHub;
    IERC20 immutable asset;
    IERC20 immutable receipt;
    IERC4626 immutable share;

    struct PermitData {
        uint256 deadline;
        uint8 v;
        bytes32 r;
        bytes32 s;
    }

    constructor(ILiquidityHub liquidityHub_) {
        liquidityHub = liquidityHub_;

        asset = liquidityHub.asset();
        receipt = liquidityHub.receipt();
        share = liquidityHub.share();

        asset.forceApprove(address(liquidityHub), type(uint256).max);
        receipt.approve(address(share), type(uint256).max);
    }

    function deposit(uint256 amountIn, bool stake, PermitData calldata permit) external {
        if (permit.deadline != 0)
            IERC20Permit(address(asset)).permit(
                msg.sender,
                address(this),
                amountIn,
                permit.deadline,
                permit.v,
                permit.r,
                permit.s
            );

        IERC20(asset).safeTransferFrom(msg.sender, address(this), amountIn);
        uint256 amountOut = liquidityHub.issue(address(this), amountIn);
        if (stake) share.deposit(amountOut, msg.sender);
    }

    function withdraw(uint256 amountIn, bool unstake, bool instant, PermitData calldata permit) external {
        address tokenIn = address(unstake ? share : receipt);
        if (permit.deadline != 0)
            IERC20Permit(tokenIn).permit(
                msg.sender,
                address(this),
                amountIn,
                permit.deadline,
                permit.v,
                permit.r,
                permit.s
            );

        IERC20(tokenIn).safeTransferFrom(msg.sender, address(this), amountIn);
        if (unstake) amountIn = share.redeem(amountIn, address(this), address(this));
        if (instant) {
            liquidityHub.redeemInstant(msg.sender, amountIn);
        } else {
            liquidityHub.requestRedeem(msg.sender, amountIn);
        }
    }
}
