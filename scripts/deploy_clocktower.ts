import { ethers } from "hardhat";

async function main() {

    const [deployer] = await ethers.getSigners();

    console.log("Deploying contracts with the account:", deployer.address);

    console.log("Account balance:", (await deployer.getBalance()).toString());

    const TestUser = "0x70997970C51812dc3A010C7d01b50e0d17dc79C8";
    const SecondUser = "0x15d34AAf54267DB7D7c367839AAf71A00a2C6A65";
    const Subscriber = "0x5FbDB2315678afecb367f032d93F642f64180aa3";
    const Provider = "0x15d34AAf54267DB7D7c367839AAf71A00a2C6A65";
    const Caller = "0x9965507D1a55bcC2695C58ba16FB37d819B0A4dc";
    
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
    await clockSubscribe.addERC20Contract(clockToken.address);
    console.log("Approved contract..."+clockToken.address);

    //funds test users accounts with CLOCK
    await clockToken.approve(TestUser, ethers.utils.parseEther("10000"));
    await clockToken.transfer(TestUser, ethers.utils.parseEther("10000"));

    await clockToken.approve(SecondUser, ethers.utils.parseEther("10000"));
    await clockToken.transfer(SecondUser, ethers.utils.parseEther("10000"));

    await clockToken.approve(Subscriber, ethers.utils.parseEther("10000"));
    await clockToken.transfer(Subscriber, ethers.utils.parseEther("10000"));

    await clockToken.approve(Provider, ethers.utils.parseEther("10000"));
    await clockToken.transfer(Provider, ethers.utils.parseEther("10000"));

    await clockToken.approve(Caller, ethers.utils.parseEther("10000"));
    await clockToken.transfer(Caller, ethers.utils.parseEther("10000"));
    console.log("Funds test users with 10000 CLOCK");

    console.log("ClocktowerSubscribe Deployed!")
    console.log("Contract address:", clockSubscribe.address);

    console.log("ClocktowerPayment Deployed!")
    console.log("Contract address:", clockPayment.address);
}

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
  });