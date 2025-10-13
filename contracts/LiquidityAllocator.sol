// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.4.0
pragma solidity ^0.8.27;

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import {IStrategy} from "./interfaces/IStrategy.sol";

enum AllocateAction {
    DEPOSIT,
    WITHDRAW,
    BRIDGE
}

struct AllocateInstruction {
    address strategy;
    AllocateAction action;
    uint256 amount;
}

contract LiquidityAllocator is OwnableUpgradeable {
    using EnumerableSet for EnumerableSet.AddressSet;

    EnumerableSet.AddressSet private _strategies;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function addStrategy(address strategy) external onlyOwner {
        _strategies.add(strategy);
    }

    function removeStrategy(address strategy) external onlyOwner {
        _strategies.remove(strategy);
    }

    function allocate(
        AllocateInstruction[] calldata instructions
    ) external onlyOwner {
        uint256 n = instructions.length;
        for (uint256 idx = 0; idx < n; idx++) {
            AllocateInstruction memory i = instructions[idx];
            require(_strategies.contains(i.strategy));

            if (i.action == AllocateAction.DEPOSIT) {
                IStrategy(i.strategy).deposit(i.amount);
            } else if (i.action == AllocateAction.WITHDRAW) {
                IStrategy(i.strategy).withdraw(i.amount);
            } else if (i.action == AllocateAction.BRIDGE) {
                revert("Not implemented");
            }
        }
    }

    function strategies() external view returns (address[] memory) {
        return _strategies.values();
    }

    function nav() external view returns (uint256 nav_) {
        uint256 n = _strategies.length();
        for (uint256 i = 0; i < n; i++) {
            nav_ += IStrategy(_strategies.at(i)).nav();
        }
    }
}
