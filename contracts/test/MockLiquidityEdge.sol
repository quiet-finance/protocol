// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {LiquidityEdge} from "../base/LiquidityEdge.sol";
import {UnderlyingAsset} from "../base/UnderlyingAsset.sol";

contract MockLiquidityEdge is LiquidityEdge {
    constructor(IERC20 asset) UnderlyingAsset(asset) {}

    function initialize(address initialAuthority) public initializer {
        __AccessManaged_init(initialAuthority);
    }

    function _transfer(uint256 amount, bytes calldata data) internal override {
        address to = abi.decode(data, (address));
        _asset.transferFrom(msg.sender, to, amount);
    }

    function quoteTransfer(uint256 amount, bytes calldata data) external view returns (uint256) {}
}
