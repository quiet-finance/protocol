// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.4.0
pragma solidity ^0.8.27;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import {ERC20PermitUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20PermitUpgradeable.sol";
import {ERC4626Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC4626Upgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

import {INavOracle} from "./interfaces/INavOracle.sol";

contract sqUSD is
    Initializable,
    ERC4626Upgradeable,
    ERC20PermitUpgradeable,
    OwnableUpgradeable
{
    event NavOracleChanged(address oldOracle, address newOracle);

    INavOracle public navOracle;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address initialOwner,
        IERC20 asset,
        INavOracle navOracle_
    ) public initializer {
        __ERC4626_init(asset);
        __ERC20_init("sQuietUSD", "sqUSD");
        __Ownable_init(initialOwner);
        __ERC20Permit_init("sQuietUSD");

        navOracle = navOracle_;
        emit NavOracleChanged(address(0), address(navOracle_));
    }

    function changeNavOracle(INavOracle navOracle_) external onlyOwner {
        emit NavOracleChanged(address(navOracle), address(navOracle_));
        navOracle = navOracle_;
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

    function totalAssets() public view virtual override returns (uint256) {
        return navOracle.nav();
    }
}
