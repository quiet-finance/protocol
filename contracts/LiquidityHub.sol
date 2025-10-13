// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.4.0
pragma solidity ^0.8.27;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {LiquidityAllocator} from "./LiquidityAllocator.sol";
import {IqUSD} from "./interfaces/IqUSD.sol";

struct RedeemRequest {
    address requester;
    uint256 timestamp;
    uint256 amount;
    bool isProcessed;
}

contract LiquidityHub is LiquidityAllocator {
    uint256 constant BPS = 10_000;

    IqUSD qUSD;
    IERC20 USDC;

    uint256 instantRedeemFee = 300; // in bps, 3% by default
    uint256 redeemDelay = 2 days;

    uint256 nextRedeemIdx;
    mapping(uint256 => RedeemRequest) redeemQueue;

    function issue(address to, uint256 amount) external {
        USDC.transferFrom(msg.sender, address(this), amount);
        qUSD.mint(to, amount);
    }

    function redeemInstant(address to, uint256 amount) external {
        qUSD.burn(msg.sender, amount);
        USDC.transfer(to, amount - (amount * instantRedeemFee) / BPS);
    }

    function requestRedeem(uint256 amount) external {
        qUSD.burn(msg.sender, amount);

        redeemQueue[nextRedeemIdx++] = RedeemRequest({
            requester: msg.sender,
            timestamp: block.timestamp,
            amount: amount,
            isProcessed: false
        });
    }

    function finishRedeem(uint256 requestId, address to) external {
        RedeemRequest storage redeemRequest = redeemQueue[requestId];
        require(!redeemRequest.isProcessed);
        require(redeemRequest.requester == msg.sender);
        require(redeemRequest.timestamp + redeemDelay < block.timestamp);

        redeemRequest.isProcessed = true;
        USDC.transfer(to, redeemRequest.amount);
    }
}
