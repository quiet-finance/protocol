import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";
import LiquidityHubModule from "./LiquidityHub.ts";

const routerModule = buildModule("Router", (m) => {
    const { LiquidityHub } = m.useModule(LiquidityHubModule);

    const router = m.contract("Router", [LiquidityHub]);

    return { router };
});

export default routerModule;