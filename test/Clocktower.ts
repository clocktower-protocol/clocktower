import { loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { time } from "@nomicfoundation/hardhat-network-helpers";
import { expect } from "chai";
import { ethers } from "hardhat";
import { anyValue } from "@nomicfoundation/hardhat-chai-matchers/withArgs";
//Written by Hugo Marx

describe("Clocktower", function(){

  
    //let currentTime = 1704088800;
    let currentTime = 1830319200
    let mergeTime = 0;
    //eth sent
    let eth = ethers.utils.parseEther("1.0")
    //console.log(eth)
    let centEth = ethers.utils.parseEther("100.0")

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

        const ClockToken = await ethers.getContractFactory("CLOCKToken");

        
        const ClockSubscribe = await ethers.getContractFactory("contracts/ClockTowerSubscribe.sol:ClockTowerSubscribe", {})

        const [owner, otherAccount, subscriber, provider, caller] = await ethers.getSigners();

        const hardhatCLOCKToken = await ClockToken.deploy(ethers.utils.parseEther("100100"));
        const hardhatClockSubscribe = await ClockSubscribe.deploy();

        await hardhatCLOCKToken.deployed();
        await hardhatClockSubscribe.deployed();
      
        //funds other account with eth
        const paramsOther = {
            from: owner.address,
            to: otherAccount.address,
            value: centEth
        };
        await owner.sendTransaction(paramsOther)
        
        await hardhatCLOCKToken.approve(hardhatClockSubscribe.address, infiniteApproval)
        await hardhatCLOCKToken.connect(otherAccount).approve(hardhatClockSubscribe.address, infiniteApproval)
        await hardhatCLOCKToken.connect(subscriber).approve(hardhatClockSubscribe.address, infiniteApproval)

    
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
            value: ethers.utils.parseEther("0.001")
        }

        const details = {
            domain: "domain",
            url: "URL",
            email: "Email",
            phone: "phone",
            description: "description"
        }

        it("Should create Subscription", async function() {
            const {hardhatCLOCKToken, hardhatClockSubscribe, provider, caller} = await loadFixture(deployClocktowerFixture);
            
            //adds CLOCK to approved tokens
            await hardhatClockSubscribe.addERC20Contract(hardhatCLOCKToken.address, ethers.utils.parseEther(".01"))
            
            //checks reverts

            //checks that too low an amount gets reverted
            await expect(hardhatClockSubscribe.connect(provider).createSubscription(ethers.utils.parseEther(".001"), hardhatCLOCKToken.address, details ,1,15, testParams))
            .to.be.reverted

            await expect(hardhatClockSubscribe.connect(provider).createSubscription(eth, ethers.constants.AddressZero, details,1,15, testParams))
            .to.be.revertedWith("8")

            await hardhatClockSubscribe.systemFeeActivate(true);
            await expect(hardhatClockSubscribe.connect(provider).createSubscription(eth, hardhatCLOCKToken.address, details,1,15, testParams2))
            .to.be.revertedWith("5")

            await expect(hardhatClockSubscribe.connect(provider).createSubscription(eth, caller.address, details,1,15, testParams))
            .to.be.revertedWith("9")

            await expect(hardhatClockSubscribe.connect(provider).createSubscription(eth, hardhatCLOCKToken.address, details,0,15, testParams))
            .to.be.revertedWith("26")

            await expect(hardhatClockSubscribe.connect(provider).createSubscription(eth, hardhatCLOCKToken.address, details,1,29, testParams))
            .to.be.revertedWith("27")

            await expect(hardhatClockSubscribe.connect(provider).createSubscription(eth, hardhatCLOCKToken.address, details,2,91, testParams))
            .to.be.revertedWith("28")

            await expect(hardhatClockSubscribe.connect(provider).createSubscription(eth, hardhatCLOCKToken.address, details,3,366, testParams))
            .to.be.revertedWith("29")

            await expect(hardhatClockSubscribe.connect(provider).createSubscription(ethers.utils.parseEther("0.001"), hardhatCLOCKToken.address, details,1,15, testParams))
            .to.be.revertedWith("30")

            await expect(hardhatClockSubscribe.connect(provider).createSubscription(eth, hardhatCLOCKToken.address, details,1,15, testParams))
            .to.emit(hardhatClockSubscribe, "SubLog").withArgs(anyValue, provider.address, anyValue, anyValue, eth, hardhatCLOCKToken.address, 0)
        })

        it("Should get created subscriptions", async function() {
            const {hardhatCLOCKToken, hardhatClockSubscribe, provider} = await loadFixture(deployClocktowerFixture);
            
            //adds CLOCK to approved tokens
            await hardhatClockSubscribe.addERC20Contract(hardhatCLOCKToken.address, ethers.utils.parseEther(".01"))

            await hardhatClockSubscribe.connect(provider).createSubscription(eth, hardhatCLOCKToken.address, details ,1, 15, testParams)
            await hardhatClockSubscribe.connect(provider).createSubscription(eth, hardhatCLOCKToken.address, details ,2, 15, testParams)
            let subscriptions = await hardhatClockSubscribe.connect(provider).getAccountSubscriptions(false, provider.address)

            //expect(subscriptions[1].subscription.description).to.equal("Test")
            expect(subscriptions[1].subscription.amount).to.equal(eth);
            expect(subscriptions[1].subscription.token).to.equal(hardhatCLOCKToken.address);
            expect(subscriptions[1].subscription.dueDay).to.equal(15);
        })
        
        it("Should allow user to subscribe", async function() {

            const testParams2 = {
                value: eth,
                gasLimit: 3000000
            };
    
            
            const {hardhatCLOCKToken, hardhatClockSubscribe, provider, subscriber, caller} = await loadFixture(deployClocktowerFixture);
            
            //adds CLOCK to approved tokens
            await hardhatClockSubscribe.addERC20Contract(hardhatCLOCKToken.address, ethers.utils.parseEther(".01"))

            await hardhatClockSubscribe.connect(provider).createSubscription(eth, hardhatCLOCKToken.address, details,1,15, testParams)
            await hardhatClockSubscribe.connect(provider).createSubscription(eth, hardhatCLOCKToken.address, details,3,15, testParams)

            let subscriptions = await hardhatClockSubscribe.connect(provider).getAccountSubscriptions(false, provider.address)

            //checks reverts

            //checks bad balance
            await hardhatCLOCKToken.connect(subscriber).transfer(caller.address, ethers.utils.parseEther("100"))
            await expect(hardhatClockSubscribe.connect(subscriber).subscribe(subscriptions[1].subscription, testParams2))
            .to.be.revertedWith("20")
            await hardhatCLOCKToken.connect(caller).transfer(subscriber.address, ethers.utils.parseEther("100"))

            //checks input of fake subscription
            let fakeSub = {id: "43445", amount: 5, provider: caller.address, token: hardhatCLOCKToken.address, exists: true, cancelled: false, frequency: 0, dueDay: 2, description: "test"}
            await expect(hardhatClockSubscribe.connect(subscriber).subscribe(fakeSub, testParams2))
            .to.be.rejectedWith("7")

            //tests emits and balances
            await expect(hardhatClockSubscribe.connect(subscriber).subscribe(subscriptions[1].subscription, testParams2))
            .to.emit(hardhatClockSubscribe, "SubLog").withArgs(anyValue, subscriber.provider, subscriber.address, anyValue, eth, hardhatCLOCKToken.address, 6)
            .to.emit(hardhatClockSubscribe, "SubLog").withArgs(anyValue, subscriber.provider, subscriber.address, anyValue, eth, hardhatCLOCKToken.address, 8)
            .to.changeTokenBalance(hardhatCLOCKToken, hardhatClockSubscribe.address, "83333333333333333")
            .to.changeTokenBalance(hardhatCLOCKToken, provider, "35159817351598170")
            
        })
        it("Should allow user to unsubscribe", async function() {
            const {hardhatCLOCKToken, hardhatClockSubscribe, provider, subscriber, caller} = await loadFixture(deployClocktowerFixture);
            
            //adds CLOCK to approved tokens
            await hardhatClockSubscribe.addERC20Contract(hardhatCLOCKToken.address, ethers.utils.parseEther(".01"))
           
            await hardhatClockSubscribe.connect(provider).createSubscription(eth, hardhatCLOCKToken.address, details,1,15, testParams)
            await hardhatClockSubscribe.connect(provider).createSubscription(eth, hardhatCLOCKToken.address, details,2,15, testParams)

            let subscriptions = await hardhatClockSubscribe.connect(provider).getAccountSubscriptions(false, provider.address);

            await hardhatClockSubscribe.connect(subscriber).subscribe(subscriptions[1].subscription, testParams)

            //check emits and balances
            await expect(hardhatClockSubscribe.connect(subscriber).unsubscribe(subscriptions[1].subscription, testParams))
            .to.emit(hardhatClockSubscribe, "SubLog").withArgs(anyValue, subscriptions[1].subscription.provider, subscriber.address, anyValue, eth, hardhatCLOCKToken.address, 7)
            .to.changeTokenBalance(hardhatCLOCKToken, provider, "51851851851851851")

            let result = await hardhatClockSubscribe.connect(subscriber).getAccountSubscriptions(true, subscriber.address)
            
            expect(result[0].status).to.equal(2)
           
            //checks second emit
            await hardhatClockSubscribe.connect(subscriber).subscribe(subscriptions[1].subscription, testParams)

            await expect(hardhatClockSubscribe.connect(subscriber).unsubscribe(subscriptions[1].subscription, testParams))
            .to.emit(hardhatClockSubscribe, "SubLog").withArgs(anyValue, provider.address, subscriber.address, anyValue, "51851851851851851", hardhatCLOCKToken.address, 4)
        })
        it("Should allow provider to unsubscribe sub", async function() {
            const {hardhatCLOCKToken, hardhatClockSubscribe, provider, subscriber, caller} = await loadFixture(deployClocktowerFixture);
            
            //adds CLOCK to approved tokens
            await hardhatClockSubscribe.addERC20Contract(hardhatCLOCKToken.address, ethers.utils.parseEther(".01"))

            await hardhatClockSubscribe.connect(provider).createSubscription(eth, hardhatCLOCKToken.address, details,1,1, testParams)

            let subscriptions = await hardhatClockSubscribe.connect(provider).getAccountSubscriptions(false, provider.address);

            await hardhatClockSubscribe.connect(subscriber).subscribe(subscriptions[0].subscription, testParams)
    
            //checks reverts

            //checks if user is in fact the provider
            await expect(hardhatClockSubscribe.connect(caller).unsubscribeByProvider(subscriptions[0].subscription, subscriber.address))
            .to.be.revertedWith("18")
            //checks if subscriber is subscribed to subscription
            await expect(hardhatClockSubscribe.connect(provider).unsubscribeByProvider(subscriptions[0].subscription, caller.address))
            .to.be.revertedWith("19")
            //checks first emit and token balance
            await expect(hardhatClockSubscribe.connect(provider).unsubscribeByProvider(subscriptions[0].subscription, subscriber.address))
            .to.emit(hardhatClockSubscribe, "SubLog").withArgs(anyValue, subscriptions[0].subscription.provider, subscriber.address, anyValue, subscriptions[0].subscription.amount, hardhatCLOCKToken.address, 7)
            //.to.emit(hardhatClockSubscribe, "SubscriberLog").withArgs(anyValue, subscriber.address, subscriptions[0].subscription.provider, anyValue,subscriptions[0].subscription.amount, hardhatCLOCKToken.address, 3)
            .to.changeTokenBalance(hardhatCLOCKToken, subscriber, ethers.utils.parseEther("1"))
            //checks second emit
            await hardhatClockSubscribe.connect(subscriber).subscribe(subscriptions[0].subscription, testParams)
            await expect(hardhatClockSubscribe.connect(provider).unsubscribeByProvider(subscriptions[0].subscription, subscriber.address))
            .to.emit(hardhatClockSubscribe, "SubLog").withArgs(anyValue, subscriptions[0].subscription.provider, subscriber.address, anyValue, "1000000000000000000", hardhatCLOCKToken.address, 7)

        })
        it("Should cancel subscription", async function(){
            const {hardhatCLOCKToken, hardhatClockSubscribe, provider, subscriber, caller} = await loadFixture(deployClocktowerFixture);
            
            //adds CLOCK to approved tokens
            await hardhatClockSubscribe.addERC20Contract(hardhatCLOCKToken.address, ethers.utils.parseEther(".01"))

            await hardhatClockSubscribe.connect(provider).createSubscription(eth, hardhatCLOCKToken.address, details,1,15, testParams)
            await hardhatClockSubscribe.connect(provider).createSubscription(eth, hardhatCLOCKToken.address, details,2,15, testParams)

            let subscriptions = await hardhatClockSubscribe.connect(provider).getAccountSubscriptions(false, provider.address);

            await hardhatClockSubscribe.connect(subscriber).subscribe(subscriptions[1].subscription, testParams)
    
            //checks reverts

            //checks input of fake subscription
            let fakeSub = {id: "43445", amount: 5, provider: caller.address, token: hardhatCLOCKToken.address, exists: true, cancelled: false, frequency: 0, dueDay: 2, description: "test"}
            await expect(hardhatClockSubscribe.connect(provider).cancelSubscription(fakeSub))
            .to.be.rejectedWith("7")

            await expect(hardhatClockSubscribe.connect(subscriber).cancelSubscription(subscriptions[1].subscription))
            .to.be.rejectedWith("23")

            //checks balances and emits

            await expect(hardhatClockSubscribe.connect(provider).cancelSubscription(subscriptions[1].subscription))
            .to.changeTokenBalance(hardhatCLOCKToken, subscriber, "51851851851851851")
            .to.emit(hardhatClockSubscribe, "SubLog").withArgs(anyValue, subscriptions[1].subscription.provider, subscriber.address, anyValue, "51851851851851851", hardhatCLOCKToken.address, 9)

            await hardhatClockSubscribe.connect(subscriber).subscribe(subscriptions[1].subscription, testParams)

            await expect(hardhatClockSubscribe.connect(provider).cancelSubscription(subscriptions[1].subscription))
            .to.emit(hardhatClockSubscribe, "SubLog").withArgs(anyValue, provider.address, anyValue, anyValue, 0, hardhatCLOCKToken.address, 1)

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
            await hardhatClockSubscribe.addERC20Contract(hardhatCLOCKToken.address, ethers.utils.parseEther(".01"))

            await hardhatClockSubscribe.connect(provider).createSubscription(eth, hardhatCLOCKToken.address, details,1,1, testParams)
            await hardhatClockSubscribe.connect(provider).createSubscription(eth, hardhatCLOCKToken.address, details,1,1, testParams)
            await hardhatClockSubscribe.connect(provider).createSubscription(eth, hardhatCLOCKToken.address, details,1,1, testParams)
            await hardhatClockSubscribe.connect(provider).createSubscription(eth, hardhatCLOCKToken.address, details,1,1, testParams)
            await hardhatClockSubscribe.connect(provider).createSubscription(eth, hardhatCLOCKToken.address, details,1,1, testParams)
            await hardhatClockSubscribe.connect(provider).createSubscription(eth, hardhatCLOCKToken.address, details,1,1, testParams)
            await hardhatClockSubscribe.connect(provider).createSubscription(eth, hardhatCLOCKToken.address, details,1,1, testParams)

            let subscriptions = await hardhatClockSubscribe.connect(provider).getAccountSubscriptions(false, provider.address);

            await hardhatClockSubscribe.connect(subscriber).subscribe(subscriptions[0].subscription, testParams)
            await hardhatClockSubscribe.connect(subscriber).subscribe(subscriptions[1].subscription, testParams)
            await hardhatClockSubscribe.connect(subscriber).subscribe(subscriptions[2].subscription, testParams)
            await hardhatClockSubscribe.connect(subscriber).subscribe(subscriptions[3].subscription, testParams)
            await hardhatClockSubscribe.connect(subscriber).subscribe(subscriptions[4].subscription, testParams)
            await hardhatClockSubscribe.connect(subscriber).subscribe(subscriptions[5].subscription, testParams)
            await hardhatClockSubscribe.connect(subscriber).subscribe(subscriptions[6].subscription, testParams)
            
            await time.increaseTo(twoHoursAhead);

            let subscribersId = await hardhatClockSubscribe.getSubscribersById(subscriptions[0].subscription.id)

            expect(subscribersId[0].subscriber).to.equal("0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC")
            expect(ethers.utils.formatEther(subscribersId[0].feeBalance)).to.equal("1.0")

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

            let expected = ethers.utils.parseEther("86.0");

            //gets fee balance
            expect(ethers.utils.formatEther(await hardhatClockSubscribe.feeBalance(subscriptions[0].subscription.id,subscriber.address))).to.equal("0.98")

            expect(otherBalance).to.equal(expected)
            
        })
        it("Should emit SubscriberLog", async function(){
            const {hardhatCLOCKToken, hardhatClockSubscribe, provider, subscriber} = await loadFixture(deployClocktowerFixture);
            //adds CLOCK to approved tokens
            await hardhatClockSubscribe.addERC20Contract(hardhatCLOCKToken.address, ethers.utils.parseEther(".01"))
            
            //creates subscription and subscribes
            await hardhatClockSubscribe.connect(provider).createSubscription(eth, hardhatCLOCKToken.address, details,1,1, testParams)
            
            let subscriptions = await hardhatClockSubscribe.connect(provider).getAccountSubscriptions(false, provider.address);
            
            //checks that event emits subscribe and feefill
            await expect(hardhatClockSubscribe.connect(subscriber).subscribe(subscriptions[0].subscription, testParams))
            .to.emit(hardhatClockSubscribe, "SubLog").withArgs(anyValue, anyValue, anyValue, anyValue, anyValue, hardhatCLOCKToken.address, 6)

            await expect(hardhatClockSubscribe.connect(subscriber).subscribe(subscriptions[0].subscription, testParams))
            .to.emit(hardhatClockSubscribe, "SubLog").withArgs(anyValue, anyValue, anyValue, anyValue, anyValue, hardhatCLOCKToken.address, 8)
        })
        it("Should allow external callers", async function() {
            const {hardhatCLOCKToken, hardhatClockSubscribe, provider, subscriber, caller} = await loadFixture(deployClocktowerFixture);
            //adds CLOCK to approved tokens
            await hardhatClockSubscribe.addERC20Contract(hardhatCLOCKToken.address, ethers.utils.parseEther(".01"))
           
            //creates subscription and subscribes
            await hardhatClockSubscribe.connect(provider).createSubscription(eth, hardhatCLOCKToken.address, details,1,1, testParams)
            
            let subscriptions = await hardhatClockSubscribe.connect(provider).getAccountSubscriptions(false, provider.address);
             
            await hardhatClockSubscribe.connect(subscriber).subscribe(subscriptions[0].subscription, testParams)

            //sets external callers
            await hardhatClockSubscribe.setExternalCallers(true)

            expect(await hardhatClockSubscribe.connect(caller).remit())
        })
        it("Should predict fees", async function() {
            const {hardhatCLOCKToken, hardhatClockSubscribe, provider, subscriber} = await loadFixture(deployClocktowerFixture);
            //adds CLOCK to approved tokens
            await hardhatClockSubscribe.addERC20Contract(hardhatCLOCKToken.address, ethers.utils.parseEther(".01"))
            
            //creates subscription and subscribes
            await hardhatClockSubscribe.connect(provider).createSubscription(eth, hardhatCLOCKToken.address, details,1,1, testParams)
            
            //let subscriptions = await hardhatClockSubscribe.getAccountSubscriptions(false)
            let subscriptions = await hardhatClockSubscribe.connect(provider).getAccountSubscriptions(false, provider.address);
            
            await hardhatClockSubscribe.connect(subscriber).subscribe(subscriptions[0].subscription, testParams)

            //moves time
            await time.increaseTo(twoHoursAhead);

            
            //gets fee estimate
            let feeArray = await hardhatClockSubscribe.feeEstimate();

            expect(feeArray.length).to.equal(1)
            expect(Number(ethers.utils.formatEther(feeArray[0].fee))).to.equal(0.02)
            expect(feeArray[0].token).to.equal(hardhatCLOCKToken.address)
            
            
        })
        it("Should collect system fees", async function() {
            const {hardhatCLOCKToken, hardhatClockSubscribe, owner, provider} = await loadFixture(deployClocktowerFixture);

            const testParams = {
                value: ethers.utils.parseEther("0.011")
            };

            //adds CLOCK to approved tokens
            await hardhatClockSubscribe.addERC20Contract(hardhatCLOCKToken.address, ethers.utils.parseEther(".01"))
            //turns on system fee collection
            await hardhatClockSubscribe.systemFeeActivate(true)

            //creates subscription and subscribes
            await hardhatClockSubscribe.connect(provider).createSubscription(eth, hardhatCLOCKToken.address, details,1,1, testParams)

            let ownerBalance1 = ethers.utils.formatEther(await owner.getBalance())

            //collect fees
            await hardhatClockSubscribe.collectFees()

            let ownerBalance2 = ethers.utils.formatEther(await owner.getBalance())

            expect(Number(ownerBalance2) - Number(ownerBalance1)).to.greaterThan(0.01)

        })
        it("Should refund provider on fail", async function() {
            
            const {hardhatCLOCKToken, hardhatClockSubscribe, subscriber, caller, provider} = await loadFixture(deployClocktowerFixture);

            const testParams = {
                value: eth
            };
            
            //adds CLOCK to approved tokens
            await hardhatClockSubscribe.addERC20Contract(hardhatCLOCKToken.address, ethers.utils.parseEther(".01"))

            //creates subscription and subscribes
            await hardhatClockSubscribe.connect(provider).createSubscription(eth, hardhatCLOCKToken.address, details,1,1, testParams)
            
            let subscriptions = await hardhatClockSubscribe.connect(provider).getAccountSubscriptions(false, provider.address);
            await hardhatClockSubscribe.connect(subscriber).subscribe(subscriptions[0].subscription, testParams)

            //otherAccount stops approval
            await hardhatCLOCKToken.connect(subscriber).approve(hardhatClockSubscribe.address, 0)

            let subAmount = await hardhatCLOCKToken.balanceOf(subscriber.address)

            await hardhatClockSubscribe.setExternalCallers(true)

            expect(await hardhatClockSubscribe.connect(caller).remit())
            .to.emit(hardhatClockSubscribe, "SubLog").withArgs(subscriptions[0].subscription.id, subscriptions[0].subscription.provider, subscriber.address, anyValue, subscriptions[0].subscription.amount, hardhatCLOCKToken.address, 7)

            //check that provider has been refunded
            let provAmount = await hardhatCLOCKToken.balanceOf(provider.address)

            //checks caller
            let callerAmount = await hardhatCLOCKToken.balanceOf(caller.address)

            expect(ethers.utils.formatEther(subAmount)).to.equal("99.0")
            expect(ethers.utils.formatEther(provAmount)).to.equal("100.98")    
            expect(ethers.utils.formatEther(callerAmount)).to.equal("100.02")  
            
            await hardhatClockSubscribe.connect(provider).createSubscription(eth, hardhatCLOCKToken.address, details,1,2, testParams)
            let subscriptions2 = await hardhatClockSubscribe.connect(provider).getAccountSubscriptions(false, provider.address);

            await time.increase(dayAhead)

            await hardhatCLOCKToken.connect(subscriber).approve(hardhatClockSubscribe.address, ethers.utils.parseEther("100"))
            await hardhatClockSubscribe.connect(subscriber).subscribe(subscriptions2[1].subscription, testParams)
            await hardhatCLOCKToken.connect(subscriber).approve(hardhatClockSubscribe.address, 0)
            expect(await hardhatClockSubscribe.connect(caller).remit())
            .to.emit(hardhatClockSubscribe, "SubLog").withArgs(subscriptions2[1].subscription.id, subscriptions2[1].subscription.provider, subscriber.address, anyValue, subscriptions2[1].subscription.amount, hardhatCLOCKToken.address, 3)

            await hardhatClockSubscribe.connect(provider).createSubscription(eth, hardhatCLOCKToken.address, details,1,3, testParams)
            let subscriptions3 = await hardhatClockSubscribe.connect(provider).getAccountSubscriptions(false, provider.address);

            await time.increase(dayAhead)

            await hardhatCLOCKToken.connect(subscriber).approve(hardhatClockSubscribe.address, ethers.utils.parseEther("100"))
            await hardhatClockSubscribe.connect(subscriber).subscribe(subscriptions3[2].subscription, testParams)
            await hardhatCLOCKToken.connect(subscriber).approve(hardhatClockSubscribe.address, 0)
            expect(await hardhatClockSubscribe.connect(caller).remit())
            .to.emit(hardhatClockSubscribe, "SubLog").withArgs(subscriptions3[2].subscription.id, provider.address, subscriber.address, anyValue, 0, hardhatCLOCKToken.address, 3)

        })
        it("Should add and remove ERC20 Tokens", async function() {
            const {hardhatCLOCKToken, hardhatClockSubscribe, subscriber, caller, provider} = await loadFixture(deployClocktowerFixture);

            //adds CLOCK to approved tokens
            expect(await hardhatClockSubscribe.addERC20Contract(hardhatCLOCKToken.address, ethers.utils.parseEther(".01")))
        })
        it("Should remit transactions PART 1", async function() {
            const {hardhatCLOCKToken, hardhatClockSubscribe, subscriber, caller, provider} = await loadFixture(deployClocktowerFixture);

            //adds CLOCK to approved tokens
            await hardhatClockSubscribe.addERC20Contract(hardhatCLOCKToken.address, ethers.utils.parseEther(".01"))

            //creates subscription and subscribes
            await hardhatClockSubscribe.connect(provider).createSubscription(eth, hardhatCLOCKToken.address, details,1,1, testParams)
             
            let subscriptions = await hardhatClockSubscribe.connect(provider).getAccountSubscriptions(false, provider.address);
            await hardhatClockSubscribe.connect(subscriber).subscribe(subscriptions[0].subscription, testParams)

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
            await hardhatClockSubscribe.connect(provider).createSubscription(eth, hardhatCLOCKToken.address, details,1,2, testParams)
            await hardhatClockSubscribe.connect(provider).createSubscription(eth, hardhatCLOCKToken.address, details,1,2, testParams)
            await hardhatClockSubscribe.connect(provider).createSubscription(eth, hardhatCLOCKToken.address, details,1,2, testParams)
            await hardhatClockSubscribe.connect(provider).createSubscription(eth, hardhatCLOCKToken.address, details,1,2, testParams)
            await hardhatClockSubscribe.connect(provider).createSubscription(eth, hardhatCLOCKToken.address, details,1,2, testParams)
            let subscriptions2 = await hardhatClockSubscribe.connect(provider).getAccountSubscriptions(false, provider.address);
            await hardhatClockSubscribe.connect(subscriber).subscribe(subscriptions2[1].subscription, testParams)
            await hardhatClockSubscribe.connect(subscriber).subscribe(subscriptions2[2].subscription, testParams)
            await hardhatClockSubscribe.connect(subscriber).subscribe(subscriptions2[3].subscription, testParams)
            await hardhatClockSubscribe.connect(subscriber).subscribe(subscriptions2[4].subscription, testParams)
            await hardhatClockSubscribe.connect(subscriber).subscribe(subscriptions2[5].subscription, testParams)

            //checks that on max remit caller is paid and event is emitted
            await expect(hardhatClockSubscribe.connect(caller).remit())
            .to.changeTokenBalance(hardhatCLOCKToken, caller, ethers.utils.parseEther("0.1"))
            .to.emit(hardhatClockSubscribe, "CallerLog").withArgs(anyValue, 21185, caller.address, true)

            //checks that successful transfer with enough fee balance
            time.increase((dayAhead))
            await hardhatClockSubscribe.connect(provider).createSubscription(eth, hardhatCLOCKToken.address, details,1,3, testParams)
            let subscriptions3 = await hardhatClockSubscribe.connect(provider).getAccountSubscriptions(false, provider.address);
            await hardhatClockSubscribe.connect(subscriber).subscribe(subscriptions3[6].subscription, testParams)
            
            await expect(hardhatClockSubscribe.connect(caller).remit())
            .to.changeTokenBalance(hardhatCLOCKToken, provider, ethers.utils.parseEther("1"))
            .to.emit(hardhatClockSubscribe, "SubLog").withArgs(subscriptions3[6].subscription.id, subscriptions3[6].subscription.provider, subscriber.address, anyValue, subscriptions3[6].subscription.amount, hardhatCLOCKToken.address, 5)

            time.increase((dayAhead))
            await hardhatClockSubscribe.connect(provider).createSubscription(eth, hardhatCLOCKToken.address, details,1,4, testParams)
            let subscriptions4 = await hardhatClockSubscribe.connect(provider).getAccountSubscriptions(false, provider.address);
            await hardhatClockSubscribe.connect(subscriber).subscribe(subscriptions4[7].subscription, testParams)
            
            await expect(hardhatClockSubscribe.connect(caller).remit())
            .to.emit(hardhatClockSubscribe, "SubLog").withArgs(anyValue, provider.address, subscriber.address, anyValue, 0, hardhatCLOCKToken.address, 2)
        })  
        it("Should remit transactions PART 2", async function() {

            const {hardhatCLOCKToken, hardhatClockSubscribe, subscriber, caller, provider} = await loadFixture(deployClocktowerFixture);

            //adds CLOCK to approved tokens
            await hardhatClockSubscribe.addERC20Contract(hardhatCLOCKToken.address, ethers.utils.parseEther(".01"))
            await hardhatClockSubscribe.changeCallerFee(13000)
            await hardhatClockSubscribe.setExternalCallers(true)

            //checks feefill events and token balances

            //checks subscriptions 90 days apart with depleted feeBalance

            await hardhatClockSubscribe.connect(provider).createSubscription(ethers.utils.parseEther("3"), hardhatCLOCKToken.address, details,2,1, testParams)
             
            let subscriptions = await hardhatClockSubscribe.connect(provider).getAccountSubscriptions(false, provider.address);

            await hardhatClockSubscribe.connect(subscriber).subscribe(subscriptions[0].subscription, testParams)
            
            expect(ethers.utils.formatEther(await hardhatCLOCKToken.balanceOf(subscriber.address))).to.equal("97.0")
            expect(ethers.utils.formatEther(await hardhatCLOCKToken.balanceOf(provider.address))).to.equal("102.0")
            expect(ethers.utils.formatEther(await hardhatCLOCKToken.balanceOf(caller.address))).to.equal("100.0")
            expect(ethers.utils.formatEther(await hardhatCLOCKToken.balanceOf(hardhatClockSubscribe.address))).to.equal("1.0")

            expect(await hardhatClockSubscribe.connect(caller).remit())

            expect(ethers.utils.formatEther(await hardhatCLOCKToken.balanceOf(subscriber.address))).to.equal("94.0")
            expect(ethers.utils.formatEther(await hardhatCLOCKToken.balanceOf(provider.address))).to.equal("105.0")
            expect(ethers.utils.formatEther(await hardhatCLOCKToken.balanceOf(caller.address))).to.equal("100.9")
            expect(ethers.utils.formatEther(await hardhatCLOCKToken.balanceOf(hardhatClockSubscribe.address))).to.equal("0.1")
            
            await time.increase((dayAhead * 95))

            await expect(hardhatClockSubscribe.connect(caller).remit())
            .to.changeTokenBalance(hardhatCLOCKToken, provider, ethers.utils.parseEther("2"))
            .to.emit(hardhatClockSubscribe, "SubLog").withArgs(subscriptions[0].subscription.id, subscriptions[0].subscription.provider, subscriber.address, anyValue, subscriptions[0].subscription.amount, hardhatCLOCKToken.address, 8)
            
            expect(ethers.utils.formatEther(await hardhatCLOCKToken.balanceOf(caller.address))).to.equal("101.0")
            expect(ethers.utils.formatEther(await hardhatCLOCKToken.balanceOf(subscriber.address))).to.equal("91.0")
            expect(ethers.utils.formatEther(await hardhatCLOCKToken.balanceOf(provider.address))).to.equal("107.0")
            expect(ethers.utils.formatEther(await hardhatCLOCKToken.balanceOf(hardhatClockSubscribe.address))).to.equal("1.0") 
        })
        it("Prorate when subscribing", async function() { 

            const {hardhatCLOCKToken, hardhatClockSubscribe, subscriber, caller, provider} = await loadFixture(deployClocktowerFixture);
            await hardhatClockSubscribe.addERC20Contract(hardhatCLOCKToken.address, ethers.utils.parseEther(".01"))
            await hardhatClockSubscribe.setExternalCallers(true)
    
            //checks weekly subscription
            await hardhatClockSubscribe.connect(provider).createSubscription(ethers.utils.parseEther("7"), hardhatCLOCKToken.address, details,0,3, testParams)
                 
            let subscriptions = await hardhatClockSubscribe.connect(provider).getAccountSubscriptions(false, provider.address);

            await time.increase((dayAhead * 5))
    
            await expect(hardhatClockSubscribe.connect(subscriber).subscribe(subscriptions[0].subscription, testParams))
            .to.changeTokenBalance(hardhatCLOCKToken, subscriber, ethers.utils.parseEther("-6"))

            //checks monthly subscription
            await hardhatClockSubscribe.connect(provider).createSubscription(ethers.utils.parseEther("1"), hardhatCLOCKToken.address, details,1,5, testParams)
                 
            let subscriptions2 = await hardhatClockSubscribe.connect(provider).getAccountSubscriptions(false, provider.address);

            await time.increase((dayAhead * 20))

            await expect(hardhatClockSubscribe.connect(subscriber).subscribe(subscriptions2[1].subscription, testParams))
            .to.changeTokenBalance(hardhatCLOCKToken, subscriber, ethers.utils.parseEther("-0.32876712328767123"))

            //checks quarterly subscription
            await hardhatClockSubscribe.connect(provider).createSubscription(ethers.utils.parseEther("1"), hardhatCLOCKToken.address, details,2,5, testParams)
                 
            let subscriptions3 = await hardhatClockSubscribe.connect(provider).getAccountSubscriptions(false, provider.address);
 
            await time.increase((dayAhead * 90))

            await expect(hardhatClockSubscribe.connect(subscriber).subscribe(subscriptions3[1].subscription, testParams))
            .to.changeTokenBalance(hardhatCLOCKToken, subscriber, ethers.utils.parseEther("-0.32876712328767123"))

            //checks yearly subscription
            
            await hardhatClockSubscribe.connect(provider).createSubscription(ethers.utils.parseEther("1"), hardhatCLOCKToken.address, details,3,5, testParams)
                 
            let subscriptions4 = await hardhatClockSubscribe.connect(provider).getAccountSubscriptions(false, provider.address);
 
            await time.increase((dayAhead * 365))

            await expect(hardhatClockSubscribe.connect(subscriber).subscribe(subscriptions4[1].subscription, testParams))
            .to.changeTokenBalance(hardhatCLOCKToken, subscriber, ethers.utils.parseEther("-0.32876712328767123"))
            

        })
        it("Gets fee info from public getter functions", async function() { 
            const {hardhatCLOCKToken, hardhatClockSubscribe, subscriber, caller, provider, otherAccount} = await loadFixture(deployClocktowerFixture);
            await hardhatClockSubscribe.addERC20Contract(hardhatCLOCKToken.address, ethers.utils.parseEther(".01"))
            await hardhatClockSubscribe.setExternalCallers(true)

            //creates subscription and subscribes
            await hardhatClockSubscribe.connect(provider).createSubscription(eth, hardhatCLOCKToken.address, details,1,1, testParams)
             
            let subscriptions = await hardhatClockSubscribe.connect(provider).getAccountSubscriptions(false, provider.address);
            await hardhatClockSubscribe.connect(subscriber).subscribe(subscriptions[0].subscription, testParams)
            await hardhatClockSubscribe.connect(otherAccount).subscribe(subscriptions[0].subscription, testParams)

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
            await hardhatClockSubscribe.addERC20Contract(hardhatCLOCKToken.address, ethers.utils.parseEther(".01"))

            let tokenObject = await hardhatClockSubscribe.connect(provider).approvedERC20(hardhatCLOCKToken.address)

            expect(tokenObject.minimum).to.equal(ethers.utils.parseEther(".01"))
        })
        
    })
 
})