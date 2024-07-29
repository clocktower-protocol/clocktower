//import { loadFixture, time } from "@nomicfoundation/hardhat-network-helpers";
import { loadFixture, time } from "@nomicfoundation/hardhat-toolbox/network-helpers";
//import { time } from "@nomicfoundation/hardhat-network-helpers";
import { expect } from "chai";
import hre from "hardhat"
//import { ethers } from "hardhat";
import { anyValue } from "@nomicfoundation/hardhat-chai-matchers/withArgs";
const { ethers } = require("hardhat");

//Written by Hugo Marx

describe("Clocktower", function(){

    //let currentTime = 1704088800;
    let currentTime = 1830319200
    let mergeTime = 0;
    //eth sent
    let eth = hre.ethers.parseEther("1.0")
    //console.log(eth)
    let centEth = hre.ethers.parseEther("100.0")

    //sends test data of an hour ago
    let hourAhead = currentTime + 3600;
    let twoHoursAhead = hourAhead + 3600;
    let dayAhead = 86400;


    //Infinite approval
    const infiniteApproval = BigInt(Math.pow(2,255))
    
    let byteArray = []
    //creates empty 32 byte array
    for(let i = 0; i < 32; i++) {
        byteArray[i] = 0x0
    }

    //fixture to deploy contract
    async function deployClocktowerFixture() {

        //sets time to 2028/01/01 1:00
        await time.increaseTo(currentTime);

        const ClockToken = await hre.ethers.getContractFactory("CLOCKToken");

        //const { clockSubscribe } = await hre.ignition.deploy(ClockSubscribe)
        //const ClockSubscribe = await hre.ethers.getContractFactory("contracts/ClockTowerSubscribe.sol:ClockTowerSubscribe", {})
        const ClockSubscribeFactory = await hre.ethers.getContractFactory("ClockTowerSubscribe")

        const [owner, otherAccount, subscriber, provider, caller] = await ethers.getSigners();

        const hardhatCLOCKToken = await ClockToken.deploy(hre.ethers.parseEther("100100"));
        const hardhatClockSubscribe = await ClockSubscribeFactory.deploy(10200n, 10000000000000000n, 5n, false, "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266");

        await hardhatCLOCKToken.waitForDeployment();
        await hardhatClockSubscribe.waitForDeployment();
      
        //funds other account with eth
        const paramsOther = {
            from: owner.address,
            to: otherAccount.address,
            value: centEth
        };
        await owner.sendTransaction(paramsOther)
        
        await hardhatCLOCKToken.approve(await hardhatClockSubscribe.getAddress(), infiniteApproval)
        await hardhatCLOCKToken.connect(otherAccount).approve(await hardhatClockSubscribe.getAddress(), infiniteApproval)
        await hardhatCLOCKToken.connect(subscriber).approve(await hardhatClockSubscribe.getAddress(), infiniteApproval)

        /*
        console.log("HERE")
        console.log(owner.address)
        console.log(otherAccount.address)
        console.log(subscriber.address)
        */
         //sends 100 clocktoken to other account
        await hardhatCLOCKToken.transfer(otherAccount.address, centEth)
        await hardhatCLOCKToken.transfer(subscriber.address, centEth)
        await hardhatCLOCKToken.transfer(provider.address, centEth)
        await hardhatCLOCKToken.transfer(caller.address, centEth)

        return {owner, otherAccount, subscriber, provider, caller, hardhatCLOCKToken, hardhatClockSubscribe} ;
    }
    describe("Subscriptions", function() {
        const testParams = {
            value: eth
        };

        const testParams2 = {
            value: hre.ethers.parseEther("0.001")
        }

        const details = {
            domain: "domain",
            url: "URL",
            email: "Email",
            phone: "phone",
            description: "description"
        }

        it("Should create a subscription", async function() {
           
            const {hardhatCLOCKToken, hardhatClockSubscribe, provider, caller} = await loadFixture(deployClocktowerFixture);
            
            //adds CLOCK to approved tokens
            await hardhatClockSubscribe.addERC20Contract(await hardhatCLOCKToken.getAddress(), hre.ethers.parseEther(".01"))
            
            //checks reverts

            //checks that too low an amount gets reverted
            await expect(hardhatClockSubscribe.connect(provider).createSubscription(hre.ethers.parseEther(".001"), await hardhatCLOCKToken.getAddress(), details ,1,15, testParams))
            .to.be.reverted

            await expect(hardhatClockSubscribe.connect(provider).createSubscription(eth, hre.ethers.ZeroAddress, details,1,15, testParams))
            .to.be.revertedWith("8")

            await hardhatClockSubscribe.systemFeeActivate(true);
            await expect(hardhatClockSubscribe.connect(provider).createSubscription(eth, await hardhatCLOCKToken.getAddress(), details,1,15, testParams2))
            .to.be.revertedWith("5")

            await expect(hardhatClockSubscribe.connect(provider).createSubscription(eth, caller.address, details,1,15, testParams))
            .to.be.revertedWith("9")

            await expect(hardhatClockSubscribe.connect(provider).createSubscription(eth, await hardhatCLOCKToken.getAddress(), details,0,15, testParams))
            .to.be.revertedWith("26")

            await expect(hardhatClockSubscribe.connect(provider).createSubscription(eth, await hardhatCLOCKToken.getAddress(), details,1,29, testParams))
            .to.be.revertedWith("27")

            await expect(hardhatClockSubscribe.connect(provider).createSubscription(eth, await hardhatCLOCKToken.getAddress(), details,2,91, testParams))
            .to.be.revertedWith("28")

            await expect(hardhatClockSubscribe.connect(provider).createSubscription(eth, await hardhatCLOCKToken.getAddress(), details,3,366, testParams))
            .to.be.revertedWith("29")

            await expect(hardhatClockSubscribe.connect(provider).createSubscription(hre.ethers.parseEther("0.001"), await hardhatCLOCKToken.getAddress(), details,1,15, testParams))
            .to.be.revertedWith("30")

            await expect(hardhatClockSubscribe.connect(provider).createSubscription(eth, await hardhatCLOCKToken.getAddress(), details,1,15, testParams))
            .to.emit(hardhatClockSubscribe, "SubLog").withArgs(anyValue, provider.address, anyValue, anyValue, eth, await hardhatCLOCKToken.getAddress(), 0)
        })

        it("Should get created subscriptions", async function() {
            const {hardhatCLOCKToken, hardhatClockSubscribe, provider} = await loadFixture(deployClocktowerFixture);
            
            //adds CLOCK to approved tokens
            await hardhatClockSubscribe.addERC20Contract(await hardhatCLOCKToken.getAddress(), hre.ethers.parseEther(".01"))

            await hardhatClockSubscribe.connect(provider).createSubscription(eth, await hardhatCLOCKToken.getAddress(), details ,1, 15, testParams)
            await hardhatClockSubscribe.connect(provider).createSubscription(eth, await hardhatCLOCKToken.getAddress(), details ,2, 15, testParams)
            let subscriptions = await hardhatClockSubscribe.connect(provider).getAccountSubscriptions(false, provider.address)

            //expect(subscriptions[1].subscription.description).to.equal("Test")
            expect(subscriptions[1].subscription.amount).to.equal(eth);
            expect(subscriptions[1].subscription.token).to.equal(await hardhatCLOCKToken.getAddress());
            expect(subscriptions[1].subscription.dueDay).to.equal(15);
        })
        
        it("Should allow user to subscribe", async function() {

            const testParams2 = {
                value: eth,
                gasLimit: 3000000
            };
    
            
            const {hardhatCLOCKToken, hardhatClockSubscribe, provider, subscriber, caller} = await loadFixture(deployClocktowerFixture);

            const clockTokenAddress = await hardhatCLOCKToken.getAddress()
            
            //adds CLOCK to approved tokens
            await hardhatClockSubscribe.addERC20Contract(clockTokenAddress, hre.ethers.parseEther(".01"))

            await hardhatClockSubscribe.connect(provider).createSubscription(eth, clockTokenAddress, details,1,15, testParams)
            await hardhatClockSubscribe.connect(provider).createSubscription(eth, clockTokenAddress, details,3,15, testParams)

            const subscriptions = await hardhatClockSubscribe.connect(provider).getAccountSubscriptions(false, provider.address)

            //checks reverts

            //creates subscribe object
            
            const subscribeObject = {
                id: subscriptions[1].subscription[0],
                amount: subscriptions[1].subscription[1],
                provider: subscriptions[1].subscription[2],
                token: subscriptions[1].subscription[3],
                exists: subscriptions[1].subscription[4],
                cancelled: subscriptions[1].subscription[5],
                frequency: subscriptions[1].subscription[6],
                dueDay: subscriptions[1].subscription[7]
            }
            
            
            //checks bad balance
            await hardhatCLOCKToken.connect(subscriber).transfer(caller.address, hre.ethers.parseEther("100"))
            await expect(hardhatClockSubscribe.connect(subscriber).subscribe(subscribeObject, testParams2))
            .to.be.revertedWith("20")
            await hardhatCLOCKToken.connect(caller).transfer(subscriber.address, hre.ethers.parseEther("100"))
            
            
            //checks input of fake subscription
            let fakeSub = {id: subscribeObject.id, amount: 5, provider: caller.address, token: clockTokenAddress, exists: true, cancelled: false, frequency: 0, dueDay: 2}
        
            await expect(hardhatClockSubscribe.connect(subscriber).subscribe(fakeSub, testParams2))
            .to.be.rejectedWith("7")
            
            
            //FIXME:
            
            /*
            const tx = await hardhatClockSubscribe.connect(subscriber).subscribe(subscribeObject, testParams2)
            await expect(tx).to.emit(hardhatClockSubscribe, "SubLog").withArgs(anyValue, subscriber.provider, subscriber.address, anyValue, eth, await hardhatCLOCKToken.getAddress(), 6)
            await expect(tx).to.emit(hardhatClockSubscribe, "SubLog").withArgs(anyValue, subscriber.provider, subscriber.address, anyValue, eth, await hardhatCLOCKToken.getAddress(), 8)
            await expect(tx).to.changeTokenBalance(hardhatCLOCKToken, await hardhatClockSubscribe.getAddress(), "83333333333333333")
            await expect(tx).to.changeTokenBalance(hardhatCLOCKToken, provider, "35159817351598170")
            */
        })
        it("Should allow user to unsubscribe", async function() {
            const {hardhatCLOCKToken, hardhatClockSubscribe, provider, subscriber, caller} = await loadFixture(deployClocktowerFixture);

            const clockTokenAddress = await hardhatCLOCKToken.getAddress()
            
            //adds CLOCK to approved tokens
            await hardhatClockSubscribe.addERC20Contract(clockTokenAddress, hre.ethers.parseEther(".01"))
           
            await hardhatClockSubscribe.connect(provider).createSubscription(eth, clockTokenAddress, details,1,15, testParams)
            await hardhatClockSubscribe.connect(provider).createSubscription(eth, clockTokenAddress, details,2,15, testParams)

            let subscriptions = await hardhatClockSubscribe.connect(provider).getAccountSubscriptions(false, provider.address);

             //creates subscribe object
             const subscribeObject = {
                id: subscriptions[1].subscription[0],
                amount: subscriptions[1].subscription[1],
                provider: subscriptions[1].subscription[2],
                token: subscriptions[1].subscription[3],
                exists: subscriptions[1].subscription[4],
                cancelled: subscriptions[1].subscription[5],
                frequency: subscriptions[1].subscription[6],
                dueDay: subscriptions[1].subscription[7]
            }

            await hardhatClockSubscribe.connect(subscriber).subscribe(subscribeObject, testParams)

            //check emits and balances
            await expect(hardhatClockSubscribe.connect(subscriber).unsubscribe(subscribeObject, testParams))
            .to.emit(hardhatClockSubscribe, "SubLog").withArgs(anyValue, subscribeObject.provider, subscriber.address, anyValue, eth, clockTokenAddress, 7)
            
            await hardhatClockSubscribe.connect(subscriber).subscribe(subscribeObject, testParams)

            await expect(hardhatClockSubscribe.connect(subscriber).unsubscribe(subscribeObject, testParams))
            .to.changeTokenBalance(hardhatCLOCKToken, provider, "51851851851851851")

            let result = await hardhatClockSubscribe.connect(subscriber).getAccountSubscriptions(true, subscriber.address)
            
            expect(result[0].status).to.equal(2)
           
            //checks second emit
            await hardhatClockSubscribe.connect(subscriber).subscribe(subscribeObject, testParams)

            await expect(hardhatClockSubscribe.connect(subscriber).unsubscribe(subscribeObject, testParams))
            .to.emit(hardhatClockSubscribe, "SubLog").withArgs(anyValue, provider.address, subscriber.address, anyValue, "51851851851851851", clockTokenAddress, 4)
        })
        it("Should allow provider to unsubscribe sub", async function() {
            const {hardhatCLOCKToken, hardhatClockSubscribe, provider, subscriber, caller} = await loadFixture(deployClocktowerFixture);

            const clockTokenAddress = await hardhatCLOCKToken.getAddress()
            
            //adds CLOCK to approved tokens
            await hardhatClockSubscribe.addERC20Contract(clockTokenAddress, hre.ethers.parseEther(".01"))

            await hardhatClockSubscribe.connect(provider).createSubscription(eth, clockTokenAddress, details,1,1, testParams)

            let subscriptions = await hardhatClockSubscribe.connect(provider).getAccountSubscriptions(false, provider.address);

             //creates subscribe object
             const subscribeObject = {
                id: subscriptions[0].subscription[0],
                amount: subscriptions[0].subscription[1],
                provider: subscriptions[0].subscription[2],
                token: subscriptions[0].subscription[3],
                exists: subscriptions[0].subscription[4],
                cancelled: subscriptions[0].subscription[5],
                frequency: subscriptions[0].subscription[6],
                dueDay: subscriptions[0].subscription[7]
            }

            await hardhatClockSubscribe.connect(subscriber).subscribe(subscribeObject, testParams)
    
            //checks reverts

            //checks if user is in fact the provider
            await expect(hardhatClockSubscribe.connect(caller).unsubscribeByProvider(subscribeObject, subscriber.address))
            .to.be.revertedWith("18")
            //checks if subscriber is subscribed to subscription
            await expect(hardhatClockSubscribe.connect(provider).unsubscribeByProvider(subscribeObject, caller.address))
            .to.be.revertedWith("19")
            //checks first emit and token balance
            await expect(hardhatClockSubscribe.connect(provider).unsubscribeByProvider(subscribeObject, subscriber.address))
            .to.emit(hardhatClockSubscribe, "SubLog").withArgs(anyValue, subscribeObject.provider, subscriber.address, anyValue, subscriptions[0].subscription.amount, clockTokenAddress, 7)
            //.to.emit(hardhatClockSubscribe, "SubscriberLog").withArgs(anyValue, subscriber.address, subscriptions[0].subscription.provider, anyValue,subscriptions[0].subscription.amount, hardhatCLOCKToken.address, 3)
            //.to.changeTokenBalance(hardhatCLOCKToken, subscriber, hre.ethers.parseEther("1"))
            //checks second emit
            await hardhatClockSubscribe.connect(subscriber).subscribe(subscribeObject, testParams)
            await expect(hardhatClockSubscribe.connect(provider).unsubscribeByProvider(subscribeObject, subscriber.address))
            .to.emit(hardhatClockSubscribe, "SubLog").withArgs(anyValue, subscribeObject.provider, subscriber.address, anyValue, "1000000000000000000", clockTokenAddress, 7)
            //checks token balance change
            await hardhatClockSubscribe.connect(subscriber).subscribe(subscribeObject, testParams)
            await expect(hardhatClockSubscribe.connect(provider).unsubscribeByProvider(subscribeObject, subscriber.address))
            .to.changeTokenBalance(hardhatCLOCKToken, subscriber, hre.ethers.parseEther("1"))

        })
        it("Should cancel subscription", async function(){
            const {hardhatCLOCKToken, hardhatClockSubscribe, provider, subscriber, caller} = await loadFixture(deployClocktowerFixture);

            const clockTokenAddress = await hardhatCLOCKToken.getAddress()
            
            //adds CLOCK to approved tokens
            await hardhatClockSubscribe.addERC20Contract(clockTokenAddress, hre.ethers.parseEther(".01"))

            await hardhatClockSubscribe.connect(provider).createSubscription(eth, clockTokenAddress, details,1,15, testParams)
            await hardhatClockSubscribe.connect(provider).createSubscription(eth, clockTokenAddress, details,2,15, testParams)

            let subscriptions = await hardhatClockSubscribe.connect(provider).getAccountSubscriptions(false, provider.address);

             //creates subscribe object
             const subscribeObject = {
                id: subscriptions[1].subscription[0],
                amount: subscriptions[1].subscription[1],
                provider: subscriptions[1].subscription[2],
                token: subscriptions[1].subscription[3],
                exists: subscriptions[1].subscription[4],
                cancelled: subscriptions[1].subscription[5],
                frequency: subscriptions[1].subscription[6],
                dueDay: subscriptions[1].subscription[7]
            }

            await hardhatClockSubscribe.connect(subscriber).subscribe(subscribeObject, testParams)
    
            //checks reverts

            //checks input of fake subscription
            let fakeSub = {id: subscribeObject.id, amount: 5, provider: caller.address, token: clockTokenAddress, exists: true, cancelled: false, frequency: 0, dueDay: 2}
            await expect(hardhatClockSubscribe.connect(provider).cancelSubscription(fakeSub))
            .to.be.rejectedWith("7")

            await expect(hardhatClockSubscribe.connect(subscriber).cancelSubscription(subscribeObject))
            .to.be.rejectedWith("23")

            //checks balances and emits

            await expect(hardhatClockSubscribe.connect(provider).cancelSubscription(subscribeObject))
            //.to.changeTokenBalance(hardhatCLOCKToken, subscriber, "51851851851851851")
            .to.emit(hardhatClockSubscribe, "SubLog").withArgs(anyValue, subscribeObject.provider, subscriber.address, anyValue, "51851851851851851", clockTokenAddress, 9)

            //checks token balance
            await hardhatClockSubscribe.connect(subscriber).subscribe(subscribeObject, testParams)
            await expect(hardhatClockSubscribe.connect(provider).cancelSubscription(subscribeObject))
            .to.changeTokenBalance(hardhatCLOCKToken, subscriber, "51851851851851851")

            await hardhatClockSubscribe.connect(subscriber).subscribe(subscribeObject, testParams)

            await expect(hardhatClockSubscribe.connect(provider).cancelSubscription(subscribeObject))
            .to.emit(hardhatClockSubscribe, "SubLog").withArgs(anyValue, provider.address, anyValue, anyValue, 0, clockTokenAddress, 1)

            let result = await hardhatClockSubscribe.connect(subscriber).getAccountSubscriptions(true, subscriber.address)

            expect(result[0].status).to.equal(1);
            expect(result[0].subscription.cancelled).to.equal(true)
        })
        it("Should paginate remit transactions", async function(){
            const {hardhatCLOCKToken, hardhatClockSubscribe, owner, provider, subscriber, caller} = await loadFixture(deployClocktowerFixture);
            
            let remits = 5

            //sets remits to 5
            expect(await hardhatClockSubscribe.changeMaxRemits(remits))

            //allows external callers
            await hardhatClockSubscribe.setExternalCallers(true)

            //adds CLOCK to approved tokens
            await hardhatClockSubscribe.addERC20Contract(await hardhatCLOCKToken.getAddress(), hre.ethers.parseEther(".01"))

            await hardhatClockSubscribe.connect(provider).createSubscription(eth, await hardhatCLOCKToken.getAddress(), details,1,1, testParams)
            await hardhatClockSubscribe.connect(provider).createSubscription(eth, await hardhatCLOCKToken.getAddress(), details,1,1, testParams)
            await hardhatClockSubscribe.connect(provider).createSubscription(eth, await hardhatCLOCKToken.getAddress(), details,1,1, testParams)
            await hardhatClockSubscribe.connect(provider).createSubscription(eth, await hardhatCLOCKToken.getAddress(), details,1,1, testParams)
            await hardhatClockSubscribe.connect(provider).createSubscription(eth, await hardhatCLOCKToken.getAddress(), details,1,1, testParams)
            await hardhatClockSubscribe.connect(provider).createSubscription(eth, await hardhatCLOCKToken.getAddress(), details,1,1, testParams)
            await hardhatClockSubscribe.connect(provider).createSubscription(eth, await hardhatCLOCKToken.getAddress(), details,1,1, testParams)

            let subscriptions = await hardhatClockSubscribe.connect(provider).getAccountSubscriptions(false, provider.address);

            //loop that creates subscription objects from returned arrays

            let subArray =[]
            //subscriptions
            for (let i = 0; i < subscriptions.length; i++) {
                subArray.push({
                    id: subscriptions[i].subscription[0],
                    amount: subscriptions[i].subscription[1],
                    provider: subscriptions[i].subscription[2],
                    token: subscriptions[i].subscription[3],
                    exists: subscriptions[i].subscription[4],
                    cancelled: subscriptions[i].subscription[5],
                    frequency: subscriptions[i].subscription[6],
                    dueDay: subscriptions[i].subscription[7]
                })
            }

            await hardhatClockSubscribe.connect(subscriber).subscribe(subArray[0], testParams)
            await hardhatClockSubscribe.connect(subscriber).subscribe(subArray[1], testParams)
            await hardhatClockSubscribe.connect(subscriber).subscribe(subArray[2], testParams)
            await hardhatClockSubscribe.connect(subscriber).subscribe(subArray[3], testParams)
            await hardhatClockSubscribe.connect(subscriber).subscribe(subArray[4], testParams)
            await hardhatClockSubscribe.connect(subscriber).subscribe(subArray[5], testParams)
            await hardhatClockSubscribe.connect(subscriber).subscribe(subArray[6], testParams)
            
            await time.increaseTo(twoHoursAhead);

            let subscribersId = await hardhatClockSubscribe.getSubscribersById(subArray[0].id)

            expect(subscribersId[0].subscriber).to.equal("0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC")
            expect(hre.ethers.formatEther(subscribersId[0].feeBalance)).to.equal("1.0")

            let isFinished = false
            let pageCounter = 0

            /*
            //loops through remit calls to test max remit
            while(!isFinished) {
                //gets emit
                let tx = await hardhatClockSubscribe.connect(caller).remit();
                let rc = await tx.wait();
                let event = rc.events?.find(event => event.event === 'CallerLog')
                let args = event?.args
                isFinished = args?.isFinished;

                pageCounter++

                console.log(isFinished)
            }
            */
            await hardhatClockSubscribe.connect(caller).remit();
            await hardhatClockSubscribe.connect(caller).remit();
        

            let otherBalance = await hardhatCLOCKToken.balanceOf(subscriber.address)

            let expected = hre.ethers.parseEther("86.0");

            //gets fee balance
            expect(hre.ethers.formatEther(await hardhatClockSubscribe.feeBalance(subArray[0].id,subscriber.address))).to.equal("0.98")

            expect(otherBalance).to.equal(expected)
            
        })
        it("Should emit SubscriberLog", async function(){
            const {hardhatCLOCKToken, hardhatClockSubscribe, provider, subscriber} = await loadFixture(deployClocktowerFixture);
            //adds CLOCK to approved tokens
            await hardhatClockSubscribe.addERC20Contract(await hardhatCLOCKToken.getAddress(), hre.ethers.parseEther(".01"))
            
            //creates subscription and subscribes
            await hardhatClockSubscribe.connect(provider).createSubscription(eth, await hardhatCLOCKToken.getAddress(), details,1,1, testParams)
            
            let subscriptions = await hardhatClockSubscribe.connect(provider).getAccountSubscriptions(false, provider.address);

             //creates subscribe object
             const subscribeObject = {
                id: subscriptions[0].subscription[0],
                amount: subscriptions[0].subscription[1],
                provider: subscriptions[0].subscription[2],
                token: subscriptions[0].subscription[3],
                exists: subscriptions[0].subscription[4],
                cancelled: subscriptions[0].subscription[5],
                frequency: subscriptions[0].subscription[6],
                dueDay: subscriptions[0].subscription[7]
            }
            
            //checks that event emits subscribe and feefill
            await expect(hardhatClockSubscribe.connect(subscriber).subscribe(subscribeObject, testParams))
            .to.emit(hardhatClockSubscribe, "SubLog").withArgs(anyValue, anyValue, anyValue, anyValue, anyValue, await hardhatCLOCKToken.getAddress(), 6)

            await expect(hardhatClockSubscribe.connect(subscriber).subscribe(subscribeObject, testParams))
            .to.emit(hardhatClockSubscribe, "SubLog").withArgs(anyValue, anyValue, anyValue, anyValue, anyValue, await hardhatCLOCKToken.getAddress(), 8)
        })
        it("Should allow external callers", async function() {
            const {hardhatCLOCKToken, hardhatClockSubscribe, provider, subscriber, caller} = await loadFixture(deployClocktowerFixture);
            //adds CLOCK to approved tokens
            await hardhatClockSubscribe.addERC20Contract(await hardhatCLOCKToken.getAddress(), hre.ethers.parseEther(".01"))
           
            //creates subscription and subscribes
            await hardhatClockSubscribe.connect(provider).createSubscription(eth, await hardhatCLOCKToken.getAddress(), details,1,1, testParams)
            
            let subscriptions = await hardhatClockSubscribe.connect(provider).getAccountSubscriptions(false, provider.address);

              //creates subscribe object
              const subscribeObject = {
                id: subscriptions[0].subscription[0],
                amount: subscriptions[0].subscription[1],
                provider: subscriptions[0].subscription[2],
                token: subscriptions[0].subscription[3],
                exists: subscriptions[0].subscription[4],
                cancelled: subscriptions[0].subscription[5],
                frequency: subscriptions[0].subscription[6],
                dueDay: subscriptions[0].subscription[7]
            }
             
            await hardhatClockSubscribe.connect(subscriber).subscribe(subscribeObject, testParams)

            //sets external callers
            await hardhatClockSubscribe.setExternalCallers(true)

            expect(await hardhatClockSubscribe.connect(caller).remit())
        })
        it("Should predict fees", async function() {
            const {hardhatCLOCKToken, hardhatClockSubscribe, provider, subscriber} = await loadFixture(deployClocktowerFixture);
            //adds CLOCK to approved tokens
            await hardhatClockSubscribe.addERC20Contract(await hardhatCLOCKToken.getAddress(), hre.ethers.parseEther(".01"))
            
            //creates subscription and subscribes
            await hardhatClockSubscribe.connect(provider).createSubscription(eth, await hardhatCLOCKToken.getAddress(), details,1,1, testParams)
            
            //let subscriptions = await hardhatClockSubscribe.getAccountSubscriptions(false)
            let subscriptions = await hardhatClockSubscribe.connect(provider).getAccountSubscriptions(false, provider.address);

              //creates subscribe object
              const subscribeObject = {
                id: subscriptions[0].subscription[0],
                amount: subscriptions[0].subscription[1],
                provider: subscriptions[0].subscription[2],
                token: subscriptions[0].subscription[3],
                exists: subscriptions[0].subscription[4],
                cancelled: subscriptions[0].subscription[5],
                frequency: subscriptions[0].subscription[6],
                dueDay: subscriptions[0].subscription[7]
            }
            
            await hardhatClockSubscribe.connect(subscriber).subscribe(subscribeObject, testParams)

            //moves time
            await time.increaseTo(twoHoursAhead);

            
            //gets fee estimate
            let feeArray = await hardhatClockSubscribe.feeEstimate();

            expect(feeArray.length).to.equal(1)
            expect(Number(hre.ethers.formatEther(feeArray[0].fee))).to.equal(0.02)
            expect(feeArray[0].token).to.equal(await hardhatCLOCKToken.getAddress())
            
            
        })
        it("Should collect system fees", async function() {
            const {hardhatCLOCKToken, hardhatClockSubscribe, owner, provider} = await loadFixture(deployClocktowerFixture);

            const testParams = {
                value: hre.ethers.parseEther("0.011")
            };

            //adds CLOCK to approved tokens
            await hardhatClockSubscribe.addERC20Contract(await hardhatCLOCKToken.getAddress(), hre.ethers.parseEther(".01"))
            //turns on system fee collection
            await hardhatClockSubscribe.systemFeeActivate(true)

            //creates subscription and subscribes
            await hardhatClockSubscribe.connect(provider).createSubscription(eth, await hardhatCLOCKToken.getAddress(), details,1,1, testParams)

            let ownerBalance1 = hre.ethers.formatEther(await owner.provider.getBalance(owner.address))

            //collect fees
            await hardhatClockSubscribe.collectFees()

            let ownerBalance2 = hre.ethers.formatEther(await owner.provider.getBalance(owner.address))

            expect(Number(ownerBalance2) - Number(ownerBalance1)).to.greaterThan(0.01)

        })
        it("Should refund provider on fail", async function() {
            
            const {hardhatCLOCKToken, hardhatClockSubscribe, subscriber, caller, provider} = await loadFixture(deployClocktowerFixture);

            const clockTokenAddress = await hardhatCLOCKToken.getAddress()

            const testParams = {
                value: eth
            };
            
            //adds CLOCK to approved tokens
            await hardhatClockSubscribe.addERC20Contract(clockTokenAddress, hre.ethers.parseEther(".01"))

            //creates subscription and subscribes
            await hardhatClockSubscribe.connect(provider).createSubscription(eth, clockTokenAddress, details,1,1, testParams)
            
            let subscriptions = await hardhatClockSubscribe.connect(provider).getAccountSubscriptions(false, provider.address);

            //creates subscribe object
            const subscribeObject = {
                id: subscriptions[0].subscription[0],
                amount: subscriptions[0].subscription[1],
                provider: subscriptions[0].subscription[2],
                token: subscriptions[0].subscription[3],
                exists: subscriptions[0].subscription[4],
                cancelled: subscriptions[0].subscription[5],
                frequency: subscriptions[0].subscription[6],
                dueDay: subscriptions[0].subscription[7]
            }

            await hardhatClockSubscribe.connect(subscriber).subscribe(subscribeObject, testParams)

            //otherAccount stops approval
            await hardhatCLOCKToken.connect(subscriber).approve(await hardhatClockSubscribe.getAddress(), 0)

            let subAmount = await hardhatCLOCKToken.balanceOf(subscriber.address)

            await hardhatClockSubscribe.setExternalCallers(true)

            expect(await hardhatClockSubscribe.connect(caller).remit())
            .to.emit(hardhatClockSubscribe, "SubLog").withArgs(subscribeObject.id, subscribeObject.provider, subscriber.address, anyValue, subscribeObject.amount, clockTokenAddress, 7)

            //check that provider has been refunded
            let provAmount = await hardhatCLOCKToken.balanceOf(provider.address)

            //checks caller
            let callerAmount = await hardhatCLOCKToken.balanceOf(caller.address)

            expect(hre.ethers.formatEther(subAmount)).to.equal("99.0")
            expect(hre.ethers.formatEther(provAmount)).to.equal("100.98")    
            expect(hre.ethers.formatEther(callerAmount)).to.equal("100.02")  
            
            await hardhatClockSubscribe.connect(provider).createSubscription(eth, clockTokenAddress, details,1,2, testParams)
            let subscriptions2 = await hardhatClockSubscribe.connect(provider).getAccountSubscriptions(false, provider.address);

              //creates subscribe object
              const subscribeObject2 = {
                id: subscriptions2[1].subscription[0],
                amount: subscriptions2[1].subscription[1],
                provider: subscriptions2[1].subscription[2],
                token: subscriptions2[1].subscription[3],
                exists: subscriptions2[1].subscription[4],
                cancelled: subscriptions2[1].subscription[5],
                frequency: subscriptions2[1].subscription[6],
                dueDay: subscriptions2[1].subscription[7]
            }

            await time.increase(dayAhead)

            await hardhatCLOCKToken.connect(subscriber).approve(await hardhatClockSubscribe.getAddress(), hre.ethers.parseEther("100"))
            await hardhatClockSubscribe.connect(subscriber).subscribe(subscribeObject2, testParams)
            await hardhatCLOCKToken.connect(subscriber).approve(await hardhatClockSubscribe.getAddress(), 0)
            expect(await hardhatClockSubscribe.connect(caller).remit())
            .to.emit(hardhatClockSubscribe, "SubLog").withArgs(subscribeObject2.id, subscribeObject2.provider, subscriber.address, anyValue, subscribeObject.amount, clockTokenAddress, 3)

            await hardhatClockSubscribe.connect(provider).createSubscription(eth, await hardhatCLOCKToken.getAddress(), details,1,3, testParams)
            let subscriptions3 = await hardhatClockSubscribe.connect(provider).getAccountSubscriptions(false, provider.address);

             //creates subscribe object
             const subscribeObject3 = {
                id: subscriptions3[2].subscription[0],
                amount: subscriptions3[2].subscription[1],
                provider: subscriptions3[2].subscription[2],
                token: subscriptions3[2].subscription[3],
                exists: subscriptions3[2].subscription[4],
                cancelled: subscriptions3[2].subscription[5],
                frequency: subscriptions3[2].subscription[6],
                dueDay: subscriptions3[2].subscription[7]
            }

            await time.increase(dayAhead)

            await hardhatCLOCKToken.connect(subscriber).approve(await hardhatClockSubscribe.getAddress(), hre.ethers.parseEther("100"))
            await hardhatClockSubscribe.connect(subscriber).subscribe(subscribeObject3, testParams)
            await hardhatCLOCKToken.connect(subscriber).approve(await hardhatClockSubscribe.getAddress(), 0)
            expect(await hardhatClockSubscribe.connect(caller).remit())
            .to.emit(hardhatClockSubscribe, "SubLog").withArgs(subscribeObject3.id, provider.address, subscriber.address, anyValue, 0, clockTokenAddress, 3)

        })
        it("Should add and remove ERC20 Tokens", async function() {
            const {hardhatCLOCKToken, hardhatClockSubscribe, subscriber, caller, provider} = await loadFixture(deployClocktowerFixture);

            //adds CLOCK to approved tokens
            expect(await hardhatClockSubscribe.addERC20Contract(await hardhatCLOCKToken.getAddress(), hre.ethers.parseEther(".01")))
        })
        it("Should remit transactions PART 1", async function() {
            const {hardhatCLOCKToken, hardhatClockSubscribe, subscriber, caller, provider} = await loadFixture(deployClocktowerFixture);

            const clockTokenAddress = await hardhatCLOCKToken.getAddress()

            //adds CLOCK to approved tokens
            await hardhatClockSubscribe.addERC20Contract(clockTokenAddress, hre.ethers.parseEther(".01"))

            //creates subscription and subscribes
            await hardhatClockSubscribe.connect(provider).createSubscription(eth, clockTokenAddress, details,1,1, testParams)
             
            let subscriptions = await hardhatClockSubscribe.connect(provider).getAccountSubscriptions(false, provider.address);

             //creates subscribe object
             const subscribeObject = {
                id: subscriptions[0].subscription[0],
                amount: subscriptions[0].subscription[1],
                provider: subscriptions[0].subscription[2],
                token: subscriptions[0].subscription[3],
                exists: subscriptions[0].subscription[4],
                cancelled: subscriptions[0].subscription[5],
                frequency: subscriptions[0].subscription[6],
                dueDay: subscriptions[0].subscription[7]
            }

            await hardhatClockSubscribe.connect(subscriber).subscribe(subscribeObject, testParams)

            //checks that only admin can call if bool is set
            await expect(hardhatClockSubscribe.connect(caller).remit())
            .to.be.rejectedWith("16")

            await hardhatClockSubscribe.setExternalCallers(true)
            await hardhatClockSubscribe.systemFeeActivate(true)

            //checks token fee is high enough
            await expect(hardhatClockSubscribe.connect(caller).remit())
            .to.be.rejectedWith("5")

            await hardhatClockSubscribe.systemFeeActivate(false)

            //checks remit can't be called twice in same day
            await hardhatClockSubscribe.connect(caller).remit()
            await expect(hardhatClockSubscribe.connect(caller).remit())
            .to.be.rejectedWith("14")

            //moves to next day and sets 5 new subscriptions
            await time.increase(dayAhead)
            await hardhatClockSubscribe.connect(provider).createSubscription(eth, clockTokenAddress, details,1,2, testParams)
            await hardhatClockSubscribe.connect(provider).createSubscription(eth, clockTokenAddress, details,1,2, testParams)
            await hardhatClockSubscribe.connect(provider).createSubscription(eth, clockTokenAddress, details,1,2, testParams)
            await hardhatClockSubscribe.connect(provider).createSubscription(eth, clockTokenAddress, details,1,2, testParams)
            await hardhatClockSubscribe.connect(provider).createSubscription(eth, clockTokenAddress, details,1,2, testParams)
            let subscriptions2 = await hardhatClockSubscribe.connect(provider).getAccountSubscriptions(false, provider.address);
            //loop to create subscribe objects
            let subArray2 = []
            //subscriptions
            for (let i = 0; i < 6; i++) {
                subArray2.push({
                    id: subscriptions2[i].subscription[0],
                    amount: subscriptions2[i].subscription[1],
                    provider: subscriptions2[i].subscription[2],
                    token: subscriptions2[i].subscription[3],
                    exists: subscriptions2[i].subscription[4],
                    cancelled: subscriptions2[i].subscription[5],
                    frequency: subscriptions2[i].subscription[6],
                    dueDay: subscriptions2[i].subscription[7]
                })
            }
            await hardhatClockSubscribe.connect(subscriber).subscribe(subArray2[1], testParams)
            await hardhatClockSubscribe.connect(subscriber).subscribe(subArray2[2], testParams)
            await hardhatClockSubscribe.connect(subscriber).subscribe(subArray2[3], testParams)
            await hardhatClockSubscribe.connect(subscriber).subscribe(subArray2[4], testParams)
            await hardhatClockSubscribe.connect(subscriber).subscribe(subArray2[5], testParams)

            //checks that on max remit caller is paid and event is emitted
            const tx = await hardhatClockSubscribe.connect(caller).remit()
            await expect(tx).to.changeTokenBalance(hardhatCLOCKToken, caller, hre.ethers.parseEther("0.1"))
            await expect(tx).to.emit(hardhatClockSubscribe, "CallerLog").withArgs(anyValue, 21185, caller.address, true)

            //checks that successful transfer with enough fee balance
            time.increase((dayAhead))
            await hardhatClockSubscribe.connect(provider).createSubscription(eth, clockTokenAddress, details,1,3, testParams)
            let subscriptions3 = await hardhatClockSubscribe.connect(provider).getAccountSubscriptions(false, provider.address);
            const subscribeObject3 = {
                id: subscriptions3[6].subscription[0],
                amount: subscriptions3[6].subscription[1],
                provider: subscriptions3[6].subscription[2],
                token: subscriptions3[6].subscription[3],
                exists: subscriptions3[6].subscription[4],
                cancelled: subscriptions3[6].subscription[5],
                frequency: subscriptions3[6].subscription[6],
                dueDay: subscriptions3[6].subscription[7]
            }

            await hardhatClockSubscribe.connect(subscriber).subscribe(subscribeObject3, testParams)
            
            const tx2 = await hardhatClockSubscribe.connect(caller).remit()
            await expect(tx2).to.changeTokenBalance(hardhatCLOCKToken, provider, hre.ethers.parseEther("1"))
            await expect(tx2).to.emit(hardhatClockSubscribe, "SubLog").withArgs(subscribeObject3.id, subscribeObject3.provider, subscriber.address, anyValue, subscribeObject3.amount, clockTokenAddress, 5)

            time.increase((dayAhead))
            await hardhatClockSubscribe.connect(provider).createSubscription(eth, clockTokenAddress, details,1,4, testParams)
            let subscriptions4 = await hardhatClockSubscribe.connect(provider).getAccountSubscriptions(false, provider.address);
            const subscribeObject4 = {
                id: subscriptions4[7].subscription[0],
                amount: subscriptions4[7].subscription[1],
                provider: subscriptions4[7].subscription[2],
                token: subscriptions4[7].subscription[3],
                exists: subscriptions4[7].subscription[4],
                cancelled: subscriptions4[7].subscription[5],
                frequency: subscriptions4[7].subscription[6],
                dueDay: subscriptions4[7].subscription[7]
            }
            await hardhatClockSubscribe.connect(subscriber).subscribe(subscribeObject4, testParams)
            
            await expect(hardhatClockSubscribe.connect(caller).remit())
            .to.emit(hardhatClockSubscribe, "SubLog").withArgs(anyValue, provider.address, subscriber.address, anyValue, 0, clockTokenAddress, 2)
        })  
        it("Should remit transactions PART 2", async function() {

            const {hardhatCLOCKToken, hardhatClockSubscribe, subscriber, caller, provider} = await loadFixture(deployClocktowerFixture);

            const clockTokenAddress = await hardhatCLOCKToken.getAddress()
            const clockSubsribeAddress = await hardhatClockSubscribe.getAddress()

            //adds CLOCK to approved tokens
            await hardhatClockSubscribe.addERC20Contract(clockTokenAddress, hre.ethers.parseEther(".01"))
            await hardhatClockSubscribe.changeCallerFee(13000)
            await hardhatClockSubscribe.setExternalCallers(true)

            //checks feefill events and token balances

            //checks subscriptions 90 days apart with depleted feeBalance

            await hardhatClockSubscribe.connect(provider).createSubscription(hre.ethers.parseEther("3"), clockTokenAddress, details,2,1, testParams)
             
            let subscriptions = await hardhatClockSubscribe.connect(provider).getAccountSubscriptions(false, provider.address);

            const subscribeObject = {
                id: subscriptions[0].subscription[0],
                amount: subscriptions[0].subscription[1],
                provider: subscriptions[0].subscription[2],
                token: subscriptions[0].subscription[3],
                exists: subscriptions[0].subscription[4],
                cancelled: subscriptions[0].subscription[5],
                frequency: subscriptions[0].subscription[6],
                dueDay: subscriptions[0].subscription[7]
            }

            await hardhatClockSubscribe.connect(subscriber).subscribe(subscribeObject, testParams)
            
            expect(hre.ethers.formatEther(await hardhatCLOCKToken.balanceOf(subscriber.address))).to.equal("97.0")
            expect(hre.ethers.formatEther(await hardhatCLOCKToken.balanceOf(provider.address))).to.equal("102.0")
            expect(hre.ethers.formatEther(await hardhatCLOCKToken.balanceOf(caller.address))).to.equal("100.0")
            expect(hre.ethers.formatEther(await hardhatCLOCKToken.balanceOf(clockSubsribeAddress))).to.equal("1.0")

            expect(await hardhatClockSubscribe.connect(caller).remit())

            expect(hre.ethers.formatEther(await hardhatCLOCKToken.balanceOf(subscriber.address))).to.equal("94.0")
            expect(hre.ethers.formatEther(await hardhatCLOCKToken.balanceOf(provider.address))).to.equal("105.0")
            expect(hre.ethers.formatEther(await hardhatCLOCKToken.balanceOf(caller.address))).to.equal("100.9")
            expect(hre.ethers.formatEther(await hardhatCLOCKToken.balanceOf(clockSubsribeAddress))).to.equal("0.1")
            
            await time.increase((dayAhead * 95))

            /*
            await expect(hardhatClockSubscribe.connect(caller).remit())
            .to.changeTokenBalance(hardhatCLOCKToken, provider, hre.ethers.parseEther("2"))
            .to.emit(hardhatClockSubscribe, "SubLog").withArgs(subscriptions[0].subscription.id, subscriptions[0].subscription.provider, subscriber.address, anyValue, subscriptions[0].subscription.amount, clockTokenAddress, 8)
            */
            const tx = await hardhatClockSubscribe.connect(caller).remit()
            await expect(tx).to.changeTokenBalance(hardhatCLOCKToken, provider, hre.ethers.parseEther("2"))
            await expect(tx).to.emit(hardhatClockSubscribe, "SubLog").withArgs(subscribeObject.id, subscribeObject.provider, subscriber.address, anyValue, subscribeObject.amount, clockTokenAddress, 8)

            
            expect(hre.ethers.formatEther(await hardhatCLOCKToken.balanceOf(caller.address))).to.equal("101.0")
            expect(hre.ethers.formatEther(await hardhatCLOCKToken.balanceOf(subscriber.address))).to.equal("91.0")
            expect(hre.ethers.formatEther(await hardhatCLOCKToken.balanceOf(provider.address))).to.equal("107.0")
            expect(hre.ethers.formatEther(await hardhatCLOCKToken.balanceOf(clockSubsribeAddress))).to.equal("1.0") 
        })
        it("Prorate when subscribing", async function() { 

            const {hardhatCLOCKToken, hardhatClockSubscribe, subscriber, caller, provider} = await loadFixture(deployClocktowerFixture);
            const clockTokenAddress = await hardhatCLOCKToken.getAddress()

            await hardhatClockSubscribe.addERC20Contract(clockTokenAddress, hre.ethers.parseEther(".01"))
            await hardhatClockSubscribe.setExternalCallers(true)
    
            //checks weekly subscription
            await hardhatClockSubscribe.connect(provider).createSubscription(hre.ethers.parseEther("7"), clockTokenAddress, details,0,3, testParams)
                 
            let subscriptions = await hardhatClockSubscribe.connect(provider).getAccountSubscriptions(false, provider.address);

            const subscribeObject = {
                id: subscriptions[0].subscription[0],
                amount: subscriptions[0].subscription[1],
                provider: subscriptions[0].subscription[2],
                token: subscriptions[0].subscription[3],
                exists: subscriptions[0].subscription[4],
                cancelled: subscriptions[0].subscription[5],
                frequency: subscriptions[0].subscription[6],
                dueDay: subscriptions[0].subscription[7]
            }

            await time.increase((dayAhead * 5))
    
            await expect(hardhatClockSubscribe.connect(subscriber).subscribe(subscribeObject, testParams))
            .to.changeTokenBalance(hardhatCLOCKToken, subscriber, hre.ethers.parseEther("-6"))

            //checks monthly subscription
            await hardhatClockSubscribe.connect(provider).createSubscription(hre.ethers.parseEther("1"), clockTokenAddress, details,1,5, testParams)
                 
            let subscriptions2 = await hardhatClockSubscribe.connect(provider).getAccountSubscriptions(false, provider.address);

            const subscribeObject2 = {
                id: subscriptions2[1].subscription[0],
                amount: subscriptions2[1].subscription[1],
                provider: subscriptions2[1].subscription[2],
                token: subscriptions2[1].subscription[3],
                exists: subscriptions2[1].subscription[4],
                cancelled: subscriptions2[1].subscription[5],
                frequency: subscriptions2[1].subscription[6],
                dueDay: subscriptions2[1].subscription[7]
            }

            await time.increase((dayAhead * 20))

            await expect(hardhatClockSubscribe.connect(subscriber).subscribe(subscribeObject2, testParams))
            .to.changeTokenBalance(hardhatCLOCKToken, subscriber, hre.ethers.parseEther("-0.32876712328767123"))

            //checks quarterly subscription
            await hardhatClockSubscribe.connect(provider).createSubscription(hre.ethers.parseEther("1"), clockTokenAddress, details,2,5, testParams)
                 
            let subscriptions3 = await hardhatClockSubscribe.connect(provider).getAccountSubscriptions(false, provider.address);

            const subscribeObject3= {
                id: subscriptions3[1].subscription[0],
                amount: subscriptions3[1].subscription[1],
                provider: subscriptions3[1].subscription[2],
                token: subscriptions3[1].subscription[3],
                exists: subscriptions3[1].subscription[4],
                cancelled: subscriptions3[1].subscription[5],
                frequency: subscriptions3[1].subscription[6],
                dueDay: subscriptions3[1].subscription[7]
            }
 
            await time.increase((dayAhead * 90))

            await expect(hardhatClockSubscribe.connect(subscriber).subscribe(subscribeObject3, testParams))
            .to.changeTokenBalance(hardhatCLOCKToken, subscriber, hre.ethers.parseEther("-0.32876712328767123"))

            //checks yearly subscription
            
            await hardhatClockSubscribe.connect(provider).createSubscription(hre.ethers.parseEther("1"), clockTokenAddress, details,3,5, testParams)
                 
            let subscriptions4 = await hardhatClockSubscribe.connect(provider).getAccountSubscriptions(false, provider.address);

            const subscribeObject4= {
                id: subscriptions4[1].subscription[0],
                amount: subscriptions4[1].subscription[1],
                provider: subscriptions4[1].subscription[2],
                token: subscriptions4[1].subscription[3],
                exists: subscriptions4[1].subscription[4],
                cancelled: subscriptions4[1].subscription[5],
                frequency: subscriptions4[1].subscription[6],
                dueDay: subscriptions4[1].subscription[7]
            }
 
            await time.increase((dayAhead * 365))

            await expect(hardhatClockSubscribe.connect(subscriber).subscribe(subscribeObject4, testParams))
            .to.changeTokenBalance(hardhatCLOCKToken, subscriber, hre.ethers.parseEther("-0.32876712328767123"))
            

        })
        it("Gets fee info from public getter functions", async function() { 
            const {hardhatCLOCKToken, hardhatClockSubscribe, subscriber, caller, provider, otherAccount} = await loadFixture(deployClocktowerFixture);

            const clockTokenAddress = await hardhatCLOCKToken.getAddress()
            await hardhatClockSubscribe.addERC20Contract(clockTokenAddress, hre.ethers.parseEther(".01"))
            await hardhatClockSubscribe.setExternalCallers(true)

            //creates subscription and subscribes
            await hardhatClockSubscribe.connect(provider).createSubscription(eth, clockTokenAddress, details,1,1, testParams)
             
            let subscriptions = await hardhatClockSubscribe.connect(provider).getAccountSubscriptions(false, provider.address);

            const subscribeObject = {
                id: subscriptions[0].subscription[0],
                amount: subscriptions[0].subscription[1],
                provider: subscriptions[0].subscription[2],
                token: subscriptions[0].subscription[3],
                exists: subscriptions[0].subscription[4],
                cancelled: subscriptions[0].subscription[5],
                frequency: subscriptions[0].subscription[6],
                dueDay: subscriptions[0].subscription[7]
            }

            await hardhatClockSubscribe.connect(subscriber).subscribe(subscribeObject, testParams)
            await hardhatClockSubscribe.connect(otherAccount).subscribe(subscribeObject, testParams)

            //first get all subscribers to subscription at the right day
            let stop = false
            let subs = new Array()
            let counter = 0
            
            /*
            while(!stop) {
            
                let test = await hardhatClockSubscribe.subscriptionMap(1, 1, 0)
                if(test.exists){
                    subs[counter] = test
                    console.log(test.id)
                } else {
                    stop = true;
                }
                counter++

            }
            //gets all fees from public mapping based on sub id
            let fee1 = await hardhatClockSubscribe.feeBalance(subscriptions[0].subscription.id, subscriber.address)

            console.log(fee1)
            */

        })
        it("Gets token minimum from contract", async function() { 
            const {hardhatCLOCKToken, hardhatClockSubscribe, subscriber, caller, provider, otherAccount} = await loadFixture(deployClocktowerFixture);
            const clockTokenAddress = await hardhatCLOCKToken.getAddress()

            await hardhatClockSubscribe.addERC20Contract(clockTokenAddress, hre.ethers.parseEther(".01"))

            let tokenObject = await hardhatClockSubscribe.connect(provider).approvedERC20(clockTokenAddress)

            expect(tokenObject.minimum).to.equal(hre.ethers.parseEther(".01"))
        })
        
    })
 
})