// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Test} from "forge-std/Test.sol";
import {MockERC20} from "forge-std/src/mocks/MockERC20.sol";
import "./test/utils.sol" as $;

import {qUSD} from "./tokens/qUSD.sol";
import {sqUSD} from "./tokens/sqUSD.sol";
import {LiquidityHub} from "./LiquidityHub.sol";

contract LiquidityHubTest is Test {
    MockERC20 usdc;
    qUSD qusd;
    sqUSD squsd;
    LiquidityHub liquidityHub;
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
        squsd = sqUSD($.proxy.deploy(address(new sqUSD()), address(this), abi.encodeCall(sqUSD.initialize, (qusd))));

        liquidityHub = LiquidityHub(
            $.proxy.deploy(
                address(new LiquidityHub(IERC20(address(usdc)), qusd, squsd)),
                address(this),
                abi.encodeCall(
                    LiquidityHub.initialize,
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

        $.accessManager.grantAccess(address(qusd), address(liquidityHub), qUSD.mint.selector);
        $.accessManager.grantAccess(address(qusd), address(liquidityHub), qUSD.burn.selector);
    }

    function test_issue() external {
        (address treasury, uint256 mintFeeBps, , ) = liquidityHub.getFees();
        uint256 usdcAmount = 100 * 1e6;
        uint256 treasuryFee = (usdcAmount * mintFeeBps) / 1e4;
        uint256 qusdAmount = ((usdcAmount - treasuryFee) * 1e18) / 1e6;

        deal(address(usdc), address(this), usdcAmount);
        usdc.approve(address(liquidityHub), usdcAmount);

        uint256 liquidityHubBalanceBefore = usdc.balanceOf(address(liquidityHub));
        uint256 treasuryBalanceBefore = usdc.balanceOf(address(treasury));
        uint256 userBalanceBefore = qusd.balanceOf(user);
        liquidityHub.issue(user, usdcAmount);

        assertEq(
            usdc.balanceOf(address(liquidityHub)) - liquidityHubBalanceBefore,
            usdcAmount - treasuryFee,
            "LiquidityHub should take USDC (-fee)"
        );
        assertEq(usdc.balanceOf(treasury) - treasuryBalanceBefore, treasuryFee, "LiquidityHub should take fee in USDC");
        assertEq(qusd.balanceOf(user) - userBalanceBefore, qusdAmount, "LiquidityHub should give qUSD");
    }

    function test_redeemInstant() external {
        // mint fee disabled to simplify testing
        $.accessManager.grantAccess(address(liquidityHub), address(this), LiquidityHub.setMintFee.selector);
        liquidityHub.setMintFee(0);

        (address treasury, , uint256 instantRedeemFeeBps, ) = liquidityHub.getFees();
        uint256 usdcAmount = 100 * 1e6;
        uint256 treasuryFee = (usdcAmount * instantRedeemFeeBps) / 1e4;

        deal(address(usdc), address(this), usdcAmount);
        usdc.approve(address(liquidityHub), usdcAmount);
        liquidityHub.issue(address(this), usdcAmount);

        uint256 LiquidityHubBalanceBefore = usdc.balanceOf(address(liquidityHub));
        uint256 userBalanceBefore = usdc.balanceOf(user);
        uint256 treasuryBalanceBefore = usdc.balanceOf(treasury);
        liquidityHub.redeemInstant(user, qusd.balanceOf(address(this)));

        assertEq(qusd.balanceOf(address(this)), 0, "LiquidityHub should burn qUSD");
        assertEq(
            LiquidityHubBalanceBefore - usdc.balanceOf(address(liquidityHub)),
            usdcAmount,
            "LiquidityHub should withdraw redeemAmount of USDC"
        );
        assertEq(
            usdc.balanceOf(user) - userBalanceBefore,
            usdcAmount - treasuryFee,
            "user should take redeemAmount of USDC (- fee)"
        );
        assertEq(usdc.balanceOf(treasury) - treasuryBalanceBefore, treasuryFee, "treasury should take fee from redeem");
    }
}
