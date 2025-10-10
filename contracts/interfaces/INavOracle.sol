// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

interface INavOracle {
    function nav() external view returns (uint256);
}
