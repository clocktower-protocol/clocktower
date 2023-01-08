import { ethers } from "hardhat";

async function main() {

    const [deployer] = await ethers.getSigners();

    console.log("Deploying contracts with the account:", deployer.address);

    console.log("Account balance:", (await deployer.getBalance()).toString());

    const TestUser = "0x70997970C51812dc3A010C7d01b50e0d17dc79C8";
    const Clocktower = await ethers.getContractFactory("Clocktower");
    const ClockToken = await ethers.getContractFactory("CLOCKToken");
    const ClockSubscribe = await ethers.getContractFactory("contracts/ClocktowerSubscribe.sol")
    const ClockPayment = await ethers.getContractFactory("contracts/ClockTowerPayment.sol")

    //const ClockPure = await ethers.getContractFactory("contracts/ClocktowerPure.sol");
    //const ClockLibrary = await ethers.getContractFactory("ClockTowerLibrary");

    const clocktower = await Clocktower.deploy();
    const clockSubscribe = await ClockSubscribe.deploy();
    const clockPayment = await ClockPayment.deploy();
    const clockToken = await ClockToken.deploy(ethers.utils.parseEther("100000"));
    //const clockPure = await ClockPure.deploy();
    
    //const clockLibrary = await ClockLibrary.deploy();

    await clocktower.deployed();
    await clockSubscribe.deployed();
    await clockPayment.deployed();
   // await clockPure.deployed();

    console.log("Clocktower deployed...");
    

    console.log("Contract address:", clocktower.address);
   // console.log("ClockPure address", clockPure.address);

    await clockToken.deployed();

    console.log("CLOCK Token deployed...")

    console.log("Contract address:", clockToken.address);

    //approve token for clocktower
    await clocktower.addERC20Contract(clockToken.address);
    await clockPayment.addERC20Contract(clockToken.address);
    console.log("Approved contract..."+clockToken.address);

    //funds test account with CLOCK
    await clockToken.approve(TestUser, ethers.utils.parseEther("10000"));
    await clockToken.transfer(TestUser, ethers.utils.parseEther("10000"));
    console.log("Funds test user 10000 CLOCK");

    console.log("ClocktowerSubscribe Deployed!")
    console.log("Contract address:", clockSubscribe.address);


   // await clockLibrary.deployed();
    //console.log("Contract address:", clockLibrary.address)
}

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
  });