// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

interface ILiquidityEdge {
    function transfer(
        uint256 amount,
        uint256 chainId,
        bytes calldata data
    ) external payable;

    function quoteTransfer(
        uint256 amount,
        uint256 chainId,
        bytes calldata data
    ) external view returns (uint256);
}
