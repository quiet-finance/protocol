// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IUnderlyingToken} from "../interfaces/IUnderlyingToken.sol";

abstract contract UnderlyingToken is IUnderlyingToken {
    IERC20 public immutable token;

    constructor(IERC20 token_) {
        token = token_;
    }
}
