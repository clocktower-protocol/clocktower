import { ethers } from "hardhat";

async function main() {

    const Clocktower = await ethers.getContractFactory("Clocktower");
    const clocktower = await Clocktower.deploy();

    await clocktower.deployed();

    console.log("Clocktower deployed...");

}

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
  });