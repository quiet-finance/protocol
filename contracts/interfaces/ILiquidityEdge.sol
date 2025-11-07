// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IUnderlyingToken} from "./IUnderlyingToken.sol";
import {IUnderlyingToken} from "./IUnderlyingToken.sol";

interface ILiquidityEdge {
    event LiquidityRouted(bytes32 indexed path, uint256 amountIn, uint256 amountOut);

    function route(uint256 amount, bytes calldata data) external payable;

    function canProcessRoute(IUnderlyingToken from) external view returns (bool);

    function quoteRoute(uint256 amount, bytes calldata data) external view returns (uint256);
}
