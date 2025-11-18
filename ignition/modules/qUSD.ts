import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";
import accessManagerModule from "./accessManager.ts";

const qUSDModule = buildModule("qUSD", (m) => {
    const proxyAdminOwner = m.getAccount(0);
    const { accessManager } = m.useModule(accessManagerModule);

    const qUSDImpl = m.contract("qUSD", [], { id: "impl" });
    const initializeCall = m.encodeFunctionCall(qUSDImpl, "initialize", [accessManager]);

    const proxy = m.contract("TransparentUpgradeableProxy", [
        qUSDImpl,
        proxyAdminOwner,
        initializeCall,
    ], { id: "auxiliaryProxy" });
    const proxyAdminAddress = m.readEventArgument(
        proxy,
        "AdminChanged",
        "newAdmin",
    );
    const proxyAdmin = m.contractAt("ProxyAdmin", proxyAdminAddress, { id: "proxyAdmin" });
    const qUSD = m.contractAt("qUSD", proxy, { id: "proxy" });

    return { qUSD, proxyAdmin };
});


export default qUSDModule;