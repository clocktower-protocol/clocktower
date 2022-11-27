import { ethers } from "hardhat";

async function main() {

    const [deployer] = await ethers.getSigners();

    console.log("Deploying contracts with the account:", deployer.address);

    console.log("Account balance:", (await deployer.getBalance()).toString());

    const Clocktower = await ethers.getContractFactory("Clocktower");
    const clocktower = await Clocktower.deploy();

    await clocktower.deployed();

    console.log("Clocktower deployed...");

    console.log("Contract address:", clocktower.address);

}

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
  });