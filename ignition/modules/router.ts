import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";
import GatewayModule from "./gateway.ts";

const routerModule = buildModule("Router", (m) => {
    const { gateway } = m.useModule(GatewayModule);

    const router = m.contract("Router", [gateway]);

    return { router };
});

export default routerModule;