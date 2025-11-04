// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IUnderlyingToken {
    function token() external view returns (IERC20);
}
