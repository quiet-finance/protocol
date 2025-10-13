// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.4.0
pragma solidity ^0.8.27;

interface IOwnable2Step {
    function transferOwnership(address newOwner) external;

    function acceptOwnership() external;
}

interface IStrategy is IOwnable2Step {
    function nav() external view returns (uint256);
}
