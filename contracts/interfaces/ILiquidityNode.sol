// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {INavProvider} from "./INavProvider.sol";
import {IStrategy} from "./IStrategy.sol";
import {IUnderlyingAsset} from "./IUnderlyingAsset.sol";

interface ILiquidityNode is INavProvider, IUnderlyingAsset {
    event LiquidityEdgeAdded(address liquidityEdge);
    event LiquidityEdgeRemoved(address liquidityEdge);
    event Enter(IStrategy strategy, uint256 amount, uint256 navDelta);
    event Exit(IStrategy strategy, uint256 amount, uint256 navDelta);
    event StrategyAdded(address strategy);
    event StrategyRemoved(address strategy);

    error NavDeltaTooHigh(uint256 navDelta);
    error NavDeltaTooLow(uint256 navDelta);
    error NavShouldBeZero();
    error UnsupportedAsset();
}
