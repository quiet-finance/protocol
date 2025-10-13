// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.4.0
pragma solidity ^0.8.27;

interface IStrategy {
    function deposit(uint256 amount) external;

    function withdraw(uint256 amount) external;

    function nav() external view returns (uint256);
}
