// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {AccessManagedUpgradeable} from "@openzeppelin/contracts-upgradeable/access/manager/AccessManagedUpgradeable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {LiquidityEdge} from "./LiquidityEdge.sol";
import {IUnderlyingToken} from "../../interfaces/IUnderlyingToken.sol";

using SafeERC20 for IERC20;

abstract contract Evm2EvmBridgeLiquidityEdge is LiquidityEdge {
    IUnderlyingToken immutable node;
    uint256 immutable toChainId;
    bytes32 immutable path;

    constructor(IUnderlyingToken node_, uint256 toChainId_) {
        node = node_;
        toChainId = toChainId_;
        path = keccak256(abi.encodePacked(Op.BRIDGE_EVM2EVM, node.token(), block.chainid, toChainId));
    }

    function route(uint256 amountIn, bytes calldata data) external payable override restricted {
        uint256 amountOut = _bridge(amountIn, data);
        emit LiquidityRouted(path, amountIn, amountOut);
    }

    function canProcessRoute(IUnderlyingToken from) external view override returns (bool) {
        return (from == node);
    }

    function _bridge(uint256 amount, bytes calldata data) internal virtual returns (uint256 amountOut);

    function _checkCanCall(address caller, bytes calldata data) internal virtual override {
        if (caller == address(node)) return;
        super._checkCanCall(caller, data);
    }

    function _toAddress() internal view returns (address) {
        return address(this);
    }
}
