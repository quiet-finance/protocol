import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";
import accessManagerModule, { ROLES } from "./accessManager.ts";
import qUSDModule from "./qUSD.ts";
import { toFunctionSelector } from "viem";
import LiquidityHubModule from "./liquidityHub.ts";

export default buildModule("setupRoles", (m) => {
    const { accessManager } = m.useModule(accessManagerModule);
    const { liquidityHub } = m.useModule(LiquidityHubModule);
    const { qUSD } = m.useModule(qUSDModule);

    m.call(accessManager, "grantRole", [ROLES.QUSD_MINTER, liquidityHub, 0], { id: "setupQusdMinterRole" })
    m.call(accessManager, "setTargetFunctionRole", [
        qUSD,
        [
            toFunctionSelector("mint(address,uint256)"),
            toFunctionSelector("burn(address,uint256)"),
        ],
        ROLES.QUSD_MINTER
    ], { id: "grantQusdMinterRole" })

    m.call(accessManager, "grantRole", [ROLES.REBALANCER, m.getParameter("REBALANCER"), 0], { id: "setupRebalancerRole" })
    m.call(accessManager, "setTargetFunctionRole", [
        liquidityHub,
        [
            toFunctionSelector("startRebalance(int256)"),
            toFunctionSelector("finishRebalance(uint256)"),
            toFunctionSelector("processRedeems(uint256)"),
        ],
        ROLES.REBALANCER
    ], { id: "grantRebalancerRole" })

    return {}
})