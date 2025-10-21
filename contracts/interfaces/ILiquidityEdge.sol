// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

interface ILiquidityEdge {
    function transfer(
        address asset,
        uint256 amount,
        uint256 chainId,
        bytes calldata data
    ) external;
}
