// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {ILiquidityEdge} from "../interfaces/ILiquidityEdge.sol";

contract MockLiquidityEdge is ILiquidityEdge {
    function transfer(uint256 amount, uint256, bytes calldata data) external payable {
        (IERC20 asset, address to) = abi.decode(data, (IERC20, address));
        asset.transferFrom(msg.sender, to, amount);
    }

    function quoteTransfer(uint256 amount, uint256 chainId, bytes calldata data) external view returns (uint256) {}
}
