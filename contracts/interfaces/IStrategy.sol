// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {ITotalAssetsProvider} from "./ITotalAssetsProvider.sol";

interface IStrategy is ITotalAssetsProvider {
    function deposit(uint256 amount, bytes calldata data) external;

    function withdraw(uint256 amount, bytes calldata data) external;
}
