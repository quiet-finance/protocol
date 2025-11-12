// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Test} from "forge-std/Test.sol";
import {MockERC20} from "forge-std/src/mocks/MockERC20.sol";

import "../test/utils.sol" as $;
import {MockProtocol} from "../test/MockProtocol.sol";
import {MockLiquidityEdge} from "../test/MockLiquidityEdge.sol";
import {MockStrategy} from "./Strategy.t.sol";

import {LiquidityNode, ILiquidityNode} from "./LiquidityNode.sol";
import {UnderlyingToken} from "./UnderlyingToken.sol";

contract MockLiquidityNode is LiquidityNode {
    constructor(IERC20 token) UnderlyingToken(token) {}

    function initialize(address initialAuthority) public initializer {
        __AccessManaged_init(initialAuthority);
    }
}

contract LiquidityNodeTest is Test {
    LiquidityNode node;
    MockStrategy strategy;
    MockStrategy otherStrategy;
    MockERC20 token;
    MockERC20 otherToken;
    MockLiquidityEdge edge;
    MockLiquidityEdge otherEdge;

    function setUp() external {
        token = deployMockERC20("token", "token", 18);
        deal(address(token), address(this), 1000);

        otherToken = deployMockERC20("token", "token", 18);

        LiquidityNode nodeImpl = new MockLiquidityNode(IERC20(address(token)));
        node = LiquidityNode(
            $.proxy.deploy(
                address(nodeImpl),
                address(this),
                abi.encodeCall(MockLiquidityNode.initialize, ($.accessManager.addr()))
            )
        );

        strategy = MockStrategy(
            $.proxy.deploy(
                address(new MockStrategy(IERC20(address(token)))),
                address(this),
                abi.encodeCall(MockStrategy.initialize, ($.accessManager.addr()))
            )
        );

        otherStrategy = MockStrategy(
            $.proxy.deploy(
                address(new MockStrategy(IERC20(address(otherToken)))),
                address(this),
                abi.encodeCall(MockStrategy.initialize, ($.accessManager.addr()))
            )
        );

        edge = MockLiquidityEdge(
            $.proxy.deploy(
                address(new MockLiquidityEdge(IERC20(address(token)))),
                address(this),
                abi.encodeCall(MockLiquidityEdge.initialize, ($.accessManager.addr()))
            )
        );

        otherEdge = MockLiquidityEdge(
            $.proxy.deploy(
                address(new MockLiquidityEdge(IERC20(address(otherToken)))),
                address(this),
                abi.encodeCall(MockStrategy.initialize, ($.accessManager.addr()))
            )
        );
    }

    function test_addStrategy() external {
        // addStrategy unauthorized
        $.accessManager.expectAccessManagedUnauthorized();
        node.addStrategy(address(strategy));

        $.accessManager.grantAccess(address(node), node.addStrategy.selector);

        vm.expectEmit();
        emit ILiquidityNode.StrategyAdded(address(strategy));
        node.addStrategy(address(strategy));

        address[] memory strategies = node.strategies();
        vm.assertEq(strategies.length, 1);
        vm.assertEq(strategies[0], address(strategy), "Strategy should be added to list");

        // strategy with different token
        vm.expectRevert(ILiquidityNode.UnsupportedStrategy.selector);
        node.addStrategy(address(otherStrategy));
    }

    function test_removeStrategy() external {
        // We should add strategy first
        $.accessManager.grantAccess(address(node), node.addStrategy.selector);
        node.addStrategy(address(strategy));

        // removeStrategy unauthorized
        $.accessManager.expectAccessManagedUnauthorized();
        node.removeStrategy(address(strategy));

        $.accessManager.grantAccess(address(node), node.removeStrategy.selector);

        vm.expectEmit();
        emit ILiquidityNode.StrategyAdded(address(strategy));
        node.removeStrategy(address(strategy));

        vm.assertEq(node.strategies().length, 0);

        // removeStrategy with NAV
        node.addStrategy(address(strategy));
        deal(address(token), address(strategy), 1);
        $.accessManager.grantAccess(address(strategy), strategy.deposit.selector);
        strategy.deposit(1, bytes(""));

        vm.expectRevert(ILiquidityNode.NavShouldBeZero.selector);
        node.removeStrategy(address(strategy));
    }

    function test_addLiquidityEdge() external {
        // addLiquidityEdge unauthorized
        $.accessManager.expectAccessManagedUnauthorized();
        node.addLiquidityEdge(address(edge));

        $.accessManager.grantAccess(address(node), node.addLiquidityEdge.selector);

        vm.expectEmit();
        emit ILiquidityNode.LiquidityEdgeAdded(address(edge));
        node.addLiquidityEdge(address(edge));

        address[] memory liquidityEdges = node.liquidityEdges();
        vm.assertEq(liquidityEdges.length, 1);
        vm.assertEq(liquidityEdges[0], address(edge), "LiquidityEdge should be added to list");

        // LiquidityEdge with different token
        vm.expectRevert(ILiquidityNode.UnsupportedLiquidityNode.selector);
        node.addLiquidityEdge(address(otherEdge));
    }

    function test_removeLiquidityEdge() external {
        // removeLiquidityEdge unauthorized
        $.accessManager.expectAccessManagedUnauthorized();
        node.removeLiquidityEdge(address(edge));

        $.accessManager.grantAccess(address(node), node.removeLiquidityEdge.selector);

        vm.expectEmit();
        emit ILiquidityNode.LiquidityEdgeRemoved(address(edge));
        node.removeLiquidityEdge(address(edge));

        address[] memory liquidityEdges = node.liquidityEdges();
        vm.assertEq(liquidityEdges.length, 0);
        vm.assertEq(
            node.token().allowance(address(node), address(edge)),
            0,
            "LiquidityNode should remove allowance from LiquidityEdge"
        );
    }

    function test_enter() external {
        revert("Not implemented");
    }

    function test_exit() external {
        revert("Not implemented");
    }

    function test_transferLiquidity() external {
        revert("Not implemented");
    }
}
