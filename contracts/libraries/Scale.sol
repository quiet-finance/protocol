// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

library Scale {
    function calculate(address underlying, address asset) internal view returns (uint256) {
        uint8 underlyingDecimals = IERC20Metadata(underlying).decimals();
        uint8 assetDecimals = IERC20Metadata(asset).decimals();
        require(assetDecimals >= underlyingDecimals);
        return 10 ** (assetDecimals - underlyingDecimals);
    }

    function asAssetAmount(uint256 underlyingAmount, uint256 scale) internal pure returns (uint256) {
        return underlyingAmount * scale;
    }

    function asAssetAmount(int256 underlyingAmount, uint256 scale) internal pure returns (int256) {
        return underlyingAmount * int256(scale);
    }

    function asUnderlyingAmount(uint256 assetAmount, uint256 scale) internal pure returns (uint256) {
        return assetAmount / scale;
    }
}
