import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";
import accessManagerModule, { ROLES } from "./accessManager.ts";
import qUSDModule from "./qUSD.ts";
import sqUSDModule from "./sqUSD.ts";

const LiquidityHubModule = buildModule("LiquidityHub", (m) => {
    const proxyAdminOwner = m.getAccount(0);
    const { accessManager } = m.useModule(accessManagerModule);
    const { qUSD } = m.useModule(qUSDModule);
    const { sqUSD } = m.useModule(sqUSDModule);

    const LiquidityHubImpl = m.contract("LiquidityHub", [m.getParameter("ASSET"), qUSD, sqUSD], { id: "impl" });
    const initializeCall = m.encodeFunctionCall(LiquidityHubImpl, "initialize", [
        accessManager,
        m.getParameter("TREASURY"),
        10, // 0.1% mint fee
        50, // 0.5% instant redeem fee
        1000, // 10% performance fee 
    ]);

    const proxy = m.contract("TransparentUpgradeableProxy", [
        LiquidityHubImpl,
        proxyAdminOwner,
        initializeCall,
    ], { id: "auxiliaryProxy" });
    const proxyAdminAddress = m.readEventArgument(
        proxy,
        "AdminChanged",
        "newAdmin",
    );
    const proxyAdmin = m.contractAt("ProxyAdmin", proxyAdminAddress, { id: "proxyAdmin" });
    const LiquidityHub = m.contractAt("LiquidityHub", proxy, { id: "proxy" });

    m.call(accessManager, "grantRole", [ROLES.QUSD_MINTER, LiquidityHub, 0])
    m.call(accessManager, "setTargetFunctionRole", [
        qUSD,
        [
            "0x40c10f19", // mint(address,uint256)
            "0x9dc29fac", // burn(address,uint256)
        ],
        ROLES.QUSD_MINTER
    ])

    return { LiquidityHub, proxyAdmin };
});


export default LiquidityHubModule;