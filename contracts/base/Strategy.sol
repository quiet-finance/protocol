// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {AccessManagedUpgradeable} from "@openzeppelin/contracts-upgradeable/access/manager/AccessManagedUpgradeable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {IStrategy} from "../interfaces/IStrategy.sol";
import {UnderlyingToken} from "./UnderlyingToken.sol";

using SafeERC20 for IERC20;

abstract contract Strategy is AccessManagedUpgradeable, UnderlyingToken, IStrategy {
    function deposit(uint256 amount, bytes calldata data) external restricted {
        _deposit(amount, data);
    }

    function withdraw(uint256 amount, bytes calldata data) external restricted {
        _withdraw(amount, data);
        _token.safeTransfer(msg.sender, amount);
    }

    function _deposit(uint256 amount, bytes calldata data) internal virtual;

    function _withdraw(uint256 amount, bytes calldata data) internal virtual;
}
