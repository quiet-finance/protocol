import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";
import qusdModule from "./qUSD.ts";

const sqUSDModule = buildModule("sqUSD", (m) => {
    const proxyAdminOwner = m.getAccount(0);
    const { qUSD } = m.useModule(qusdModule);

    const sqUSDImpl = m.contract("sqUSD", [], { id: "impl" });
    const initializeCall = m.encodeFunctionCall(sqUSDImpl, "initialize", [qUSD]);

    const proxy = m.contract("TransparentUpgradeableProxy", [
        sqUSDImpl,
        proxyAdminOwner,
        initializeCall,
    ], { id: "auxiliaryProxy" });
    const proxyAdminAddress = m.readEventArgument(
        proxy,
        "AdminChanged",
        "newAdmin",
    );
    const proxyAdmin = m.contractAt("ProxyAdmin", proxyAdminAddress, { id: "proxyAdmin" });
    const sqUSD = m.contractAt("sqUSD", proxy, { id: "proxy" });

    return { sqUSD, proxyAdmin };
});


export default sqUSDModule;