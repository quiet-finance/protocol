// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {AccessManagedUpgradeable} from "@openzeppelin/contracts-upgradeable/access/manager/AccessManagedUpgradeable.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {IStrategy} from "../interfaces/IStrategy.sol";
import {ILiquidityEdge} from "../interfaces/ILiquidityEdge.sol";
import {ILiquidityNode} from "../interfaces/ILiquidityNode.sol";
import {IUnderlyingToken} from "../interfaces/IUnderlyingToken.sol";
import {UnderlyingToken} from "./UnderlyingToken.sol";

using EnumerableSet for EnumerableSet.AddressSet;
using SafeERC20 for IERC20;

abstract contract LiquidityNode is AccessManagedUpgradeable, UnderlyingToken, ILiquidityNode {
    /// @custom:storage-location erc7201:quiet-finance.storage.LiquidityNode;
    struct Storage {
        EnumerableSet.AddressSet strategies;
        EnumerableSet.AddressSet liquidityEdges;
    }

    /// @dev keccak256(abi.encode(uint256(keccak256("quiet-finance.storage.LiquidityNode")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant STORAGE_LOCATION = 0xf1d08d25cb0c657a55dd4b08dfc06d9a51ab54febd3c2710eb14c4d290c1af00;

    function enter(
        IStrategy strategy,
        uint256 amount,
        uint256 minNavDelta,
        bytes calldata data
    ) external payable restricted returns (uint256 navDelta) {
        require(_getStorage().strategies.contains(address(strategy)));
        if (amount == 0) amount = token.balanceOf(address(this));

        uint256 navBefore = strategy.nav();
        token.safeTransfer(address(strategy), amount);
        strategy.deposit(amount, data);
        navDelta = strategy.nav() - navBefore;

        require(navDelta >= minNavDelta, NavDeltaTooLow(navDelta));
        emit Enter(strategy, amount, navDelta);
    }

    function exit(
        IStrategy strategy,
        uint256 amount,
        uint256 maxNavDelta,
        bytes calldata data
    ) external payable restricted returns (uint256 navDelta) {
        uint256 navBefore = strategy.nav();
        strategy.withdraw(amount, data);
        navDelta = navBefore - strategy.nav();

        require(navDelta <= maxNavDelta, NavDeltaTooHigh(navDelta));
        emit Exit(strategy, amount, navDelta);
    }

    function route(
        ILiquidityEdge liquidityEdge,
        uint256 nativeAmount,
        uint256 amount,
        bytes calldata data
    ) external payable restricted {
        require(_getStorage().liquidityEdges.contains(address(liquidityEdge)));
        if (amount == 0) amount = token.balanceOf(address(this));

        token.safeTransfer(address(liquidityEdge), amount);
        liquidityEdge.route{value: nativeAmount}(amount, data);
    }

    function addLiquidityEdge(address liquidityEdge) external restricted {
        require(ILiquidityEdge(liquidityEdge).canProcessRoute(this), UnsupportedLiquidityNode());
        _getStorage().liquidityEdges.add(liquidityEdge);
        emit LiquidityEdgeAdded(liquidityEdge);
    }

    function removeLiquidityEdge(address liquidityEdge) external restricted {
        _getStorage().liquidityEdges.remove(liquidityEdge);
        emit LiquidityEdgeRemoved(liquidityEdge);
    }

    function addStrategy(address strategy) external restricted {
        require(IUnderlyingToken(strategy).token() == token, UnsupportedStrategy());

        _getStorage().strategies.add(strategy);
        emit StrategyAdded(strategy);
    }

    function removeStrategy(address strategy) external restricted {
        require(IStrategy(strategy).nav() == 0, NavShouldBeZero());

        _getStorage().strategies.remove(strategy);
        emit StrategyAdded(strategy);
    }

    function strategies() external view returns (address[] memory) {
        return _getStorage().strategies.values();
    }

    function liquidityEdges() external view returns (address[] memory) {
        return _getStorage().liquidityEdges.values();
    }

    function nav() external view returns (uint256 strategiesNav) {
        uint256 n = _getStorage().strategies.length();
        for (uint256 i = 0; i < n; i++) {
            strategiesNav += IStrategy(_getStorage().strategies.at(i)).nav();
        }
    }

    function _getStorage() private pure returns (Storage storage $) {
        assembly {
            $.slot := STORAGE_LOCATION
        }
    }
}
