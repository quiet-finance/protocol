// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import {ERC20PermitUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20PermitUpgradeable.sol";
import {ERC4626Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC4626Upgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {AccessManagedUpgradeable} from "@openzeppelin/contracts-upgradeable/access/manager/AccessManagedUpgradeable.sol";

import {INavProvider} from "../interfaces/INavProvider.sol";

contract sqUSD is
    Initializable,
    ERC4626Upgradeable,
    ERC20PermitUpgradeable,
    AccessManagedUpgradeable
{
    event NavOracleChanged(address oldOracle, address newOracle);

    address public navOracle;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        IERC20 asset,
        address initialAuthority,
        address navOracle_
    ) public initializer {
        __ERC4626_init(asset);
        __ERC20_init("sQuietUSD", "sqUSD");
        __ERC20Permit_init("sQuietUSD");
        __AccessManaged_init(initialAuthority);

        navOracle = navOracle_;
        emit NavOracleChanged(address(0), address(navOracle_));
    }

    function changeNavOracle(address navOracle_) external restricted {
        emit NavOracleChanged(navOracle, navOracle_);
        navOracle = navOracle_;
    }

    function totalAssets() public view virtual override returns (uint256) {
        return INavProvider(navOracle).nav();
    }

    function decimals()
        public
        view
        virtual
        override(ERC4626Upgradeable, ERC20Upgradeable)
        returns (uint8)
    {
        return super.decimals();
    }
}
