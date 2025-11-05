// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {AccessManagedUpgradeable} from "@openzeppelin/contracts-upgradeable/access/manager/AccessManagedUpgradeable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {IStrategy} from "../interfaces/IStrategy.sol";
import {IOracle} from "../interfaces/IOracle.sol";
import {UnderlyingToken} from "./UnderlyingToken.sol";

using SafeERC20 for IERC20;

abstract contract Strategy is AccessManagedUpgradeable, UnderlyingToken, IStrategy {
    /// @custom:storage-location erc7201:quiet-finance.storage.Strategy
    struct Storage {
        IOracle oracle;
    }

    /// @dev keccak256(abi.encode(uint256(keccak256("quiet-finance.storage.Strategy")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant STORAGE_LOCATION = 0x8dace110bad92d2e155cd128c56a1cf1dde760848cbd860924dfd007f1975a00;

    function __Strategy_init(IOracle initialOracle) internal onlyInitializing {
        _getStorage().oracle = initialOracle;
        emit OracleUpdated(address(0), address(initialOracle));
    }

    function deposit(uint256 amount, bytes calldata data) external restricted {
        _deposit(amount, data);
    }

    function withdraw(uint256 amount, bytes calldata data) external restricted {
        _withdraw(amount, data);
        _token.safeTransfer(msg.sender, amount);
    }

    function setOralce(IOracle newOracle) external restricted {
        IOracle oldOracle = _getStorage().oracle;
        _getStorage().oracle = newOracle;
        emit OracleUpdated(address(oldOracle), address(newOracle));
    }

    function oracle() public view returns (IOracle) {
        return _getStorage().oracle;
    }

    function _getAssetAmount(uint256 tokenAmount) internal view returns (uint256) {
        return _getStorage().oracle.getAssetAmount(tokenAmount);
    }

    function _deposit(uint256 amount, bytes calldata data) internal virtual;

    function _withdraw(uint256 amount, bytes calldata data) internal virtual;

    function _getStorage() private pure returns (Storage storage $) {
        assembly {
            $.slot := STORAGE_LOCATION
        }
    }
}
