// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {AccessManagedUpgradeable} from "@openzeppelin/contracts-upgradeable/access/manager/AccessManagedUpgradeable.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {IStrategy} from "../interfaces/IStrategy.sol";
import {ILiquidityEdge} from "../interfaces/ILiquidityEdge.sol";
import {ILiquidityNode} from "../interfaces/ILiquidityNode.sol";

using EnumerableSet for EnumerableSet.AddressSet;
using SafeERC20 for IERC20;

abstract contract LiquidityNode is AccessManagedUpgradeable, ILiquidityNode {
    /// @custom:storage-location erc7201:quiet-finance.storage.LiquidityNode;
    struct LiquidityNodeStorage {
        EnumerableSet.AddressSet _strategies;
        EnumerableSet.AddressSet _liquidityEdges;
    }

    /// @dev keccak256(abi.encode(uint256(keccak256("quiet-finance.storage.LiquidityNode")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant LIQUIDITYNODE_STORAGE_LOCATION =
        0xf1d08d25cb0c657a55dd4b08dfc06d9a51ab54febd3c2710eb14c4d290c1af00;

    IERC20 public immutable asset;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor(IERC20 asset_) {
        _disableInitializers();

        asset = asset_;
    }

    /// @notice We don't validate strategy, because of not whitelisted strategy hasn't allowance
    function enter(
        IStrategy strategy,
        uint256 amount,
        uint256 minNavDelta,
        bytes calldata data
    ) external payable restricted returns (uint256 navDelta) {
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
    ) external payable restricted returns (uint256 navDelta) {
        uint256 navBefore = strategy.nav();
        strategy.withdraw(amount, data);

        navDelta = navBefore - strategy.nav();
        require(navDelta <= maxNavDelta, NavDeltaTooHigh(navDelta));
        emit Exit(strategy, amount, navDelta);
    }

    function transferLiquidity(
        ILiquidityEdge liquidityEdge,
        uint256 nativeAmount,
        uint256 amount,
        uint256 chainId,
        bytes calldata data
    ) external payable restricted {
        liquidityEdge.transfer{value: nativeAmount}(amount, chainId, data);
    }

    function addLiquidityEdge(address liquidityEdge) external restricted {
        _getLiquidityNodeStorage()._liquidityEdges.add(liquidityEdge);
        asset.forceApprove(liquidityEdge, type(uint256).max);
        emit LiquidityEdgeAdded(liquidityEdge);
    }

    function removeLiquidityEdge(address liquidityEdge) external restricted {
        _getLiquidityNodeStorage()._liquidityEdges.remove(liquidityEdge);
        asset.forceApprove(liquidityEdge, 0);
        emit LiquidityEdgeRemoved(liquidityEdge);
    }

    function addStrategy(address strategy) external restricted {
        require(IStrategy(strategy).asset() == asset, UnsupportedStrategy());

        _getLiquidityNodeStorage()._strategies.add(strategy);
        asset.forceApprove(strategy, type(uint256).max);
        emit StrategyAdded(strategy);
    }

    function removeStrategy(address strategy) external restricted {
        require(IStrategy(strategy).nav() == 0, NavShouldBeZero());

        _getLiquidityNodeStorage()._strategies.remove(strategy);
        asset.forceApprove(strategy, 0);
        emit StrategyAdded(strategy);
    }

    function strategies() external view returns (address[] memory) {
        return _getLiquidityNodeStorage()._strategies.values();
    }

    function liquidityEdges() external view returns (address[] memory) {
        return _getLiquidityNodeStorage()._liquidityEdges.values();
    }

    function nav() external view returns (uint256 strategiesNav) {
        uint256 n = _getLiquidityNodeStorage()._strategies.length();
        for (uint256 i = 0; i < n; i++) {
            strategiesNav += IStrategy(_getLiquidityNodeStorage()._strategies.at(i)).nav();
        }
    }

    function _getLiquidityNodeStorage() private pure returns (LiquidityNodeStorage storage $) {
        assembly {
            $.slot := LIQUIDITYNODE_STORAGE_LOCATION
        }
    }
}
