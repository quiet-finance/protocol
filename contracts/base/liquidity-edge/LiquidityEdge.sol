// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {AccessManagedUpgradeable} from "@openzeppelin/contracts-upgradeable/access/manager/AccessManagedUpgradeable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {ILiquidityEdge} from "../../interfaces/ILiquidityEdge.sol";

using SafeERC20 for IERC20;

abstract contract LiquidityEdge is AccessManagedUpgradeable, ILiquidityEdge {
    function rescue(IERC20 stuckToken, address payable to) external restricted {
        if (address(stuckToken) == address(0)) {
            (bool success, ) = to.call{value: payable(address(this)).balance}("");
            require(success);
        } else {
            stuckToken.safeTransfer(to, stuckToken.balanceOf(address(this)));
        }
    }
}
