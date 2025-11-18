import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";
import accessManagerModule from "./accessManager.ts";
import qUSDModule from "./qUSD.ts";
import sqUSDModule from "./sqUSD.ts";

const GatewayModule = buildModule("Gateway", (m) => {
    const proxyAdminOwner = m.getAccount(0);
    const { accessManager } = m.useModule(accessManagerModule);
    const { qUSD } = m.useModule(qUSDModule);
    const { sqUSD } = m.useModule(sqUSDModule);

    const gatewayImpl = m.contract("Gateway", [m.getParameter("ASSET"), qUSD, sqUSD], { id: "impl" });
    const initializeCall = m.encodeFunctionCall(gatewayImpl, "initialize", [
        accessManager,
        m.getParameter("TREASURY"),
        10, // 0.1% mint fee
        50, // 0.5% instant redeem fee
        1000, // 10% performance fee 
    ]);

    const proxy = m.contract("TransparentUpgradeableProxy", [
        gatewayImpl,
        proxyAdminOwner,
        initializeCall,
    ], { id: "auxiliaryProxy" });
    const proxyAdminAddress = m.readEventArgument(
        proxy,
        "AdminChanged",
        "newAdmin",
    );
    const proxyAdmin = m.contractAt("ProxyAdmin", proxyAdminAddress, { id: "proxyAdmin" });
    const gateway = m.contractAt("Gateway", proxy, { id: "proxy" });

    return { gateway, proxyAdmin };
});


export default GatewayModule;