// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IUnderlyingToken} from "./IUnderlyingToken.sol";

interface ILiquidityEdge is IUnderlyingToken {
    function transfer(uint256 amount, bytes calldata data) external payable;

    function quoteTransfer(uint256 amount, bytes calldata data) external view returns (uint256);
}
