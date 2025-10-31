// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IUnderlyingAsset} from "../interfaces/IUnderlyingAsset.sol";

abstract contract UnderlyingAsset is IUnderlyingAsset {
    IERC20 immutable _asset;

    constructor(IERC20 asset_) {
        _asset = asset_;
    }

    function asset() external view returns (IERC20) {
        return _asset;
    }
}
