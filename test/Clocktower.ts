import { loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { time } from "@nomicfoundation/hardhat-network-helpers";
//import { anyValue } from "@nomicfoundation/hardhat-chai-matchers/withArgs";
import { expect } from "chai";
import { ethers } from "hardhat";

//Written by Hugo Marx

describe("Clocktower", function(){

    //sends receive time in unix epoch seconds
    let millis = Date.now();
    let currentTime = Math.floor(millis / 1000);
    //hour merge occured
    let mergeTime = 1663264750;
    let hoursSinceMerge = Math.floor((currentTime - mergeTime) /3600);
    //eth sent
    let eth = ethers.utils.parseEther("1.0")

    //sends test data of an hour ago
    let hourAgo = currentTime - 3600;
    let hourAhead = currentTime + 3600;
    
    async function moveTime(hours: number, contract: any) {
        let seconds = hours * 3600;
        await time.increase(seconds);

        //resets time variables tests
        currentTime = Number(await contract.getTime())
        hoursSinceMerge = Math.floor((currentTime - mergeTime) /3600);
        hourAgo = currentTime - 3600;
        hourAhead = currentTime + 3600;
    }
    

    //fixture to deploy contract
    async function deployClocktowerFixture() {
        const Clocktower = await ethers.getContractFactory("Clocktower");
        const [owner, otherAccount] = await ethers.getSigners();

        const hardhatClocktower = await Clocktower.deploy();
        await hardhatClocktower.deployed();

        let params2 = {
            value: eth
        }

        //creates several transaactions to test transaction list
        hardhatClocktower.addTransaction(otherAccount.address, hourAhead, eth, params2);
        hardhatClocktower.addTransaction(otherAccount.address, hourAhead, eth, params2);

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
            ).to.greaterThanOrEqual(eth)
        })
    })

    
    //tests adding transaction
    describe("Transactions", function(){

        const testParams = {
            value: eth
        };

        it("Should add transactions", async function(){
            const {hardhatClocktower, owner, otherAccount} = await loadFixture(deployClocktowerFixture);

            //Add transaction to contract
            await expect(
                hardhatClocktower.addTransaction(otherAccount.address, hourAhead ,eth , testParams)
            ).to.emit(hardhatClocktower, "TransactionAdd")
            .withArgs(owner.address, otherAccount.address, (hoursSinceMerge + 1), eth);
        })
        it("Should output status", async function() {
            const {hardhatClocktower, owner, otherAccount} = await loadFixture(deployClocktowerFixture);
            //get status output
            await expect(
                hardhatClocktower.addTransaction(otherAccount.address, hourAhead, eth, testParams)
            ).to.emit(hardhatClocktower, "Status")
            .withArgs("Pushed");
        })
        it("Should send eth with the transaction", async function() {
            const {hardhatClocktower, owner, otherAccount} = await loadFixture(deployClocktowerFixture);
           
            await hardhatClocktower.addTransaction(otherAccount.address, hourAhead, eth, testParams)
            await expect(
                await ethers.provider.getBalance(hardhatClocktower.address)
            ).to.equals(ethers.utils.parseEther("103.0"))

        })
        
        it("Should Get Account", async function(){
            const {hardhatClocktower, owner, otherAccount} = await loadFixture(deployClocktowerFixture)
            

            hardhatClocktower.addTransaction(otherAccount.address, hourAhead, eth, testParams)
            expect(
                 (await hardhatClocktower.getAccount(owner.address)).accountAddress
            ).to.equal(owner.address)
        
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