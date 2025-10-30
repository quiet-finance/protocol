// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Test} from "forge-std/Test.sol";

import "./test/utils.sol" as $;
import {MockAsset as USDC} from "./test/MockAsset.sol";
import {qUSD} from "./tokens/qUSD.sol";
import {sqUSD} from "./tokens/sqUSD.sol";
import {Gateway} from "./Gateway.sol";

contract LiquidityNodeTest is Test {
    USDC usdc;
    qUSD qusd;
    sqUSD squsd;
    Gateway gateway;
    address treasury = address(777);
    address user = address(222);

    function setUp() external {
        usdc = new USDC();
        qusd = qUSD(
            $.proxy.deploy(
                address(new qUSD()),
                address(this),
                abi.encodeCall(qUSD.initialize, ($.accessManager.addr()))
            )
        );
        squsd = sqUSD(
            $.proxy.deploy(
                address(new sqUSD()),
                address(this),
                abi.encodeCall(sqUSD.initialize, (qusd, $.accessManager.addr()))
            )
        );

        gateway = Gateway(
            $.proxy.deploy(
                address(new Gateway(usdc, qusd, address(squsd))),
                address(this),
                abi.encodeCall(
                    Gateway.initialize,
                    (
                        $.accessManager.addr(),
                        treasury,
                        300, // 3%
                        1000 // 10%
                    )
                )
            )
        );

        $.accessManager.grantAccess(address(qusd), address(gateway), qUSD.mint.selector);
        $.accessManager.grantAccess(address(qusd), address(gateway), qUSD.burn.selector);
    }

    function test_issue() external {
        uint256 issueAmount = 10;

        usdc.mint(address(this), issueAmount);
        usdc.approve(address(gateway), issueAmount);
        uint256 gatewayBalanceBefore = usdc.balanceOf(address(gateway));
        uint256 userBalanceBefore = qusd.balanceOf(user);
        gateway.issue(user, issueAmount);

        assertEq(usdc.balanceOf(address(gateway)) - gatewayBalanceBefore, issueAmount, "gateway should take USDC");
        assertEq(qusd.balanceOf(user) - userBalanceBefore, issueAmount, "gateway should give qUSD");
    }

    function test_redeemInstant() external {
        uint256 redeemAmount = 10;

        usdc.mint(address(this), redeemAmount);
        usdc.approve(address(gateway), redeemAmount);
        gateway.issue(address(this), redeemAmount);
        uint256 redeemerBalanceBefore = qusd.balanceOf(address(this));
        uint256 gatewayBalanceBefore = usdc.balanceOf(address(gateway));
        uint256 userBalanceBefore = usdc.balanceOf(user);
        uint256 treasuryBalanceBefore = usdc.balanceOf(gateway.treasury());
        gateway.redeemInstant(user, redeemAmount);

        assertEq(redeemerBalanceBefore - qusd.balanceOf(address(this)), redeemAmount, "gateway should burn qUSD");
        assertEq(
            gatewayBalanceBefore - usdc.balanceOf(address(gateway)),
            redeemAmount,
            "gateway should withdraw redeemAmount of USDC"
        );
        assertEq(
            usdc.balanceOf(user) - userBalanceBefore,
            redeemAmount - (redeemAmount * gateway.instantRedeemFeeBps()) / 10000,
            "user should take redeemAmount of USDC (- fee)"
        );
        assertEq(
            usdc.balanceOf(gateway.treasury()) - treasuryBalanceBefore,
            (redeemAmount * gateway.instantRedeemFeeBps()) / 10000,
            "treasury should take fee from redeem"
        );
    }
}
