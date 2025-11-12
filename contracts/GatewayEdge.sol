// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {LiquidityEdge} from "./base/liquidity-edge/LiquidityEdge.sol";
import {IGateway} from "./interfaces/IGateway.sol";
import {IUnderlyingToken} from "./interfaces/IUnderlyingToken.sol";

using SafeERC20 for IERC20;

contract GatewayEdge is LiquidityEdge {
    IGateway immutable gateway;
    IUnderlyingToken immutable node;

    constructor(IGateway gateway_, IUnderlyingToken node_) {
        gateway = gateway_;
        node = node_;
    }

    function route(uint256 amountIn, bytes calldata data) external payable {
        (uint256 navAfterRebalance, int256 assetsDelta) = abi.decode(data, (uint256, int256));
        if (assetsDelta < 0) {
            require(amountIn == uint256(-assetsDelta));
            node.token().safeTransfer(address(gateway), amountIn);
        }

        gateway.finishRebalance(navAfterRebalance, assetsDelta);

        if (assetsDelta > 0) {
            require(amountIn == 0);
            node.token().safeTransfer(address(node), uint256(assetsDelta));
        }
    }

    function canProcessRoute(IUnderlyingToken from) external view returns (bool) {
        return node == from;
    }

    function quoteRoute(uint256, bytes calldata) external pure returns (uint256) {
        return 0;
    }

    function _checkCanCall(address caller, bytes calldata data) internal virtual override {
        if (caller == address(node)) return;
        super._checkCanCall(caller, data);
    }
}
