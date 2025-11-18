import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

const accessManagerModule = buildModule("AccessManager", (m) => {
    const initialOwner = m.getAccount(0);

    const accessManager = m.contract("AccessManager", [initialOwner]);

    return { accessManager };
});

export default accessManagerModule;