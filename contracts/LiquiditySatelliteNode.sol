// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {LiquidityNode} from "./base/LiquidityNode.sol";

contract LiquiditySatelliteNode is LiquidityNode {
    IERC20 _asset;

    function ____LiquiditySatelliteNode_init(
        IERC20 asset_
    ) public onlyInitializing {
        _asset = asset_;
    }

    function asset() public view override returns (IERC20) {
        return _asset;
    }
}
