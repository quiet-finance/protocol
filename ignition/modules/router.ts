import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";
import LiquidityHubModule from "./liquidityHub.ts";

const routerModule = buildModule("Router", (m) => {
    const { liquidityHub } = m.useModule(LiquidityHubModule);

    const router = m.contract("Router", [liquidityHub]);

    return { router };
});

export default routerModule;