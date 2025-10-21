// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

interface INavProvider {
    function nav() external view returns (uint256);
}
