// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {LiquidityEdge} from "../base/liquidity-edge/LiquidityEdge.sol";
import {IUnderlyingToken} from "../interfaces/IUnderlyingToken.sol";

contract MockLiquidityEdge is LiquidityEdge {
    IERC20 immutable token;

    constructor(IERC20 token_) {
        token = token_;
    }

    function initialize(address initialAuthority) public initializer {
        __AccessManaged_init(initialAuthority);
    }

    function route(uint256 amount, bytes calldata data) external payable override {
        address to = abi.decode(data, (address));
        token.transferFrom(msg.sender, to, amount);
    }

    function canProcessRoute(IUnderlyingToken from) external view returns (bool) {
        return from.token() == token;
    }

    function quoteRoute(uint256 amount, bytes calldata data) external view returns (uint256) {}
}
