// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {AccessManagedUpgradeable} from "@openzeppelin/contracts-upgradeable/access/manager/AccessManagedUpgradeable.sol";
import {MulticallUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/MulticallUpgradeable.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {IStrategy} from "../interfaces/IStrategy.sol";
import {ILiquidityEdge} from "../interfaces/ILiquidityEdge.sol";
import {ILiquidityNode} from "../interfaces/ILiquidityNode.sol";

abstract contract LiquidityNode is AccessManagedUpgradeable, ILiquidityNode {
    using EnumerableSet for EnumerableSet.AddressSet;
    using SafeERC20 for IERC20;

    EnumerableSet.AddressSet private _strategies;
    EnumerableSet.AddressSet private _liquidityEdges;

    /// @notice We don't validate strategy, because of not whitelisted strategy hasn't allowance
    function enter(
        IStrategy strategy,
        uint256 amount,
        uint256 minNavDelta,
        bytes calldata data
    ) external restricted returns (uint256 navDelta) {
        uint256 navBefore = strategy.nav();
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
    ) external restricted returns (uint256 navDelta) {
        uint256 navBefore = strategy.nav();
        strategy.withdraw(amount, data);

        navDelta = navBefore - strategy.nav();
        require(navDelta <= maxNavDelta, NavDeltaTooHigh(navDelta));
        emit Exit(strategy, amount, navDelta);
    }

    function transferLiquidity(
        ILiquidityEdge liquidityEdge,
        uint256 amount,
        uint256 chainId,
        bytes calldata data
    ) external restricted {
        liquidityEdge.transfer(amount, chainId, data);
    }

    function addLiquidityEdge(address liquidityEdge) external restricted {
        _liquidityEdges.add(liquidityEdge);
        asset().forceApprove(liquidityEdge, type(uint256).max);
        emit LiquidityEdgeAdded(liquidityEdge);
    }

    function removeLiquidityEdge(address liquidityEdge) external restricted {
        _liquidityEdges.remove(liquidityEdge);
        asset().forceApprove(liquidityEdge, 0);
        emit LiquidityEdgeRemoved(liquidityEdge);
    }

    function addStrategy(address strategy) external restricted {
        require(IStrategy(strategy).asset() == asset(), UnsupportedStrategy());

        _strategies.add(strategy);
        asset().forceApprove(strategy, type(uint256).max);
        emit StrategyAdded(strategy);
    }

    function removeStrategy(address strategy) external restricted {
        require(IStrategy(strategy).nav() == 0, NavShouldBeZero());

        _strategies.remove(strategy);
        asset().forceApprove(strategy, 0);
        emit StrategyAdded(strategy);
    }

    function strategies() external view returns (address[] memory) {
        return _strategies.values();
    }

    function liquidityEdges() external view returns (address[] memory) {
        return _liquidityEdges.values();
    }

    function nav() external view returns (uint256) {
        return allocatedNav() + unallocatedNav();
    }

    function allocatedNav()
        public
        view
        virtual
        returns (uint256 strategiesNav)
    {
        uint256 n = _strategies.length();
        for (uint256 i = 0; i < n; i++) {
            strategiesNav += IStrategy(_strategies.at(i)).nav();
        }
    }

    function asset() public view virtual returns (IERC20);

    function unallocatedNav() public view virtual returns (uint256);
}
