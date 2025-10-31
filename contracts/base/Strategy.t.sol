// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {MockProtocol} from "../test/MockProtocol.sol";
import {Strategy} from "../base/Strategy.sol";
import {UnderlyingAsset} from "../base/UnderlyingAsset.sol";

contract MockStrategy is Strategy {
    MockProtocol public protocol;

    constructor(IERC20 asset) UnderlyingAsset(asset) {}

    function initialize(address initialAuthority) public initializer {
        __AccessManaged_init(initialAuthority);

        protocol = new MockProtocol(_asset);
        _asset.approve(address(protocol), type(uint256).max);
    }

    function nav() external view returns (uint256) {
        return _asset.balanceOf(address(protocol));
    }

    function _deposit(uint256 amount, bytes calldata) internal override {
        protocol.deposit(amount);
    }

    function _withdraw(uint256 amount, bytes calldata) internal override {
        protocol.withdraw(amount);
    }
}
