// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {ERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockAsset is ERC20 {
    constructor() ERC20("asset", "a") {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}
