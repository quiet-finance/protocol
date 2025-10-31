// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {INavProvider} from "./INavProvider.sol";
import {IUnderlyingAsset} from "./IUnderlyingAsset.sol";

interface IStrategy is INavProvider, IUnderlyingAsset {
    function deposit(uint256 amount, bytes calldata data) external;

    function withdraw(uint256 amount, bytes calldata data) external;
}
