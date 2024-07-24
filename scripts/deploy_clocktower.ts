//import { ethers } from "hardhat";
const { ethers } = require("hardhat");
import hre from "hardhat"

async function main() {

    const [deployer] = await ethers.getSigners();

    console.log("Deploying contracts with the account:", deployer.address);

    console.log("Account balance:", (await deployer.provider.getBalance(deployer.address)).toString());

    const TestUser = "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266";
    const SecondUser = "0x70997970C51812dc3A010C7d01b50e0d17dc79C8";
    const Subscriber = "0x90F79bf6EB2c4f870365E785982E1f101E93b906";
    const Provider = "0x15d34AAf54267DB7D7c367839AAf71A00a2C6A65";
    const Caller = "0x9965507D1a55bcC2695C58ba16FB37d819B0A4dc";
    
    const ClockToken = await hre.ethers.getContractFactory("CLOCKToken");
    //const ClockSubscribe = await hre.ethers.getContractFactory("contracts/ClockTowerSubscribe.sol:ClockTowerSubscribe")
    const ClockSubscribe = await hre.ethers.getContractFactory("ClockTowerSubscribe")
    const clockSubscribe = await ClockSubscribe.deploy();
    const clockToken = await ClockToken.deploy(hre.ethers.parseEther("100000"));
  
    await clockSubscribe.waitForDeployment();

    console.log("Clocktower deployed...");

    await clockToken.waitForDeployment();

    console.log("CLOCK Token deployed...")

    const clockTokenAddress = await clockToken.getAddress()
    const clockSubscribeAddress = await clockSubscribe.getAddress()

    console.log("Contract address:", clockTokenAddress);

    //approve token for clocktower
    await clockSubscribe.addERC20Contract(clockTokenAddress, hre.ethers.parseEther("0.01"));
    console.log("Approved contract..."+clockTokenAddress);

    //funds test users accounts with CLOCK
    await clockToken.approve(TestUser, hre.ethers.parseEther("10000"));
    await clockToken.transfer(TestUser, hre.ethers.parseEther("10000"));

    await clockToken.approve(SecondUser, hre.ethers.parseEther("10000"));
    await clockToken.transfer(SecondUser, hre.ethers.parseEther("10000"));

    await clockToken.approve(Subscriber, hre.ethers.parseEther("10000"));
    await clockToken.transfer(Subscriber, hre.ethers.parseEther("10000"));

    await clockToken.approve(Provider, hre.ethers.parseEther("10000"));
    await clockToken.transfer(Provider, hre.ethers.parseEther("10000"));

    await clockToken.approve(Caller, hre.ethers.parseEther("10000"));
    await clockToken.transfer(Caller, hre.ethers.parseEther("10000"));
    console.log("Funds test users with 10000 CLOCK");

    console.log("ClocktowerSubscribe Deployed!")
    console.log("Contract address:", clockSubscribeAddress);
}

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
  });