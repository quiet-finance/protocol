// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

interface ITotalAssetsProvider {
    function totalAssets() external view returns (uint256);
}
