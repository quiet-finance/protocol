import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

export const ROLES = {
    QUSD_MINTER: 1,
    REBALANCER: 2,
}

const accessManagerModule = buildModule("AccessManager", (m) => {
    const initialOwner = m.getAccount(0);

    const accessManager = m.contract("AccessManager", [initialOwner]);

    return { accessManager };
});

export default accessManagerModule;