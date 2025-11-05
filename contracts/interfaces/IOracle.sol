// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

interface IOracle {
    function getAssetAmount(uint256 tokenAmount) external view returns (uint256);
}
