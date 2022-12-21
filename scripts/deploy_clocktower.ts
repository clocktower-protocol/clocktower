import { ethers } from "hardhat";

async function main() {

    const [deployer] = await ethers.getSigners();

    console.log("Deploying contracts with the account:", deployer.address);

    console.log("Account balance:", (await deployer.getBalance()).toString());

    const TestUser = "0x70997970C51812dc3A010C7d01b50e0d17dc79C8";
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

    //approve token for clocktower
    await clocktower.addERC20Contract(clockToken.address);
    console.log("Approved contract..."+clockToken.address);

    //funds test account with CLOCK
    await clockToken.approve(TestUser, ethers.utils.parseEther("10000"));
    await clockToken.transfer(TestUser, ethers.utils.parseEther("10000"));
    console.log("Funds test user 10000 CLOCK");
}

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
  });