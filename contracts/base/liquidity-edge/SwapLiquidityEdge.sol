// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {LiquidityEdge} from "./LiquidityEdge.sol";
import {IUnderlyingToken} from "../../interfaces/IUnderlyingToken.sol";

using SafeERC20 for IERC20;

abstract contract SwapLiquidityEdge is LiquidityEdge {
    IUnderlyingToken immutable nodeA;
    IUnderlyingToken immutable nodeB;

    constructor(IUnderlyingToken nodeA_, IUnderlyingToken nodeB_) {
        nodeA = nodeA_;
        nodeB = nodeB_;
    }

    function route(uint256 amountIn, bytes calldata data) external payable override restricted {
        (IUnderlyingToken nodeIn, IUnderlyingToken nodeOut) = msg.sender == address(nodeA)
            ? (nodeA, nodeB)
            : (nodeB, nodeA);

        uint256 amountOut = _swap(amountIn, data);
        nodeOut.token().safeTransfer(address(nodeOut), amountOut);
        emit LiquidityRouted(keccak256(abi.encodePacked("swap", nodeIn.token(), nodeOut.token())), amountIn, amountOut);
    }

    function canProcessRoute(IUnderlyingToken from) external view override returns (bool) {
        return (from == nodeA || from == nodeB);
    }

    function _swap(uint256 amount, bytes calldata data) internal virtual returns (uint256 amountOut);

    function _checkCanCall(address caller, bytes calldata data) internal virtual override {
        if (caller == address(nodeA) || caller == address(nodeB)) return;
        super._checkCanCall(caller, data);
    }
}
