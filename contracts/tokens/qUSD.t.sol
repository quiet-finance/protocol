// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {Test} from "forge-std/Test.sol";
import "../test/utils.sol" as $;

import {qUSD} from "./qUSD.sol";

contract qUSDTest is Test {
    qUSD token;

    function setUp() external {
        qUSD qUSDImpl = new qUSD();

        token = qUSD(
            $.proxy.deploy(
                address(qUSDImpl),
                address(this),
                abi.encodeCall(qUSD.initialize, ($.accessManager.addr()))
            )
        );
    }

    function test_mintBurn() external {
        // mint unauthorized
        $.accessManager.expectAccessManagedUnauthorized();
        token.mint(address(this), 10);

        // mint authorized
        $.accessManager.grantAccess(address(token), token.mint.selector);
        token.mint(address(this), 10);
        vm.assertEq(token.balanceOf(address(this)), 10);

        // burn unauthorized
        $.accessManager.expectAccessManagedUnauthorized();
        token.burn(address(this), 5);

        // burn authorized
        $.accessManager.grantAccess(address(token), token.burn.selector);
        token.burn(address(this), 5);
        vm.assertEq(token.balanceOf(address(this)), 5);
    }
}
