// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

library Scale {
    function calculate(address asset, address qUSD) internal view returns (uint256) {
        uint8 inDecimals = IERC20Metadata(asset).decimals();
        uint8 outDecimals = IERC20Metadata(qUSD).decimals();
        require(outDecimals >= inDecimals);
        return 10 ** (outDecimals - inDecimals);
    }

    function asQusdAmount(uint256 assetAmount, uint256 scale) internal pure returns (uint256) {
        return assetAmount * scale;
    }

    function asAssetAmount(uint256 qusdAmount, uint256 scale) internal pure returns (uint256) {
        return qusdAmount / scale;
    }
}
