import { ethers } from "hardhat";

async function main() {

    const [deployer] = await ethers.getSigners();

    console.log("Deploying contracts with the account:", deployer.address);

    console.log("Account balance:", (await deployer.getBalance()).toString());

    const Clocktower = await ethers.getContractFactory("Clocktower");
    const ClockToken = await ethers.getContractFactory("CLOCKToken");
    const clocktower = await Clocktower.deploy();
    const clockToken = await ClockToken.deploy(ethers.utils.parseEther("100000"));

    await clocktower.deployed();

    console.log("Clocktower deployed...");

    console.log("Contract address:", clocktower.address);

    await clockToken.deployed();

    console.log("CLOCK Token deployed...")

    console.log("Contract address:", clockToken.address);

    

}

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
  });