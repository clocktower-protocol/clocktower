import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

export default buildModule("ClocktowerHardhat", (m) => {

    const clockSubscribe = m.contract("ClockTowerSubscribe", [10200n, 10000000000000000n, 5n, false, "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266"])

    return { clockSubscribe }
})