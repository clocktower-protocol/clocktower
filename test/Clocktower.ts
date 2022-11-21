import { loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { time } from "@nomicfoundation/hardhat-network-helpers";
//import { anyValue } from "@nomicfoundation/hardhat-chai-matchers/withArgs";
import { expect } from "chai";
import { ethers } from "hardhat";

describe("Clocktower", function(){

    //sends receive time in unix epoch seconds
    let millis = Date.now();
    let currentTime = Math.floor(millis / 1000);
    //hour merge occured
    let mergeTime = 1663264750;
    let hoursSinceMerge = Math.floor((currentTime - mergeTime) /3600);
    
    //sends test data of an hour ago
    let hourAgo = currentTime - 3600;
    let hourAhead = currentTime + 3600;

    console.log(
        hoursSinceMerge
    );

    
    async function moveTime(hours: number, contract: any) {
        let seconds = hours * 3600;
        await time.increase(seconds);

        //resets time variables tests
        currentTime = Number(await contract.getTime())
        hoursSinceMerge = Math.floor((currentTime - mergeTime) /3600);
        hourAgo = currentTime - 3600;
        hourAhead = currentTime + 3600;

        console.log(
        hoursSinceMerge
        );
    }
    

    //fixture to deploy contract
    async function deployClocktowerFixture() {
        const Clocktower = await ethers.getContractFactory("Clocktower");
        const [owner, otherAccount] = await ethers.getSigners();

        const hardhatClocktower = await Clocktower.deploy();
        await hardhatClocktower.deployed();

        //creates several transaactions to test transaction list
        hardhatClocktower.addTransaction(otherAccount.address, hourAhead, ethers.utils.parseEther("4.0"));
        hardhatClocktower.addTransaction(otherAccount.address, hourAhead, ethers.utils.parseEther("4.0"));

        //starts contract with 100 ETH
        const params = {
            from: owner.address,
            to: hardhatClocktower.address,
            value: ethers.utils.parseEther("100.0")
        };
        await owner.sendTransaction(params);

        //moves time 2 hours
        await moveTime(2, hardhatClocktower);


        return { Clocktower, hardhatClocktower, owner, otherAccount } ;
    }

    //test sending ether
    describe("Sending Ether", function() {
        it("Should receive ether", async function() {
            const {hardhatClocktower, owner, otherAccount} = await loadFixture(deployClocktowerFixture);
            
            const params = {
                from: owner.address,
                to: hardhatClocktower.address,
                value: ethers.utils.parseEther("1.0")
            };

            await owner.sendTransaction(params);

            
            expect(
                await ethers.provider.getBalance(hardhatClocktower.address)
            ).to.greaterThanOrEqual(ethers.utils.parseEther("1.0"))
        })
    })

    
    //tests adding transaction
    describe("Transactions", function(){


        it("Should add transactions", async function(){
            const {hardhatClocktower, owner, otherAccount} = await loadFixture(deployClocktowerFixture);

            console.log(
                hoursSinceMerge
            );
        
            //Add transaction to contract
            await expect(
                hardhatClocktower.addTransaction(otherAccount.address, hourAhead , 40)
            ).to.emit(hardhatClocktower, "TransactionAdd")
            .withArgs(owner.address, otherAccount.address, (hoursSinceMerge + 1), 40);
        })
        it("Should output status", async function() {
            const {hardhatClocktower, owner, otherAccount} = await loadFixture(deployClocktowerFixture);
            //get status output
            await expect(
                hardhatClocktower.addTransaction(otherAccount.address, hourAhead, 40)
            ).to.emit(hardhatClocktower, "Status")
            .withArgs("Pushed");
        })
        
        
    })
    

    describe("Check Time", function(){
        it("Should output transactions", async function(){
            const {hardhatClocktower, owner, otherAccount} = await loadFixture(deployClocktowerFixture);
            await expect(
                hardhatClocktower.checkTime()
            ).to.emit(hardhatClocktower, "CheckStatus")
            .withArgs("done");
        })
         
        it("Should send transactions", async function(){
            const {hardhatClocktower, owner, otherAccount} = await loadFixture(deployClocktowerFixture);
            await expect(

                hardhatClocktower.checkTime()
            ).to.emit(hardhatClocktower, "TransactionSent")
            .withArgs(true);
        }) 
        it("Should send ether to addresses", async function() {
            const {hardhatClocktower, owner, otherAccount} = await loadFixture(deployClocktowerFixture);
            hardhatClocktower.checkTime();
            expect(
                await ethers.provider.getBalance(otherAccount.address)
            ).to.greaterThan(ethers.utils.parseEther("1007.0"))
        })
    })

    
    describe("Time Functions", function() {
        it("Should output hours", async function() {
            const {hardhatClocktower, owner, otherAccount} = await loadFixture(deployClocktowerFixture);

            expect(
                await hardhatClocktower.hoursSinceMerge(currentTime)
            )
        })
    })
    
    
    
    
})