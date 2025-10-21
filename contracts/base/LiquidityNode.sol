// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {AccessManagedUpgradeable} from "@openzeppelin/contracts-upgradeable/access/manager/AccessManagedUpgradeable.sol";
import {MulticallUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/MulticallUpgradeable.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {IStrategy} from "../interfaces/IStrategy.sol";
import {ITotalAssetsProvider} from "../interfaces/ITotalAssetsProvider.sol";
import {ILiquidityMover} from "../interfaces/ILiquidityMover.sol";

abstract contract LiquidityNode is
    AccessManagedUpgradeable,
    ITotalAssetsProvider
{
    using EnumerableSet for EnumerableSet.AddressSet;
    using SafeERC20 for IERC20;

    EnumerableSet.AddressSet private _strategies;
    EnumerableSet.AddressSet private _liquidityMovers;

    /// @notice We don't validate strategy, because of not whitelisted strategy hasn't allowance
    function enter(
        IStrategy strategy,
        uint256 amount,
        uint256 minAssetsDelta,
        bytes calldata data
    ) external restricted returns (uint256 assetsDelta) {
        uint256 assetsBefore = strategy.totalAssets();
        strategy.deposit(amount, data);

        assetsDelta = strategy.totalAssets() - assetsBefore;
        require(assetsDelta >= minAssetsDelta);
    }

    function exit(
        IStrategy strategy,
        uint256 amount,
        uint256 minBalanceDelta,
        bytes calldata data
    ) external restricted returns (uint256 balanceDelta) {
        uint256 balanceBefore = asset().balanceOf(address(this));
        strategy.withdraw(amount, data);

        balanceDelta = asset().balanceOf(address(this)) - balanceBefore;
        require(balanceDelta >= minBalanceDelta);
    }

    function moveLiquidity(
        ILiquidityMover liquidityMover,
        uint256 amount,
        uint256 chainId,
        bytes calldata data
    ) external restricted {
        liquidityMover.move(address(asset()), amount, chainId, data);
    }

    function enableLiquidityMover(address liquidityMover) external restricted {
        _liquidityMovers.add(liquidityMover);
        asset().forceApprove(liquidityMover, type(uint256).max);
    }

    function disableLiquidityMover(address liquidityMover) external restricted {
        _liquidityMovers.remove(liquidityMover);
        asset().forceApprove(liquidityMover, 0);
    }

    function addStrategy(address strategy) external restricted {
        _strategies.add(strategy);
        asset().forceApprove(strategy, type(uint256).max);
    }

    function removeStrategy(address strategy) external restricted {
        require(IStrategy(strategy).totalAssets() == 0);

        _strategies.remove(strategy);
        asset().forceApprove(strategy, 0);
    }

    function strategies() external view returns (address[] memory) {
        return _strategies.values();
    }

    function liquidityMovers() external view returns (address[] memory) {
        return _liquidityMovers.values();
    }

    function totalAssets() external view virtual returns (uint256 assets) {
        uint256 n = _strategies.length();
        for (uint256 i = 0; i < n; i++) {
            assets += IStrategy(_strategies.at(i)).totalAssets();
        }
    }

    function asset() public view virtual returns (IERC20);
}
