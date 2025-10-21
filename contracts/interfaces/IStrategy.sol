// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {INavProvider} from "./INavProvider.sol";

interface IStrategy is INavProvider {
    function deposit(uint256 amount, bytes calldata data) external;

    function withdraw(uint256 amount, bytes calldata data) external;

    function asset() external returns (IERC20);
}
