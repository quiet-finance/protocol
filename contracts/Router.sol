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
    IERC20 immutable qUSD;
    IERC4626 immutable sqUSD;

    struct PermitData {
        uint256 deadline;
        uint8 v;
        bytes32 r;
        bytes32 s;
    }

    constructor(ILiquidityHub liquidityHub_) {
        liquidityHub = liquidityHub_;

        asset = liquidityHub.asset();
        qUSD = liquidityHub.qUSD();
        sqUSD = liquidityHub.sqUSD();

        asset.forceApprove(address(liquidityHub), type(uint256).max);
        qUSD.approve(address(sqUSD), type(uint256).max);
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
            amountOut = sqUSD.mint(liquidityHub.issue(address(this), amountIn), msg.sender);
        } else {
            amountOut = liquidityHub.issue(msg.sender, amountIn);
        }
    }
}
