import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";
import accessManagerModule, { ROLES } from "./accessManager.ts";
import qUSDModule from "./qUSD.ts";
import sqUSDModule from "./sqUSD.ts";

const LiquidityHubModule = buildModule("LiquidityHub", (m) => {
    const proxyAdminOwner = m.getAccount(0);
    const { accessManager } = m.useModule(accessManagerModule);
    const { qUSD } = m.useModule(qUSDModule);
    const { sqUSD } = m.useModule(sqUSDModule);

    const liquidityHubImpl = m.contract("LiquidityHub", [m.getParameter("UNDERLYING"), qUSD, sqUSD], { id: "impl" });
    const initializeCall = m.encodeFunctionCall(liquidityHubImpl, "initialize", [
        accessManager,
        m.getParameter("TREASURY"),
        10, // 0.1% mint fee
        50, // 0.5% instant redeem fee
        1000, // 10% performance fee 
    ]);

    const proxy = m.contract("TransparentUpgradeableProxy", [
        liquidityHubImpl,
        proxyAdminOwner,
        initializeCall,
    ], { id: "auxiliaryProxy" });
    const proxyAdminAddress = m.readEventArgument(
        proxy,
        "AdminChanged",
        "newAdmin",
    );
    const proxyAdmin = m.contractAt("ProxyAdmin", proxyAdminAddress, { id: "proxyAdmin" });
    const liquidityHub = m.contractAt("LiquidityHub", proxy, { id: "proxy" });

    return { liquidityHub, proxyAdmin };
});


export default LiquidityHubModule;