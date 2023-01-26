import { ethers } from "hardhat";

async function main() {

    const [deployer] = await ethers.getSigners();

    console.log("Deploying contracts with the account:", deployer.address);

    console.log("Account balance:", (await deployer.getBalance()).toString());

    const TestUser = "0x70997970C51812dc3A010C7d01b50e0d17dc79C8";
    
    const ClockToken = await ethers.getContractFactory("CLOCKToken");
    const ClockSubscribe = await ethers.getContractFactory("ClockTowerSubscribe")
    const ClockPayment = await ethers.getContractFactory("ClockTowerPayment")

    const clockSubscribe = await ClockSubscribe.deploy();
    const clockPayment = await ClockPayment.deploy();
    const clockToken = await ClockToken.deploy(ethers.utils.parseEther("100000"));
  
    await clockSubscribe.deployed();
    await clockPayment.deployed();

    console.log("Clocktower deployed...");

    await clockToken.deployed();

    console.log("CLOCK Token deployed...")

    console.log("Contract address:", clockToken.address);

    //approve token for clocktower
    await clockPayment.addERC20Contract(clockToken.address);
    console.log("Approved contract..."+clockToken.address);

    //funds test account with CLOCK
    await clockToken.approve(TestUser, ethers.utils.parseEther("10000"));
    await clockToken.transfer(TestUser, ethers.utils.parseEther("10000"));
    console.log("Funds test user 10000 CLOCK");

    console.log("ClocktowerSubscribe Deployed!")
    console.log("Contract address:", clockSubscribe.address);

    console.log("ClocktowerPayment Deployed!")
    console.log("Contract address:", clockPayment.address);
}

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
  });