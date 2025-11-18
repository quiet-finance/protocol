// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {ERC20PermitUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20PermitUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {AccessManagedUpgradeable} from "@openzeppelin/contracts-upgradeable/access/manager/AccessManagedUpgradeable.sol";

import {IMintableERC20} from "../interfaces/IMintableERC20.sol";

contract qUSD is Initializable, ERC20PermitUpgradeable, AccessManagedUpgradeable, IMintableERC20 {
    constructor() {
        _disableInitializers();
    }

    function initialize(address initialAuthority) public initializer {
        __ERC20_init("QuietUSD", "qUSD");
        __ERC20Permit_init("QuietUSD");
        __AccessManaged_init(initialAuthority);
    }

    function mint(address to, uint256 amount) public restricted {
        _mint(to, amount);
    }

    function burn(address from, uint256 amount) public restricted {
        _burn(from, amount);
    }
}
