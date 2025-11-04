// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Test} from "forge-std/Test.sol";
import {MockERC20} from "forge-std/src/mocks/MockERC20.sol";
import "./test/utils.sol" as $;

import {qUSD} from "./tokens/qUSD.sol";
import {sqUSD} from "./tokens/sqUSD.sol";
import {Gateway} from "./Gateway.sol";

contract LiquidityNodeTest is Test {
    MockERC20 usdc;
    qUSD qusd;
    sqUSD squsd;
    Gateway gateway;
    address user = address(222);

    function setUp() external {
        usdc = deployMockERC20("USC", "USDC", 6);
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
                address(new Gateway(IERC20(address(usdc)), qusd, address(squsd))),
                address(this),
                abi.encodeCall(
                    Gateway.initialize,
                    (
                        $.accessManager.addr(),
                        address(777),
                        10, // 0.1%
                        50, // 0.5%
                        1000 // 10%
                    )
                )
            )
        );

        $.accessManager.grantAccess(address(qusd), address(gateway), qUSD.mint.selector);
        $.accessManager.grantAccess(address(qusd), address(gateway), qUSD.burn.selector);
    }

    function test_issue() external {
        (address treasury, uint256 mintFeeBps, , ) = gateway.getFees();
        uint256 usdcAmount = 100 * 1e6;
        uint256 treasuryFee = (usdcAmount * mintFeeBps) / 1e4;
        uint256 qusdAmount = ((usdcAmount - treasuryFee) * 1e18) / 1e6;

        deal(address(usdc), address(this), usdcAmount);
        usdc.approve(address(gateway), usdcAmount);

        uint256 gatewayBalanceBefore = usdc.balanceOf(address(gateway));
        uint256 treasuryBalanceBefore = usdc.balanceOf(address(treasury));
        uint256 userBalanceBefore = qusd.balanceOf(user);
        gateway.issue(user, usdcAmount);

        assertEq(
            usdc.balanceOf(address(gateway)) - gatewayBalanceBefore,
            usdcAmount - treasuryFee,
            "gateway should take USDC (-fee)"
        );
        assertEq(usdc.balanceOf(treasury) - treasuryBalanceBefore, treasuryFee, "gateway should take fee in USDC");
        assertEq(qusd.balanceOf(user) - userBalanceBefore, qusdAmount, "gateway should give qUSD");
    }

    function test_redeemInstant() external {
        // mint fee disabled to simplify testing
        $.accessManager.grantAccess(address(gateway), address(this), Gateway.setMintFee.selector);
        gateway.setMintFee(0);

        (address treasury, , uint256 instantRedeemFeeBps, ) = gateway.getFees();
        uint256 usdcAmount = 100 * 1e6;
        uint256 treasuryFee = (usdcAmount * instantRedeemFeeBps) / 1e4;

        deal(address(usdc), address(this), usdcAmount);
        usdc.approve(address(gateway), usdcAmount);
        gateway.issue(address(this), usdcAmount);

        uint256 gatewayBalanceBefore = usdc.balanceOf(address(gateway));
        uint256 userBalanceBefore = usdc.balanceOf(user);
        uint256 treasuryBalanceBefore = usdc.balanceOf(treasury);
        gateway.redeemInstant(user, qusd.balanceOf(address(this)));

        assertEq(qusd.balanceOf(address(this)), 0, "gateway should burn qUSD");
        assertEq(
            gatewayBalanceBefore - usdc.balanceOf(address(gateway)),
            usdcAmount,
            "gateway should withdraw redeemAmount of USDC"
        );
        assertEq(
            usdc.balanceOf(user) - userBalanceBefore,
            usdcAmount - treasuryFee,
            "user should take redeemAmount of USDC (- fee)"
        );
        assertEq(usdc.balanceOf(treasury) - treasuryBalanceBefore, treasuryFee, "treasury should take fee from redeem");
    }
}
