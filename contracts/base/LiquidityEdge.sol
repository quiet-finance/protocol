// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {AccessManagedUpgradeable} from "@openzeppelin/contracts-upgradeable/access/manager/AccessManagedUpgradeable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {ILiquidityEdge} from "../interfaces/ILiquidityEdge.sol";
import {ILiquidityNode} from "../interfaces/ILiquidityNode.sol";
import {UnderlyingToken} from "./UnderlyingToken.sol";

using SafeERC20 for IERC20;

abstract contract LiquidityEdge is AccessManagedUpgradeable, UnderlyingToken, ILiquidityEdge {
    function transfer(uint256 amount, bytes calldata data) external payable {
        _transfer(amount, data);
    }

    function _transfer(uint256 amount, bytes calldata data) internal virtual;
}
