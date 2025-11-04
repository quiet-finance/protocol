// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {INavProvider} from "./INavProvider.sol";
import {IUnderlyingToken} from "./IUnderlyingToken.sol";

interface IStrategy is INavProvider, IUnderlyingToken {
    event OracleUpdated(address oldOracle, address newOracle);

    function deposit(uint256 amount, bytes calldata data) external;

    function withdraw(uint256 amount, bytes calldata data) external;
}
