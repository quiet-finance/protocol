// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Test} from "forge-std/Test.sol";
import {MockERC20} from "forge-std/src/mocks/MockERC20.sol";
import "./test/utils.sol" as $;

import {qUSD} from "./tokens/qUSD.sol";
import {sqUSD} from "./tokens/sqUSD.sol";
import {LiquidityHub, ILiquidityHub} from "./LiquidityHub.sol";
import {Bps} from "./libraries/BpsMath.sol";

import "hardhat/console.sol";

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
                        Bps.wrap(10), // 0.1%
                        Bps.wrap(50), // 0.5%
                        Bps.wrap(1000) // 10%
                    )
                )
            )
        );

        $.accessManager.grantAccess(address(qusd), address(liquidityHub), qUSD.mint.selector);
        $.accessManager.grantAccess(address(qusd), address(liquidityHub), qUSD.burn.selector);
    }

    function test_issue() external {
        (address treasury, Bps mintFeeBps, , ) = liquidityHub.getFees();
        uint256 usdcAmount = 100 * 1e6;
        uint256 treasuryFee = (usdcAmount * Bps.unwrap(mintFeeBps)) / 1e4;
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
        _disableMintFee();

        (address treasury, , Bps instantRedeemFeeBps, ) = liquidityHub.getFees();
        uint256 usdcAmount = 100 * 1e6;
        uint256 treasuryFee = (usdcAmount * Bps.unwrap(instantRedeemFeeBps)) / 1e4;
        deal(address(usdc), address(this), usdcAmount);
        usdc.approve(address(liquidityHub), usdcAmount);
        liquidityHub.issue(address(this), usdcAmount);

        uint256 liquidityHubBalanceBefore = usdc.balanceOf(address(liquidityHub));
        uint256 userBalanceBefore = usdc.balanceOf(user);
        uint256 treasuryBalanceBefore = usdc.balanceOf(treasury);
        liquidityHub.redeemInstant(user, qusd.balanceOf(address(this)));

        assertEq(qusd.balanceOf(address(this)), 0, "LiquidityHub should burn qUSD");
        assertEq(
            liquidityHubBalanceBefore - usdc.balanceOf(address(liquidityHub)),
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

    function test_redeemInstant_limitedUnerlying() external {
        deal(address(qusd), address(this), 2e18);
        deal(address(usdc), address(this), 1e6);

        vm.expectRevert(ILiquidityHub.NoAvailableUnderlyingAmount.selector);
        liquidityHub.redeemInstant(address(this), 2e18);
    }

    function test_requestRedeem() external {
        _disableMintFee();

        uint256 usdcAmount = 100 * 1e6;
        deal(address(usdc), address(this), usdcAmount);
        usdc.approve(address(liquidityHub), usdcAmount);

        uint256 requestAmount = qusd.balanceOf(address(this)) / 2;
        uint256 requestId = liquidityHub.requestRedeem(user, requestAmount);
        LiquidityHub.RedeemData memory redeem = liquidityHub.getRedeem(requestId);

        assertEq(redeem.recipient, user);
        assertEq(redeem.assetAmount, requestAmount);
        assertEq(redeem.isClaimed, false);
        assertEq(redeem.cumAssetAmount, requestAmount);

        uint256 redeem2Amount = qusd.balanceOf(address(this));
        LiquidityHub.RedeemData memory redeem2 = liquidityHub.getRedeem(
            liquidityHub.requestRedeem(user, redeem2Amount)
        );
        assertEq(redeem2.assetAmount, redeem2Amount);
        assertEq(redeem2.cumAssetAmount, requestAmount + redeem2Amount);

        assertEq(qusd.balanceOf(address(this)), 0, "LiquidityHub should burn qUSD");
    }

    function test_finishRedeem() external {
        _disableMintFee();

        uint256 usdcAmount = 100 * 1e6;
        deal(address(usdc), address(this), usdcAmount);
        usdc.approve(address(liquidityHub), usdcAmount);
        liquidityHub.issue(address(this), usdcAmount);
        uint256 redeemId = liquidityHub.requestRedeem(user, qusd.balanceOf(address(this)));

        // Should revert before setMaxRedeemableId call
        vm.expectRevert(ILiquidityHub.RedeemNotProcessed.selector);
        liquidityHub.claimRedeem(redeemId);

        $.accessManager.grantAccess(address(liquidityHub), address(this), LiquidityHub.processRedeems.selector);
        liquidityHub.processRedeems(redeemId);
        uint256 balanceBefore = usdc.balanceOf(user);
        liquidityHub.claimRedeem(redeemId);
        LiquidityHub.RedeemData memory request = liquidityHub.getRedeem(redeemId);

        assertEq(request.isClaimed, true);
        assertEq(usdc.balanceOf(user) - balanceBefore, usdcAmount);
    }

    function test_startRebalance(uint256 underlyingToDeploy) external {
        vm.assume(underlyingToDeploy <= uint256(type(int256).max / 1e12));
        $.accessManager.grantAccess(address(liquidityHub), address(this), LiquidityHub.startRebalance.selector);
        $.accessManager.grantAccess(address(liquidityHub), address(this), LiquidityHub.finishRebalance.selector);

        deal(address(usdc), address(liquidityHub), uint256(underlyingToDeploy));
        uint256 balanceBefore = usdc.balanceOf(address(this));
        liquidityHub.startRebalance(int256(underlyingToDeploy));
        assertEq(usdc.balanceOf(address(this)) - balanceBefore, underlyingToDeploy);
    }

    function test_finshRebalance(uint256 deployedUnderlying) external {
        uint256 deployedUnderlyingBefore = 1000 * 1e6;
        uint256 deployedAssetsBefore = deployedUnderlyingBefore * 1e12;

        vm.assume(deployedUnderlying < 2 * deployedUnderlyingBefore);
        vm.assume(deployedUnderlying > deployedUnderlyingBefore / 2);
        vm.assume(deployedUnderlying > deployedUnderlyingBefore / 2);

        (address treasury, , , Bps performanceFeeBps) = liquidityHub.getFees();
        uint256 deployedAssets = deployedUnderlying * 1e12;

        deal(address(usdc), address(liquidityHub), 2 * deployedUnderlyingBefore);
        deal(address(qusd), address(squsd), 2 * deployedAssetsBefore);

        $.accessManager.grantAccess(address(liquidityHub), address(this), LiquidityHub.startRebalance.selector);
        liquidityHub.startRebalance(int256(deployedUnderlyingBefore));

        uint256 assetsBefore = qusd.balanceOf(address(squsd));
        uint256 treasuryBalanceBefore = usdc.balanceOf(address(treasury));

        $.accessManager.grantAccess(address(liquidityHub), address(this), LiquidityHub.finishRebalance.selector);

        vm.expectEmit();
        emit ILiquidityHub.RebalanceFinished(deployedUnderlying);
        liquidityHub.finishRebalance(deployedUnderlying);

        if (deployedUnderlying > deployedUnderlyingBefore) {
            uint256 underlyingDelta = deployedUnderlying - deployedUnderlyingBefore;
            assertEq(
                qusd.balanceOf(address(squsd)) - assetsBefore,
                (underlyingDelta - (underlyingDelta * Bps.unwrap(performanceFeeBps)) / 10_000) * 1e12
            );
            assertEq(
                usdc.balanceOf(address(treasury)) - treasuryBalanceBefore,
                (underlyingDelta * Bps.unwrap(performanceFeeBps)) / 10_000
            );
        } else {
            assertEq(assetsBefore - qusd.balanceOf(address(squsd)), deployedAssetsBefore - deployedAssets);
        }
    }

    function _disableMintFee() internal {
        $.accessManager.grantAccess(address(liquidityHub), address(this), LiquidityHub.setMintFee.selector);
        liquidityHub.setMintFee(Bps.wrap(0));
    }
}
