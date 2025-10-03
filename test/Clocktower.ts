//import { loadFixture, time } from "@nomicfoundation/hardhat-network-helpers";
//import { loadFixture, time } from "@nomicfoundation/hardhat-toolbox/network-helpers";
//import { time } from "@nomicfoundation/hardhat-network-helpers";
import { expect } from "chai";
import hre from "hardhat";

const anyValue = () => true;

// Get ethers from network connection for Hardhat 3
const { ethers, networkHelpers } = await hre.network.connect();
const { loadFixture, time } = networkHelpers;


//Written by Hugo Marx

describe("Clocktower", function(){

    //let currentTime = 1704088800;
    let currentTime = 1830319200
    let mergeTime = 0;
    //eth sent
    let eth = ethers.parseEther("1.0")
    //console.log(eth)
    let centEth = ethers.parseEther("100.0")

    //sends test data of an hour ago
    let hourAhead = currentTime + 3600;
    let twoHoursAhead = hourAhead + 3600;
    let dayAhead = 86400;

    //CLOCK Decimals
    let ClockDecimals = 6n

    //Infinite approval
    const infiniteApproval = BigInt(Math.pow(2,255))
    
    let byteArray = []
    //creates empty 32 byte array
    for(let i = 0; i < 32; i++) {
        byteArray[i] = 0x0
    }

    const convert = (amount:bigint) => {
        return amount / 10n ** (18n - ClockDecimals)
    }

    const convertToWei = (amount:bigint) => {
        return amount * 10n ** (18n - ClockDecimals)
    }

    //fixture to deploy contract
    async function deployClocktowerFixture() {

        //sets time to 2028/01/01 1:00
        await time.increaseTo(currentTime);

        const ClockLibrary = await ethers.getContractFactory("ClockTowerTimeLibrary");
        const hardhatClockLibrary = await ClockLibrary.deploy()
        await hardhatClockLibrary.waitForDeployment()

        const timeLibAddress = await hardhatClockLibrary.getAddress()

        const ClockToken = await ethers.getContractFactory("CLOCKToken");

        //const { clockSubscribe } = await hre.ignition.deploy(ClockSubscribe)
        //const ClockSubscribeFactory = await ethers.getContractFactory("contracts/ClockTowerSubscribe.sol:ClockTowerSubscribe", {})
        const ClockSubscribeFactory = await ethers.getContractFactory("ClockTowerSubscribe", {
            libraries: {
                ClockTowerTimeLibrary: timeLibAddress
            },
        })

        const [owner, otherAccount, subscriber, provider, caller, subscriber2, subscriber3, subscriber4, subscriber5] = await ethers.getSigners();

        const hardhatCLOCKToken = await ClockToken.deploy(ethers.parseEther("100100"));
        const hardhatClockSubscribe = await ClockSubscribeFactory.deploy(10200n, 11000n, 5n, 5n, false, "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266", otherAccount.address);

        await hardhatCLOCKToken.waitForDeployment();
        await hardhatClockSubscribe.waitForDeployment();
      
        //funds other accounts with eth
        const paramsOther = {
            from: owner.address,
            to: otherAccount.address,
            value: centEth
        };
        const paramsOther2 = {
            from: owner.address,
            to: subscriber2.address,
            value: centEth
        };
        const paramsOther3 = {
            from: owner.address,
            to: subscriber3.address,
            value: centEth
        };
        const paramsOther4 = {
            from: owner.address,
            to: subscriber4.address,
            value: centEth
        };
        const paramsOther5 = {
            from: owner.address,
            to: subscriber5.address,
            value: centEth
        };
        await owner.sendTransaction(paramsOther)
        await owner.sendTransaction(paramsOther2)
        await owner.sendTransaction(paramsOther3)
        await owner.sendTransaction(paramsOther4)
        await owner.sendTransaction(paramsOther5)

        await hardhatCLOCKToken.approve(await hardhatClockSubscribe.getAddress(), infiniteApproval)
        await hardhatCLOCKToken.connect(otherAccount).approve(await hardhatClockSubscribe.getAddress(), infiniteApproval)
        await hardhatCLOCKToken.connect(subscriber).approve(await hardhatClockSubscribe.getAddress(), infiniteApproval)
        await hardhatCLOCKToken.connect(subscriber2).approve(await hardhatClockSubscribe.getAddress(), infiniteApproval)
        await hardhatCLOCKToken.connect(subscriber3).approve(await hardhatClockSubscribe.getAddress(), infiniteApproval)
        await hardhatCLOCKToken.connect(subscriber4).approve(await hardhatClockSubscribe.getAddress(), infiniteApproval)
        await hardhatCLOCKToken.connect(subscriber5).approve(await hardhatClockSubscribe.getAddress(), infiniteApproval)

        /*
        console.log("HERE")
        console.log(owner.address)
        console.log(otherAccount.address)
        console.log(subscriber.address)
        */
         //sends 100 clocktoken to other accounts
        await hardhatCLOCKToken.transfer(otherAccount.address, convert(centEth))
        await hardhatCLOCKToken.transfer(subscriber.address, convert(centEth))
        await hardhatCLOCKToken.transfer(provider.address, convert(centEth))
        await hardhatCLOCKToken.transfer(caller.address, convert(centEth))
        await hardhatCLOCKToken.transfer(subscriber2.address, convert(centEth))
        await hardhatCLOCKToken.transfer(subscriber3.address, convert(centEth))
        await hardhatCLOCKToken.transfer(subscriber4.address, convert(centEth))
        await hardhatCLOCKToken.transfer(subscriber5.address, convert(centEth))

        return {owner, otherAccount, subscriber, provider, caller, hardhatCLOCKToken, hardhatClockSubscribe, subscriber2, subscriber3, subscriber4, subscriber5} ;
    }
    describe("Subscriptions", function() {
        const testParams = {
            value: eth
        };

        const testParams2 = {
            value: ethers.parseEther("0.001")
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
            await hardhatClockSubscribe.addERC20Contract(await hardhatCLOCKToken.getAddress(), ethers.parseEther(".01"), ClockDecimals)
            
            //checks reverts

            //checks that too low an amount gets reverted
            await expect(hardhatClockSubscribe.connect(provider).createSubscription(ethers.parseEther(".001"), await hardhatCLOCKToken.getAddress(), details ,1,15))
            .to.be.revertedWith("18")

            await expect(hardhatClockSubscribe.connect(provider).createSubscription(eth, ethers.ZeroAddress, details,1,15))
            .to.be.revertedWith("4")

            await hardhatClockSubscribe.systemFeeActivate(true);
            /*
            await expect(hardhatClockSubscribe.connect(provider).createSubscription(eth, await hardhatCLOCKToken.getAddress(), details,1,15, testParams2))
            .to.be.revertedWith("5")
            */

            await expect(hardhatClockSubscribe.connect(provider).createSubscription(eth, caller.address, details,1,15))
            .to.be.revertedWith("5")

            await expect(hardhatClockSubscribe.connect(provider).createSubscription(eth, await hardhatCLOCKToken.getAddress(), details,0,15))
            .to.be.revertedWith("14")

            await expect(hardhatClockSubscribe.connect(provider).createSubscription(eth, await hardhatCLOCKToken.getAddress(), details,1,29))
            .to.be.revertedWith("15")

            await expect(hardhatClockSubscribe.connect(provider).createSubscription(eth, await hardhatCLOCKToken.getAddress(), details,2,91))
            .to.be.revertedWith("16")

            await expect(hardhatClockSubscribe.connect(provider).createSubscription(eth, await hardhatCLOCKToken.getAddress(), details,3,366))
            .to.be.revertedWith("17")

            await expect(hardhatClockSubscribe.connect(provider).createSubscription(ethers.parseEther("0.001"), await hardhatCLOCKToken.getAddress(), details,1,15))
            .to.be.revertedWith("18")

            await expect(hardhatClockSubscribe.connect(provider).createSubscription(eth, await hardhatCLOCKToken.getAddress(), details,1,15))
            .to.emit(hardhatClockSubscribe, "SubLog").withArgs(anyValue, provider.address, anyValue, anyValue, eth, await hardhatCLOCKToken.getAddress(), 0)
        })

        it("Should get created subscriptions", async function() {
            const {hardhatCLOCKToken, hardhatClockSubscribe, provider} = await loadFixture(deployClocktowerFixture);
            
            //adds CLOCK to approved tokens
            await hardhatClockSubscribe.addERC20Contract(await hardhatCLOCKToken.getAddress(), ethers.parseEther(".01"), ClockDecimals)

            await hardhatClockSubscribe.connect(provider).createSubscription(eth, await hardhatCLOCKToken.getAddress(), details ,1, 15)
            await hardhatClockSubscribe.connect(provider).createSubscription(eth, await hardhatCLOCKToken.getAddress(), details ,2, 15)
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
            await hardhatClockSubscribe.addERC20Contract(clockTokenAddress, ethers.parseEther(".01"), ClockDecimals)

            await hardhatClockSubscribe.connect(provider).createSubscription(eth, clockTokenAddress, details,1,15)
            await hardhatClockSubscribe.connect(provider).createSubscription(eth, clockTokenAddress, details,3,15)

            const subscriptions = await hardhatClockSubscribe.connect(provider).getAccountSubscriptions(false, provider.address)

            //checks reverts

            //creates subscribe object
            
            const subscribeObject = {
                id: subscriptions[1].subscription[0],
                amount: subscriptions[1].subscription[1],
                provider: subscriptions[1].subscription[2],
                token: subscriptions[1].subscription[3],
                //exists: subscriptions[1].subscription[4],
                cancelled: subscriptions[1].subscription[4],
                frequency: subscriptions[1].subscription[5],
                dueDay: subscriptions[1].subscription[6]
            }
            
            
            //checks bad balance
            await hardhatCLOCKToken.connect(subscriber).transfer(caller.address, convert(ethers.parseEther("100")))
            await expect(hardhatClockSubscribe.connect(subscriber).subscribe(subscribeObject))
            .to.be.revertedWith("10")
            await hardhatCLOCKToken.connect(caller).transfer(subscriber.address, convert(ethers.parseEther("100")))
            
            
            //checks input of fake subscription
            let fakeSub = {id: "0x496e74686520517569636b2042726f776e20466f78204a6f686e204a6f686e20536d697468", amount: 5, provider: caller.address, token: clockTokenAddress, cancelled: false, frequency: 0, dueDay: 2}
        
            await expect(hardhatClockSubscribe.connect(subscriber).subscribe(fakeSub))
            .to.be.rejectedWith("3")
            
                
            /*
            const tx = await hardhatClockSubscribe.connect(subscriber).subscribe(subscribeObject, testParams2)
            await expect(tx).to.emit(hardhatClockSubscribe, "SubLog").withArgs(anyValue, subscriber.provider, subscriber.address, anyValue, eth, await hardhatCLOCKToken.getAddress(), 6)
            await expect(tx).to.emit(hardhatClockSubscribe, "SubLog").withArgs(anyValue, subscriber.provider, subscriber.address, anyValue, eth, await hardhatCLOCKToken.getAddress(), 8)
            await expect(tx).to.changeTokenBalance(ethers, hardhatCLOCKToken, await hardhatClockSubscribe.getAddress(), "83333333333333333")
            await expect(tx).to.changeTokenBalance(ethers, hardhatCLOCKToken, provider, "35159817351598170")
            */
        })
        it("Should allow user to unsubscribe", async function() {
            const {hardhatCLOCKToken, hardhatClockSubscribe, provider, subscriber, caller, owner} = await loadFixture(deployClocktowerFixture);

            const clockTokenAddress = await hardhatCLOCKToken.getAddress()
            
            //adds CLOCK to approved tokens
            await hardhatClockSubscribe.addERC20Contract(clockTokenAddress, ethers.parseEther(".01"), ClockDecimals)
           
            await hardhatClockSubscribe.connect(provider).createSubscription(eth, clockTokenAddress, details,1,15)
            await hardhatClockSubscribe.connect(provider).createSubscription(eth, clockTokenAddress, details,2,15)

            let subscriptions = await hardhatClockSubscribe.connect(provider).getAccountSubscriptions(false, provider.address);

             //creates subscribe object
             const subscribeObject = {
                id: subscriptions[1].subscription[0],
                amount: subscriptions[1].subscription[1],
                provider: subscriptions[1].subscription[2],
                token: subscriptions[1].subscription[3],
                //exists: subscriptions[1].subscription[4],
                cancelled: subscriptions[1].subscription[4],
                frequency: subscriptions[1].subscription[5],
                dueDay: subscriptions[1].subscription[6]
            }

            await hardhatClockSubscribe.connect(subscriber).subscribe(subscribeObject)

            //check emits and balances
            await expect(hardhatClockSubscribe.connect(subscriber).unsubscribe(subscribeObject))
            .to.emit(hardhatClockSubscribe, "SubLog").withArgs(anyValue, subscribeObject.provider, subscriber.address, anyValue, eth, clockTokenAddress, 7)

            //checks that when you unsubscribe not in pagination the subscriber is deleted from subscription list
            const ids = await hardhatClockSubscribe.connect(subscriber).getSubscribersById(subscribeObject.id)
            expect(ids.length).to.be.equal(0)
            
            await hardhatClockSubscribe.connect(subscriber).subscribe(subscribeObject)

            const pageStart = {
                id: subscribeObject.id,
                subscriberIndex: 1,
                subscriptionIndex: 1,
                frequency: 2,
                initialized: true
            }

            //checks that in a paginated state the subscriber stays in the list but is added to the unsubscribe map
            await hardhatClockSubscribe.connect(owner).setPageStart(pageStart)

            //console.log(51851851851851851n / 10n ** (18n - ClockDecimals))

            //console.log(Math.floor(Number(ethers.formatEther("51851851851851851")) * 10 ** ClockDecimals))

            await expect(hardhatClockSubscribe.connect(subscriber).unsubscribe(subscribeObject))
            .to.changeTokenBalance(ethers, hardhatCLOCKToken, provider, convert(83000000000000000n))

            const ids2 = await hardhatClockSubscribe.connect(subscriber).getSubscribersById(subscribeObject.id)

            expect(ids2.length).to.be.equal(0)

            //expects unsubscribed list to be increased
            expect(await hardhatClockSubscribe.connect(owner).getUnsubscribedLength(subscribeObject.id)).to.equal(1)
           

            const pageStart2 = {
                id: ethers.ZeroHash,
                subscriberIndex: 0,
                subscriptionIndex: 0,
                frequency: 0,
                initialized: false
            }

            //turns off pagination
            await hardhatClockSubscribe.connect(owner).setPageStart(pageStart2)

            let result = await hardhatClockSubscribe.connect(subscriber).getAccountSubscriptions(true, subscriber.address)
            
            expect(result[0].status).to.equal(2)
           
            //checks second emit
            await hardhatClockSubscribe.connect(subscriber).subscribe(subscribeObject)

            await expect(hardhatClockSubscribe.connect(subscriber).unsubscribe(subscribeObject))
            .to.emit(hardhatClockSubscribe, "SubLog").withArgs(anyValue, provider.address, subscriber.address, anyValue, "83000000000000000", clockTokenAddress, 4)
        })
        it("Should allow provider to unsubscribe sub", async function() {
            const {hardhatCLOCKToken, hardhatClockSubscribe, provider, subscriber, caller, otherAccount} = await loadFixture(deployClocktowerFixture);

            const clockTokenAddress = await hardhatCLOCKToken.getAddress()
            
            //adds CLOCK to approved tokens
            await hardhatClockSubscribe.addERC20Contract(clockTokenAddress, ethers.parseEther(".01"), ClockDecimals)

            await hardhatClockSubscribe.connect(provider).createSubscription(eth, clockTokenAddress, details,1,1)

            let subscriptions = await hardhatClockSubscribe.connect(provider).getAccountSubscriptions(false, provider.address);

             //creates subscribe object
             const subscribeObject = {
                id: subscriptions[0].subscription[0],
                amount: subscriptions[0].subscription[1],
                provider: subscriptions[0].subscription[2],
                token: subscriptions[0].subscription[3],
                //exists: subscriptions[0].subscription[4],
                cancelled: subscriptions[0].subscription[4],
                frequency: subscriptions[0].subscription[5],
                dueDay: subscriptions[0].subscription[6]
            }

            await hardhatClockSubscribe.connect(subscriber).subscribe(subscribeObject)
    
            //checks reverts

            //checks if user is in fact the provider
            await expect(hardhatClockSubscribe.connect(caller).unsubscribeByProvider(subscribeObject, subscriber.address))
            .to.be.revertedWith("8")
            //checks if subscriber is subscribed to subscription
            await expect(hardhatClockSubscribe.connect(provider).unsubscribeByProvider(subscribeObject, caller.address))
            .to.be.revertedWith("9")
            //checks first emit and token balance
            await expect(hardhatClockSubscribe.connect(provider).unsubscribeByProvider(subscribeObject, subscriber.address))
            .to.emit(hardhatClockSubscribe, "SubLog").withArgs(anyValue, subscribeObject.provider, subscriber.address, anyValue, subscriptions[0].subscription.amount, clockTokenAddress, 7)
            //.to.emit(hardhatClockSubscribe, "SubscriberLog").withArgs(anyValue, subscriber.address, subscriptions[0].subscription.provider, anyValue,subscriptions[0].subscription.amount, hardhatCLOCKToken.address, 3)
            //.to.changeTokenBalance(hardhatCLOCKToken, subscriber, ethers.parseEther("1"))

            //checks second emit
            await hardhatClockSubscribe.connect(subscriber).subscribe(subscribeObject)
            await expect(hardhatClockSubscribe.connect(provider).unsubscribeByProvider(subscribeObject, subscriber.address))
            .to.emit(hardhatClockSubscribe, "SubLog").withArgs(anyValue, subscribeObject.provider, subscriber.address, anyValue, "1000000000000000000", clockTokenAddress, 7)

        })
        it("Should cancel subscription", async function(){
            const {hardhatCLOCKToken, hardhatClockSubscribe, provider, subscriber, caller, otherAccount, owner} = await loadFixture(deployClocktowerFixture);

            const clockTokenAddress = await hardhatCLOCKToken.getAddress()
            
            //adds CLOCK to approved tokens
            await hardhatClockSubscribe.addERC20Contract(clockTokenAddress, ethers.parseEther(".01"), ClockDecimals)

            await hardhatClockSubscribe.connect(provider).createSubscription(eth, clockTokenAddress, details,1,15)
            await hardhatClockSubscribe.connect(provider).createSubscription(eth, clockTokenAddress, details,2,15)
            await hardhatClockSubscribe.connect(provider).createSubscription(eth, clockTokenAddress, details,2,16)

            let subscriptions = await hardhatClockSubscribe.connect(provider).getAccountSubscriptions(false, provider.address);

             //creates subscribe object
            const subscribeObject = {
                id: subscriptions[1].subscription[0],
                amount: subscriptions[1].subscription[1],
                provider: subscriptions[1].subscription[2],
                token: subscriptions[1].subscription[3],
                //exists: subscriptions[1].subscription[4],
                cancelled: subscriptions[1].subscription[4],
                frequency: subscriptions[1].subscription[5],
                dueDay: subscriptions[1].subscription[6]
            }

            const subscribeObject2 = {
                id: subscriptions[0].subscription[0],
                amount: subscriptions[0].subscription[1],
                provider: subscriptions[0].subscription[2],
                token: subscriptions[0].subscription[3],
                //exists: subscriptions[1].subscription[4],
                cancelled: subscriptions[0].subscription[4],
                frequency: subscriptions[0].subscription[5],
                dueDay: subscriptions[0].subscription[6]
            }
            await hardhatClockSubscribe.connect(subscriber).subscribe(subscribeObject)
            await hardhatClockSubscribe.connect(otherAccount).subscribe(subscribeObject)
            await hardhatClockSubscribe.connect(subscriber).subscribe(subscribeObject2)
    
            //checks reverts

            await hardhatClockSubscribe.connect(owner).setCancelLimit(5n)

            //checks input of fake subscription
            let fakeSub = {id: "7a8b9c1d2e3f4a5b6c7d8e9f0a1b2c3d", amount: 5, provider: caller.address, token: clockTokenAddress, cancelled: false, frequency: 0, dueDay: 2}
            await expect(hardhatClockSubscribe.connect(provider).cancelSubscription(fakeSub))
            .to.be.rejectedWith("3")

            await expect(hardhatClockSubscribe.connect(subscriber).cancelSubscription(subscribeObject))
            .to.be.rejectedWith("13")

            //checks balances and emits

            /*
            //await expect(hardhatClockSubscribe.connect(provider).cancelSubscription(subscribeObject))
            //.to.changeTokenBalance(hardhatCLOCKToken, subscriber, "51851851851851851")
            //.to.emit(hardhatClockSubscribe, "SubLog").withArgs(anyValue, subscribeObject.provider, subscriber.address, anyValue, "51851851851851851", clockTokenAddress, 9)

            //checks token balance
            await hardhatClockSubscribe.connect(subscriber).subscribe(subscribeObject)
            await expect(hardhatClockSubscribe.connect(provider).cancelSubscription(subscribeObject))
            .to.changeTokenBalance(ethers, hardhatCLOCKToken, subscriber, "51851851851851851")
            */

            //await hardhatClockSubscribe.connect(subscriber).subscribe(subscribeObject)

            await expect(hardhatClockSubscribe.connect(provider).cancelSubscription(subscribeObject))
            .to.emit(hardhatClockSubscribe, "SubLog").withArgs(anyValue, provider.address, anyValue, anyValue, 0, clockTokenAddress, 1)

            let result = await hardhatClockSubscribe.connect(subscriber).getAccountSubscriptions(true, subscriber.address)

            //expect(result[0].status).to.equal(1);
            expect(result[0].subscription.cancelled).to.equal(true)

            //checks that subscription is NOT added to time mappings if there are no subscribers (done only with first subscriber)
            let ids = await hardhatClockSubscribe.connect(owner).getIdByTime(2, 16)
            expect(ids.length).to.equal(0)

            //sees if remit cleans the subscription from the time mapping

            //subscription is in timetable
            let ids2 = await hardhatClockSubscribe.connect(owner).getIdByTime(2, 15)
            expect(ids2.length).to.equal(1)
            //has one subscriber
            let subs = await hardhatClockSubscribe.connect(owner).getSubscribersById(ids2[0])
            expect(subs.length).to.equal(2)
            //cleans up subscribers
            await hardhatClockSubscribe.connect(otherAccount).cleanupCancelledSubscribers(subscribeObject)
            //should have no subscribers now
            let subs2 = await hardhatClockSubscribe.connect(owner).getSubscribersById(ids2[0])
            expect(subs2.length).to.equal(0)

            
            //remits subscriptions and should remove cancelled subscription
            let block = await ethers.provider.getBlock("latest")
            
            await time.increase(dayAhead * 100)
            await hardhatClockSubscribe.connect(owner).remit()
            let ids3 = await hardhatClockSubscribe.connect(owner).getIdByTime(2, 15)
            expect(ids3.length).to.be.equal(0)
            
            
            
        })
        it("Should paginate remit transactions", async function(){
            const {hardhatCLOCKToken, hardhatClockSubscribe, owner, provider, subscriber, caller} = await loadFixture(deployClocktowerFixture);
            
            let remits = 5

            //sets remits to 5
            expect(await hardhatClockSubscribe.changeMaxRemits(remits))

            //allows external callers
            //await hardhatClockSubscribe.setExternalCallers(true)

            //adds CLOCK to approved tokens
            await hardhatClockSubscribe.addERC20Contract(await hardhatCLOCKToken.getAddress(), ethers.parseEther(".01"), ClockDecimals)

            await hardhatClockSubscribe.connect(provider).createSubscription(eth, await hardhatCLOCKToken.getAddress(), details,1,1)
            await hardhatClockSubscribe.connect(provider).createSubscription(eth, await hardhatCLOCKToken.getAddress(), details,1,1)
            await hardhatClockSubscribe.connect(provider).createSubscription(eth, await hardhatCLOCKToken.getAddress(), details,1,1)
            await hardhatClockSubscribe.connect(provider).createSubscription(eth, await hardhatCLOCKToken.getAddress(), details,1,1)
            await hardhatClockSubscribe.connect(provider).createSubscription(eth, await hardhatCLOCKToken.getAddress(), details,1,1)
            await hardhatClockSubscribe.connect(provider).createSubscription(eth, await hardhatCLOCKToken.getAddress(), details,1,1)
            await hardhatClockSubscribe.connect(provider).createSubscription(eth, await hardhatCLOCKToken.getAddress(), details,1,1)

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
                    //exists: subscriptions[i].subscription[4],
                    cancelled: subscriptions[i].subscription[4],
                    frequency: subscriptions[i].subscription[5],
                    dueDay: subscriptions[i].subscription[6]
                })
            }

            //console.log(await hardhatCLOCKToken.balanceOf(subscriber.address))

            await hardhatClockSubscribe.connect(subscriber).subscribe(subArray[0])
            await hardhatClockSubscribe.connect(subscriber).subscribe(subArray[1])
            await hardhatClockSubscribe.connect(subscriber).subscribe(subArray[2])
            await hardhatClockSubscribe.connect(subscriber).subscribe(subArray[3])
            await hardhatClockSubscribe.connect(subscriber).subscribe(subArray[4])
            await hardhatClockSubscribe.connect(subscriber).subscribe(subArray[5])
            await hardhatClockSubscribe.connect(subscriber).subscribe(subArray[6])
            
            await time.increaseTo(twoHoursAhead);

            let subscribersId = await hardhatClockSubscribe.getSubscribersById(subArray[0].id)

            expect(subscribersId[0].subscriber).to.equal("0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC")
            expect(ethers.formatEther(subscribersId[0].feeBalance)).to.equal("0.02")

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

            //balance befoe remmitance
            //console.log(await hardhatCLOCKToken.balanceOf(subscriber.address))
            await hardhatClockSubscribe.connect(caller).remit();
            //console.log(ethers.formatEther(await hardhatClockSubscribe.connect(provider).feeBalance(subscriptions[0].subscription[0], subscriber.address)))
            //console.log(await hardhatCLOCKToken.balanceOf(subscriber.address))
            await hardhatClockSubscribe.connect(caller).remit();
            //console.log(await hardhatCLOCKToken.balanceOf(subscriber.address))
            //console.log(ethers.formatEther(await hardhatClockSubscribe.connect(provider).feeBalance(subscriptions[0].subscription[0], subscriber.address)))

            let otherBalance = await hardhatCLOCKToken.balanceOf(subscriber.address)

            //console.log(otherBalance)

            let expected = convert(ethers.parseEther("92.86"));

            //gets fee balance
            expect(ethers.formatEther(await hardhatClockSubscribe.feeBalance(subArray[0].id,subscriber.address))).to.equal("0.25")

            expect(otherBalance).to.equal(expected)
            
        })
        it("Should emit SubscriberLog", async function(){
            const {hardhatCLOCKToken, hardhatClockSubscribe, provider, subscriber} = await loadFixture(deployClocktowerFixture);
            //adds CLOCK to approved tokens
            await hardhatClockSubscribe.addERC20Contract(await hardhatCLOCKToken.getAddress(), ethers.parseEther(".01"), ClockDecimals)
            
            //creates subscription and subscribes
            await hardhatClockSubscribe.connect(provider).createSubscription(eth, await hardhatCLOCKToken.getAddress(), details,1,1)
            
            let subscriptions = await hardhatClockSubscribe.connect(provider).getAccountSubscriptions(false, provider.address);

             //creates subscribe object
             const subscribeObject = {
                id: subscriptions[0].subscription[0],
                amount: subscriptions[0].subscription[1],
                provider: subscriptions[0].subscription[2],
                token: subscriptions[0].subscription[3],
                //exists: subscriptions[0].subscription[4],
                cancelled: subscriptions[0].subscription[4],
                frequency: subscriptions[0].subscription[5],
                dueDay: subscriptions[0].subscription[6]
            }

            const tx = await hardhatClockSubscribe.connect(subscriber).subscribe(subscribeObject)

            expect(tx).to.emit(hardhatClockSubscribe, "SubLog").withArgs(anyValue, anyValue, anyValue, anyValue, anyValue, await hardhatCLOCKToken.getAddress(), 6)
            expect(tx).to.emit(hardhatClockSubscribe, "SubLog").withArgs(anyValue, anyValue, anyValue, anyValue, anyValue, await hardhatCLOCKToken.getAddress(), 8)
            
            /*
            //checks that event emits subscribe and feefill
            await expect(hardhatClockSubscribe.connect(subscriber).subscribe(subscribeObject))
            .to.emit(hardhatClockSubscribe, "SubLog").withArgs(anyValue, anyValue, anyValue, anyValue, anyValue, await hardhatCLOCKToken.getAddress(), 6)

            await expect(hardhatClockSubscribe.connect(subscriber).subscribe(subscribeObject))
            .to.emit(hardhatClockSubscribe, "SubLog").withArgs(anyValue, anyValue, anyValue, anyValue, anyValue, await hardhatCLOCKToken.getAddress(), 8)
            */
        })
        it("Should allow external callers", async function() {
            const {hardhatCLOCKToken, hardhatClockSubscribe, provider, subscriber, caller} = await loadFixture(deployClocktowerFixture);
            //adds CLOCK to approved tokens
            await hardhatClockSubscribe.addERC20Contract(await hardhatCLOCKToken.getAddress(), ethers.parseEther(".01"), ClockDecimals)
           
            //creates subscription and subscribes
            await hardhatClockSubscribe.connect(provider).createSubscription(eth, await hardhatCLOCKToken.getAddress(), details,1,1)
            
            let subscriptions = await hardhatClockSubscribe.connect(provider).getAccountSubscriptions(false, provider.address);

              //creates subscribe object
              const subscribeObject = {
                id: subscriptions[0].subscription[0],
                amount: subscriptions[0].subscription[1],
                provider: subscriptions[0].subscription[2],
                token: subscriptions[0].subscription[3],
                //exists: subscriptions[0].subscription[4],
                cancelled: subscriptions[0].subscription[4],
                frequency: subscriptions[0].subscription[5],
                dueDay: subscriptions[0].subscription[6]
            }
             
            await hardhatClockSubscribe.connect(subscriber).subscribe(subscribeObject)

            //sets external callers
            //await hardhatClockSubscribe.setExternalCallers(true)

            expect(await hardhatClockSubscribe.connect(caller).remit())
        })
        /*
        it("Should predict fees", async function() {
            const {hardhatCLOCKToken, hardhatClockSubscribe, provider, subscriber} = await loadFixture(deployClocktowerFixture);
            //adds CLOCK to approved tokens
            await hardhatClockSubscribe.addERC20Contract(await hardhatCLOCKToken.getAddress(), ethers.parseEther(".01"), ClockDecimals)
            
            //creates subscription and subscribes
            await hardhatClockSubscribe.connect(provider).createSubscription(eth, await hardhatCLOCKToken.getAddress(), details,1,1)
            
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
            
            await hardhatClockSubscribe.connect(subscriber).subscribe(subscribeObject)

            //moves time
            await time.increaseTo(twoHoursAhead);

            
            //gets fee estimate
            let feeArray = await hardhatClockSubscribe.feeEstimate();

            expect(feeArray.length).to.equal(1)
            expect(Number(ethers.formatEther(feeArray[0].fee))).to.equal(0.02)
            expect(feeArray[0].token).to.equal(await hardhatCLOCKToken.getAddress())
            
            
        })
            */
        it("Should collect system fees", async function() {
            const {hardhatCLOCKToken, hardhatClockSubscribe, owner, provider, caller, subscriber} = await loadFixture(deployClocktowerFixture);

            const testParams = {
                value: ethers.parseEther("0.011")
            };

            //adds CLOCK to approved tokens
            await hardhatClockSubscribe.addERC20Contract(await hardhatCLOCKToken.getAddress(), ethers.parseEther(".01"), ClockDecimals)
            //turns on system fee collection
            await hardhatClockSubscribe.systemFeeActivate(true)
            //await hardhatClockSubscribe.setExternalCallers(true)
            //await hardhatClockSubscribe.changeSystemFee(ethers.parseEther(""))

            //creates subscription and subscribes
            await hardhatClockSubscribe.connect(provider).createSubscription(eth, await hardhatCLOCKToken.getAddress(), details,1,1)

            let subscriptions = await hardhatClockSubscribe.connect(provider).getAccountSubscriptions(false, provider.address);

            //creates subscribe object
            const subscribeObject = {
                id: subscriptions[0].subscription[0],
                amount: subscriptions[0].subscription[1],
                provider: subscriptions[0].subscription[2],
                token: subscriptions[0].subscription[3],
                //exists: subscriptions[0].subscription[4],
                cancelled: subscriptions[0].subscription[4],
                frequency: subscriptions[0].subscription[5],
                dueDay: subscriptions[0].subscription[6]
            }

            await hardhatClockSubscribe.connect(subscriber).subscribe(subscribeObject)

            let ownerBalance1 = ethers.formatEther(await owner.provider.getBalance(owner.address))

            //collect fees
            //await hardhatClockSubscribe.collectFees()
            /*
            await hardhatClockSubscribe.connect(caller).remit()

            let ownerBalance2 = ethers.formatEther(await owner.provider.getBalance(owner.address))

            console.log(Number(ownerBalance1))
            console.log(Number(ownerBalance2))

            expect(Number(ownerBalance2) - Number(ownerBalance1)).to.greaterThan(0.01)
            */
            const tx = await hardhatClockSubscribe.connect(caller).remit()
            await expect(tx).to.changeTokenBalance(ethers, hardhatCLOCKToken, caller, convert(ethers.parseEther("0.018")))
            await expect(tx).to.changeTokenBalance(ethers, hardhatCLOCKToken, owner, convert(ethers.parseEther("0.002")))
        })
        it("Should refund provider on fail", async function() {
            
            const {hardhatCLOCKToken, hardhatClockSubscribe, subscriber, caller, provider} = await loadFixture(deployClocktowerFixture);

            const clockTokenAddress = await hardhatCLOCKToken.getAddress()

            const testParams = {
                value: eth
            };
            
            //adds CLOCK to approved tokens
            await hardhatClockSubscribe.addERC20Contract(clockTokenAddress, ethers.parseEther(".01"), ClockDecimals)

            //creates subscription and subscribes
            await hardhatClockSubscribe.connect(provider).createSubscription(eth, clockTokenAddress, details,1,1)
            
            let subscriptions = await hardhatClockSubscribe.connect(provider).getAccountSubscriptions(false, provider.address);

            //creates subscribe object
            const subscribeObject = {
                id: subscriptions[0].subscription[0],
                amount: subscriptions[0].subscription[1],
                provider: subscriptions[0].subscription[2],
                token: subscriptions[0].subscription[3],
                //exists: subscriptions[0].subscription[4],
                cancelled: subscriptions[0].subscription[4],
                frequency: subscriptions[0].subscription[5],
                dueDay: subscriptions[0].subscription[6]
            }

            await hardhatClockSubscribe.connect(subscriber).subscribe(subscribeObject)

            //otherAccount stops approval
            await hardhatCLOCKToken.connect(subscriber).approve(await hardhatClockSubscribe.getAddress(), 0)

            let subAmount = await hardhatCLOCKToken.balanceOf(subscriber.address)

            //await hardhatClockSubscribe.setExternalCallers(true)
            //console.log(await hardhatCLOCKToken.balanceOf(provider.address))
            //console.log(await hardhatCLOCKToken.balanceOf(provider.address))
            //console.log(await hardhatCLOCKToken.balanceOf(await hardhatClockSubscribe.getAddress()))

            //FAILED remit
            await expect(hardhatClockSubscribe.connect(caller).remit())
            .to.emit(hardhatClockSubscribe, "SubLog").withArgs(subscribeObject.id, subscribeObject.provider, subscriber.address, anyValue, subscribeObject.amount, clockTokenAddress, 7)

            //console.log(await hardhatCLOCKToken.balanceOf(await hardhatClockSubscribe.getAddress()))

            //check that provider has been refunded
            let provAmount = await hardhatCLOCKToken.balanceOf(provider.address)

            //checks caller
            let callerAmount = await hardhatCLOCKToken.balanceOf(caller.address)

            expect(ethers.formatEther(convertToWei(subAmount))).to.equal("99.98")
            expect(ethers.formatEther(convertToWei(provAmount))).to.equal("100.0")    
            expect(ethers.formatEther(convertToWei(callerAmount))).to.equal("100.0")  
            
            await hardhatClockSubscribe.connect(provider).createSubscription(eth, clockTokenAddress, details,1,2)
            let subscriptions2 = await hardhatClockSubscribe.connect(provider).getAccountSubscriptions(false, provider.address);

              //creates subscribe object
              const subscribeObject2 = {
                id: subscriptions2[1].subscription[0],
                amount: subscriptions2[1].subscription[1],
                provider: subscriptions2[1].subscription[2],
                token: subscriptions2[1].subscription[3],
                //exists: subscriptions2[1].subscription[4],
                cancelled: subscriptions2[1].subscription[4],
                frequency: subscriptions2[1].subscription[5],
                dueDay: subscriptions2[1].subscription[6]
            }

            await time.increase(dayAhead)

            await hardhatCLOCKToken.connect(subscriber).approve(await hardhatClockSubscribe.getAddress(), ethers.parseEther("100"))
            await hardhatClockSubscribe.connect(subscriber).subscribe(subscribeObject2)
            await hardhatCLOCKToken.connect(subscriber).approve(await hardhatClockSubscribe.getAddress(), 0)
            
            await expect(hardhatClockSubscribe.connect(caller).remit())
            .to.emit(hardhatClockSubscribe, "SubLog").withArgs(subscribeObject2.id, subscribeObject2.provider, subscriber.address, anyValue, subscribeObject.amount, clockTokenAddress, 3)
            

            await hardhatClockSubscribe.connect(provider).createSubscription(eth, await hardhatCLOCKToken.getAddress(), details,1,3)
            let subscriptions3 = await hardhatClockSubscribe.connect(provider).getAccountSubscriptions(false, provider.address);

             //creates subscribe object
             const subscribeObject3 = {
                id: subscriptions3[2].subscription[0],
                amount: subscriptions3[2].subscription[1],
                provider: subscriptions3[2].subscription[2],
                token: subscriptions3[2].subscription[3],
                //exists: subscriptions3[2].subscription[4],
                cancelled: subscriptions3[2].subscription[4],
                frequency: subscriptions3[2].subscription[5],
                dueDay: subscriptions3[2].subscription[6]
            }

            await time.increase(dayAhead)

            await hardhatCLOCKToken.connect(subscriber).approve(await hardhatClockSubscribe.getAddress(), ethers.parseEther("100"))
            await hardhatClockSubscribe.connect(subscriber).subscribe(subscribeObject3)
            await hardhatCLOCKToken.connect(subscriber).approve(await hardhatClockSubscribe.getAddress(), 0)

            
            await expect(hardhatClockSubscribe.connect(caller).remit())
            .to.emit(hardhatClockSubscribe, "SubLog").withArgs(subscribeObject3.id, provider.address, subscriber.address, anyValue, 0, clockTokenAddress, 3)
            

        })
        it("Should add and remove ERC20 Tokens", async function() {
            const {hardhatCLOCKToken, hardhatClockSubscribe, subscriber, caller, provider} = await loadFixture(deployClocktowerFixture);

            //adds CLOCK to approved tokens
            expect(await hardhatClockSubscribe.addERC20Contract(await hardhatCLOCKToken.getAddress(), ethers.parseEther(".01"), ClockDecimals))
        })
        it("Should remit transactions PART 1", async function() {
            const {hardhatCLOCKToken, hardhatClockSubscribe, subscriber, caller, provider} = await loadFixture(deployClocktowerFixture);

            const clockTokenAddress = await hardhatCLOCKToken.getAddress()

            //adds CLOCK to approved tokens
            await hardhatClockSubscribe.addERC20Contract(clockTokenAddress, ethers.parseEther(".01"), ClockDecimals)

            //creates subscription and subscribes
            await hardhatClockSubscribe.connect(provider).createSubscription(eth, clockTokenAddress, details,1,1)
             
            let subscriptions = await hardhatClockSubscribe.connect(provider).getAccountSubscriptions(false, provider.address);

             //creates subscribe object
             const subscribeObject = {
                id: subscriptions[0].subscription[0],
                amount: subscriptions[0].subscription[1],
                provider: subscriptions[0].subscription[2],
                token: subscriptions[0].subscription[3],
                //exists: subscriptions[0].subscription[4],
                cancelled: subscriptions[0].subscription[4],
                frequency: subscriptions[0].subscription[5],
                dueDay: subscriptions[0].subscription[6]
            }

            await hardhatClockSubscribe.connect(subscriber).subscribe(subscribeObject)

            //checks that only admin can call if bool is set
            /*
            await expect(hardhatClockSubscribe.connect(caller).remit())
            .to.be.rejectedWith("16")
            */

            //await hardhatClockSubscribe.setExternalCallers(true)
            await hardhatClockSubscribe.systemFeeActivate(true)

            /*
            //checks token fee is high enough
            await expect(hardhatClockSubscribe.connect(caller).remit())
            .to.be.rejectedWith("5")
            */

            await hardhatClockSubscribe.systemFeeActivate(false)

            //checks remit can't be called twice in same day
            await hardhatClockSubscribe.connect(caller).remit()
            await expect(hardhatClockSubscribe.connect(caller).remit())
            .to.be.rejectedWith("6")

            //moves to next day and sets 5 new subscriptions
            //await time.increase(dayAhead)
            await hardhatClockSubscribe.connect(provider).createSubscription(eth, clockTokenAddress, details,1,2)
            await hardhatClockSubscribe.connect(provider).createSubscription(eth, clockTokenAddress, details,1,2)
            await hardhatClockSubscribe.connect(provider).createSubscription(eth, clockTokenAddress, details,1,2)
            await hardhatClockSubscribe.connect(provider).createSubscription(eth, clockTokenAddress, details,1,2)
            await hardhatClockSubscribe.connect(provider).createSubscription(eth, clockTokenAddress, details,1,2)
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
                    //exists: subscriptions2[i].subscription[4],
                    cancelled: subscriptions2[i].subscription[4],
                    frequency: subscriptions2[i].subscription[5],
                    dueDay: subscriptions2[i].subscription[6]
                })
            }
            await hardhatClockSubscribe.connect(subscriber).subscribe(subArray2[1])
            await hardhatClockSubscribe.connect(subscriber).subscribe(subArray2[2])
            await hardhatClockSubscribe.connect(subscriber).subscribe(subArray2[3])
            await hardhatClockSubscribe.connect(subscriber).subscribe(subArray2[4])
            await hardhatClockSubscribe.connect(subscriber).subscribe(subArray2[5])

            //increases time after user subscribes so fee balance is not prorated to zero
            await time.increase(dayAhead)

            //checks that on max remit caller is paid and event is emitted
            const tx = await hardhatClockSubscribe.connect(caller).remit()
            await expect(tx).to.changeTokenBalance(ethers, hardhatCLOCKToken, caller, convert(ethers.parseEther("0.1")))
            await expect(tx).to.emit(hardhatClockSubscribe, "CallerLog").withArgs(anyValue, 21185, caller.address, true)

            //checks that successful transfer with enough fee balance
            //await time.increase((dayAhead))
            await hardhatClockSubscribe.connect(provider).createSubscription(eth, clockTokenAddress, details,1,3)
            let subscriptions3 = await hardhatClockSubscribe.connect(provider).getAccountSubscriptions(false, provider.address);
            const subscribeObject3 = {
                id: subscriptions3[6].subscription[0],
                amount: subscriptions3[6].subscription[1],
                provider: subscriptions3[6].subscription[2],
                token: subscriptions3[6].subscription[3],
                //exists: subscriptions3[6].subscription[4],
                cancelled: subscriptions3[6].subscription[4],
                frequency: subscriptions3[6].subscription[5],
                dueDay: subscriptions3[6].subscription[6]
            }

            await hardhatClockSubscribe.connect(subscriber).subscribe(subscribeObject3)

            await time.increase((dayAhead))
            
            const tx2 = await hardhatClockSubscribe.connect(caller).remit()
            await expect(tx2).to.changeTokenBalance(ethers, hardhatCLOCKToken, provider, convert(ethers.parseEther("1")))
            await expect(tx2).to.emit(hardhatClockSubscribe, "SubLog").withArgs(subscribeObject3.id, subscribeObject3.provider, subscriber.address, anyValue, subscribeObject3.amount, clockTokenAddress, 5)

            //await time.increase((dayAhead))
            await hardhatClockSubscribe.connect(provider).createSubscription(eth, clockTokenAddress, details,1,4)
            let subscriptions4 = await hardhatClockSubscribe.connect(provider).getAccountSubscriptions(false, provider.address);
            const subscribeObject4 = {
                id: subscriptions4[7].subscription[0],
                amount: subscriptions4[7].subscription[1],
                provider: subscriptions4[7].subscription[2],
                token: subscriptions4[7].subscription[3],
                //exists: subscriptions4[7].subscription[4],
                cancelled: subscriptions4[7].subscription[4],
                frequency: subscriptions4[7].subscription[5],
                dueDay: subscriptions4[7].subscription[6]
            }
            await hardhatClockSubscribe.connect(subscriber).subscribe(subscribeObject4)

            await time.increase((dayAhead))
            
            await expect(hardhatClockSubscribe.connect(caller).remit())
            .to.emit(hardhatClockSubscribe, "SubLog").withArgs(anyValue, provider.address, subscriber.address, anyValue, anyValue, clockTokenAddress, 2)

            //tests that subscribing before remittance prorates fee balance to a single day and then causes fee fill on remit() call
            await hardhatClockSubscribe.connect(provider).createSubscription(eth, clockTokenAddress, details,1,5)
            let subscriptions5 = await hardhatClockSubscribe.connect(provider).getAccountSubscriptions(false, provider.address);
            const subscribeObject5 = {
                id: subscriptions5[8].subscription[0],
                amount: subscriptions5[8].subscription[1],
                provider: subscriptions5[8].subscription[2],
                token: subscriptions5[8].subscription[3],
                //exists: subscriptions4[7].subscription[4],
                cancelled: subscriptions5[8].subscription[4],
                frequency: subscriptions5[8].subscription[5],
                dueDay: subscriptions5[8].subscription[6]
            }

            const clockSubsribeAddress = await hardhatClockSubscribe.getAddress()

            await time.increase((dayAhead))

            //console.log(ethers.formatEther(convertToWei(await hardhatCLOCKToken.balanceOf(clockSubsribeAddress))))

            //console.log(ethers.formatEther(convertToWei(await hardhatCLOCKToken.balanceOf(subscriber.address))))

            await hardhatClockSubscribe.connect(subscriber).subscribe(subscribeObject5)
            //console.log(ethers.formatEther(convertToWei(await hardhatCLOCKToken.balanceOf(subscriber.address))))
            await hardhatClockSubscribe.connect(caller).remit()
            //console.log(ethers.formatEther(convertToWei(await hardhatCLOCKToken.balanceOf(subscriber.address))))

            //console.log(ethers.formatEther(convertToWei(await hardhatCLOCKToken.balanceOf(clockSubsribeAddress))))

            //checks subscriber is not double charged
            expect(ethers.formatEther(convertToWei(await hardhatCLOCKToken.balanceOf(subscriber.address)))).to.equal("90.729868")
            await time.increase((dayAhead * 32))
            await hardhatClockSubscribe.connect(caller).remit()
            //checks fee balance has been increased
            expect(ethers.formatEther(convertToWei(await hardhatCLOCKToken.balanceOf(clockSubsribeAddress)))).to.equal("0.570132")

        })  
        it("Should remit transactions PART 2", async function() {

            const {hardhatCLOCKToken, hardhatClockSubscribe, subscriber, caller, provider} = await loadFixture(deployClocktowerFixture);

            const clockTokenAddress = await hardhatCLOCKToken.getAddress()
            const clockSubsribeAddress = await hardhatClockSubscribe.getAddress()

            //adds CLOCK to approved tokens
            await hardhatClockSubscribe.addERC20Contract(clockTokenAddress, ethers.parseEther(".01"), ClockDecimals)
            //await hardhatClockSubscribe.changeCallerFee(13000)
            await hardhatClockSubscribe.changeCallerFee(10800)
            //await hardhatClockSubscribe.setExternalCallers(true)

            //checks feefill events and token balances

            //checks subscriptions 90 days apart with depleted feeBalance

            await hardhatClockSubscribe.connect(provider).createSubscription(ethers.parseEther("3"), clockTokenAddress, details,2,1)
             
            let subscriptions = await hardhatClockSubscribe.connect(provider).getAccountSubscriptions(false, provider.address);

            const subscribeObject = {
                id: subscriptions[0].subscription[0],
                amount: subscriptions[0].subscription[1],
                provider: subscriptions[0].subscription[2],
                token: subscriptions[0].subscription[3],
                //exists: subscriptions[0].subscription[4],
                cancelled: subscriptions[0].subscription[4],
                frequency: subscriptions[0].subscription[5],
                dueDay: subscriptions[0].subscription[6]
            }

    
            await hardhatClockSubscribe.connect(subscriber).subscribe(subscribeObject)
            
            expect(ethers.formatEther(convertToWei(await hardhatCLOCKToken.balanceOf(subscriber.address)))).to.equal("99.76")
            expect(ethers.formatEther(convertToWei(await hardhatCLOCKToken.balanceOf(provider.address)))).to.equal("100.0")
            expect(ethers.formatEther(convertToWei(await hardhatCLOCKToken.balanceOf(caller.address)))).to.equal("100.0")
            expect(ethers.formatEther(convertToWei(await hardhatCLOCKToken.balanceOf(clockSubsribeAddress)))).to.equal("0.24")

            //feefill
            expect(await hardhatClockSubscribe.connect(caller).remit())

            expect(ethers.formatEther(convertToWei(await hardhatCLOCKToken.balanceOf(subscriber.address)))).to.equal("96.76")
            expect(ethers.formatEther(convertToWei(await hardhatCLOCKToken.balanceOf(provider.address)))).to.equal("102.75")
            //expect(ethers.formatEther(await hardhatCLOCKToken.balanceOf(caller.address))).to.equal("100.9")
            expect(ethers.formatEther(convertToWei(await hardhatCLOCKToken.balanceOf(caller.address)))).to.equal("100.24")
            //expect(ethers.formatEther(await hardhatCLOCKToken.balanceOf(clockSubsribeAddress))).to.equal("0.1")
            expect(ethers.formatEther(convertToWei(await hardhatCLOCKToken.balanceOf(clockSubsribeAddress)))).to.equal("0.25")
            
            await time.increase((dayAhead * 95))

            //********** */

            // fee fill has already been checked 

            /*
            //loops through remittances until fee balance is empty
            expect(await hardhatClockSubscribe.connect(caller).remit())

            //console.log(await hardhatCLOCKToken.balanceOf(provider.address))

            await time.increase((dayAhead * 95))

            expect(await hardhatClockSubscribe.connect(caller).remit())

            //console.log(await hardhatCLOCKToken.balanceOf(provider.address))

            await time.increase((dayAhead * 95))

            expect(await hardhatClockSubscribe.connect(caller).remit())

            //console.log(await hardhatCLOCKToken.balanceOf(provider.address))

            await time.increase((dayAhead * 95))
            */

            //-----------------

            /*
            await expect(hardhatClockSubscribe.connect(caller).remit())
            .to.changeTokenBalance(ethers, hardhatCLOCKToken, provider, ethers.parseEther("2"))
            .to.emit(hardhatClockSubscribe, "SubLog").withArgs(subscriptions[0].subscription.id, subscriptions[0].subscription.provider, subscriber.address, anyValue, subscriptions[0].subscription.amount, clockTokenAddress, 8)
            */

            /*
            //checks that fee fill has been completed and provider only receives prorated amount 
            const tx = await hardhatClockSubscribe.connect(caller).remit()
            await expect(tx).to.changeTokenBalance(ethers, hardhatCLOCKToken, provider, convert(ethers.parseEther("2")))
            await expect(tx).to.emit(hardhatClockSubscribe, "SubLog").withArgs(subscribeObject.id, subscribeObject.provider, subscriber.address, anyValue, subscribeObject.amount, clockTokenAddress, 8)

            
            expect(ethers.formatEther(convertToWei(await hardhatCLOCKToken.balanceOf(caller.address)))).to.equal("101.24")
            //expect(ethers.formatEther(await hardhatCLOCKToken.balanceOf(subscriber.address))).to.equal("91.0")
            expect(ethers.formatEther(convertToWei(await hardhatCLOCKToken.balanceOf(subscriber.address)))).to.equal("82.0")
            //expect(ethers.formatEther(await hardhatCLOCKToken.balanceOf(provider.address))).to.equal("107.0")
            expect(ethers.formatEther(convertToWei(await hardhatCLOCKToken.balanceOf(provider.address)))).to.equal("116.0")
            expect(ethers.formatEther(convertToWei(await hardhatCLOCKToken.balanceOf(clockSubsribeAddress)))).to.equal("0.76") 
            */
        })
        it("Prorate when subscribing", async function() { 

            const {hardhatCLOCKToken, hardhatClockSubscribe, subscriber, caller, provider} = await loadFixture(deployClocktowerFixture);
            const clockTokenAddress = await hardhatCLOCKToken.getAddress()

            await hardhatClockSubscribe.addERC20Contract(clockTokenAddress, ethers.parseEther(".01"), ClockDecimals)
            //await hardhatClockSubscribe.setExternalCallers(true)
    
            //checks weekly subscription
            await hardhatClockSubscribe.connect(provider).createSubscription(ethers.parseEther("7"), clockTokenAddress, details,0,3)
                 
            let subscriptions = await hardhatClockSubscribe.connect(provider).getAccountSubscriptions(false, provider.address);

            const subscribeObject = {
                id: subscriptions[0].subscription[0],
                amount: subscriptions[0].subscription[1],
                provider: subscriptions[0].subscription[2],
                token: subscriptions[0].subscription[3],
                //exists: subscriptions[0].subscription[4],
                cancelled: subscriptions[0].subscription[4],
                frequency: subscriptions[0].subscription[5],
                dueDay: subscriptions[0].subscription[6]
            }

            await time.increase((dayAhead * 5))
    
            await expect(hardhatClockSubscribe.connect(subscriber).subscribe(subscribeObject))
            .to.changeTokenBalance(ethers, hardhatCLOCKToken, subscriber, convert(ethers.parseEther("-6")))


            //checks monthly subscription
            await hardhatClockSubscribe.connect(provider).createSubscription(ethers.parseEther("1"), clockTokenAddress, details,1,5)
                 
            let subscriptions2 = await hardhatClockSubscribe.connect(provider).getAccountSubscriptions(false, provider.address);

            const subscribeObject2 = {
                id: subscriptions2[1].subscription[0],
                amount: subscriptions2[1].subscription[1],
                provider: subscriptions2[1].subscription[2],
                token: subscriptions2[1].subscription[3],
                //exists: subscriptions2[1].subscription[4],
                cancelled: subscriptions2[1].subscription[4],
                frequency: subscriptions2[1].subscription[5],
                dueDay: subscriptions2[1].subscription[6]
            }

            await time.increase((dayAhead * 20))

            await expect(hardhatClockSubscribe.connect(subscriber).subscribe(subscribeObject2))
            .to.changeTokenBalance(ethers, hardhatCLOCKToken, subscriber, convert(ethers.parseEther("-0.32876712328767123")))

            //checks quarterly subscription
            await hardhatClockSubscribe.connect(provider).createSubscription(ethers.parseEther("1"), clockTokenAddress, details,2,5)
                 
            let subscriptions3 = await hardhatClockSubscribe.connect(provider).getAccountSubscriptions(false, provider.address);

            /*
            const subscribeObject3= {
                id: subscriptions3[1].subscription[0],
                amount: subscriptions3[1].subscription[1],
                provider: subscriptions3[1].subscription[2],
                token: subscriptions3[1].subscription[3],
                //exists: subscriptions3[1].subscription[4],
                cancelled: subscriptions3[1].subscription[4],
                frequency: subscriptions3[1].subscription[5],
                dueDay: subscriptions3[1].subscription[6]
            }
            */

            const subscribeObject3= {
                id: subscriptions3[2].subscription[0],
                amount: subscriptions3[2].subscription[1],
                provider: subscriptions3[2].subscription[2],
                token: subscriptions3[2].subscription[3],
                //exists: subscriptions3[1].subscription[4],
                cancelled: subscriptions3[2].subscription[4],
                frequency: subscriptions3[2].subscription[5],
                dueDay: subscriptions3[2].subscription[6]
            }

            //twenty days into the period. (25 - 5 days)
            await time.increase((dayAhead * 90))

            await expect(hardhatClockSubscribe.connect(subscriber).subscribe(subscribeObject3))
            //.to.changeTokenBalance(hardhatCLOCKToken, subscriber, convert(ethers.parseEther("-0.32876712328767123")))
            .to.changeTokenBalance(ethers, hardhatCLOCKToken, subscriber, convert(ethers.parseEther("-0.77777777")))

            //checks yearly subscription
            
            await hardhatClockSubscribe.connect(provider).createSubscription(ethers.parseEther("1"), clockTokenAddress, details,3,5)
                 
            let subscriptions4 = await hardhatClockSubscribe.connect(provider).getAccountSubscriptions(false, provider.address);

            const subscribeObject4= {
                id: subscriptions4[3].subscription[0],
                amount: subscriptions4[3].subscription[1],
                provider: subscriptions4[3].subscription[2],
                token: subscriptions4[3].subscription[3],
                //exists: subscriptions4[1].subscription[4],
                cancelled: subscriptions4[3].subscription[4],
                frequency: subscriptions4[3].subscription[5],
                dueDay: subscriptions4[3].subscription[6]
            }
 
            await time.increase((dayAhead * 365))

           // console.log(await time.latest())

            //checks 225 days remaining in year 365 - (25 + 90)
            await expect(hardhatClockSubscribe.connect(subscriber).subscribe(subscribeObject4))
            //.to.changeTokenBalance(hardhatCLOCKToken, subscriber, convert(ethers.parseEther("-0.32876712328767123")))
            .to.changeTokenBalance(ethers, hardhatCLOCKToken, subscriber, convert(ethers.parseEther("-0.698630")))

            /*
            //need to cehck that proration is zero if duedate == subsscribe date and remit has not been called. 
            console.log(await hardhatClockSubscribe.connect(provider).nextUncheckedDay())

            await hardhatClockSubscribe.connect(provider).createSubscription(ethers.parseEther("7"), clockTokenAddress, details,0,3)
            let subscriptionsZ = await hardhatClockSubscribe.connect(provider).getAccountSubscriptions(false, provider.address);

            const subscribeObjectZ = {
                id: subscriptionsZ[4].subscription[0],
                amount: subscriptionsZ[4].subscription[1],
                provider: subscriptionsZ[4].subscription[2],
                token: subscriptionsZ[4].subscription[3],
                //exists: subscriptions[0].subscription[4],
                cancelled: subscriptionsZ[4].subscription[4],
                frequency: subscriptionsZ[4].subscription[5],
                dueDay: subscriptionsZ[4].subscription[6]
            }

            console.log(subscribeObjectZ.dueDay)

            await hardhatClockSubscribe.connect(subscriber).subscribe(subscribeObjectZ)


            const latestTimestamp = await time.latest();
            const date = new Date(latestTimestamp * 1000);
            const currentDay = date.getDay();

            console.log(currentDay)
            */

        })
        it("Gets fee info from public getter functions", async function() { 
            const {hardhatCLOCKToken, hardhatClockSubscribe, subscriber, caller, provider, otherAccount} = await loadFixture(deployClocktowerFixture);

            const clockTokenAddress = await hardhatCLOCKToken.getAddress()
            await hardhatClockSubscribe.addERC20Contract(clockTokenAddress, ethers.parseEther(".01"), ClockDecimals)
            //await hardhatClockSubscribe.setExternalCallers(true)

            //creates subscription and subscribes
            await hardhatClockSubscribe.connect(provider).createSubscription(eth, clockTokenAddress, details,1,1)
             
            let subscriptions = await hardhatClockSubscribe.connect(provider).getAccountSubscriptions(false, provider.address);

            const subscribeObject = {
                id: subscriptions[0].subscription[0],
                amount: subscriptions[0].subscription[1],
                provider: subscriptions[0].subscription[2],
                token: subscriptions[0].subscription[3],
                //exists: subscriptions[0].subscription[4],
                cancelled: subscriptions[0].subscription[4],
                frequency: subscriptions[0].subscription[5],
                dueDay: subscriptions[0].subscription[6]
            }

            await hardhatClockSubscribe.connect(subscriber).subscribe(subscribeObject)
            await hardhatClockSubscribe.connect(otherAccount).subscribe(subscribeObject)

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

            //checks day of
        })
        it("Gets token minimum from contract", async function() { 
            const {hardhatCLOCKToken, hardhatClockSubscribe, subscriber, caller, provider, otherAccount} = await loadFixture(deployClocktowerFixture);
            const clockTokenAddress = await hardhatCLOCKToken.getAddress()

            await hardhatClockSubscribe.addERC20Contract(clockTokenAddress, ethers.parseEther(".01"), ClockDecimals)

            let tokenObject = await hardhatClockSubscribe.connect(provider).approvedERC20(clockTokenAddress)

            expect(tokenObject.minimum).to.equal(ethers.parseEther(".01"))
        })
        it("Changes transferred amounts based on erc20 decimals", async function (){
            const {hardhatCLOCKToken, hardhatClockSubscribe, subscriber, caller, provider, otherAccount, owner} = await loadFixture(deployClocktowerFixture);
            const clockTokenAddress = await hardhatCLOCKToken.getAddress()

            //changes decimal to 6
            await hardhatClockSubscribe.addERC20Contract(clockTokenAddress, ethers.parseEther(".01"), 6)

            let balance1 = await hardhatCLOCKToken.balanceOf(subscriber.address)
            //console.log(balance1)

            //monthly
            await hardhatClockSubscribe.connect(provider).createSubscription(eth, clockTokenAddress, details,1,15)
            //quarterly
            await hardhatClockSubscribe.connect(provider).createSubscription(eth, clockTokenAddress, details,2,15)

            let subscriptions = await hardhatClockSubscribe.connect(provider).getAccountSubscriptions(false, provider.address)

            //checks contract saved subscription amount is in 10^18 decimal format
            expect(subscriptions[0].subscription.amount).to.equal(eth);

             //creates subscribe object
             const subscribeObject = {
                id: subscriptions[0].subscription[0],
                amount: subscriptions[0].subscription[1],
                provider: subscriptions[0].subscription[2],
                token: subscriptions[0].subscription[3],
                //exists: subscriptions[0].subscription[4],
                cancelled: subscriptions[0].subscription[4],
                frequency: subscriptions[0].subscription[5],
                dueDay: subscriptions[0].subscription[6]
            }

              //creates subscribe object2
              const subscribeObject2 = {
                id: subscriptions[1].subscription[0],
                amount: subscriptions[1].subscription[1],
                provider: subscriptions[1].subscription[2],
                token: subscriptions[1].subscription[3],
                //exists: subscriptions[1].subscription[4],
                cancelled: subscriptions[1].subscription[4],
                frequency: subscriptions[1].subscription[5],
                dueDay: subscriptions[1].subscription[6]
            }

            //checks monthly token decimal conversion works
            await expect(hardhatClockSubscribe.connect(subscriber).subscribe(subscribeObject))
            .changeTokenBalance(ethers, hardhatCLOCKToken, subscriber.address, -460273n)

            let balance2 = await hardhatCLOCKToken.balanceOf(subscriber.address)
            //console.log(balance2)
            //console.log((balance1 - balance2))

            //test quarterly token decimal conversion works and takes from subscriber and funds both contract and provider
            const tx = hardhatClockSubscribe.connect(subscriber).subscribe(subscribeObject2)
            await expect(tx).to.changeTokenBalance(ethers, hardhatCLOCKToken, subscriber.address, -155555n)
            await expect(tx).to.changeTokenBalance(ethers, hardhatCLOCKToken, await hardhatClockSubscribe.getAddress(), 83000n)
            await expect(tx).to.changeTokenBalance(ethers, hardhatCLOCKToken, provider.address, 72555n)

            let balance3 = await hardhatCLOCKToken.balanceOf(subscriber.address)
            //console.log(balance3)
            //console.log((balance2 - balance3))

        })
        it("Allows the admin user to set the starting location of remittances", async function() {
            const {hardhatCLOCKToken, hardhatClockSubscribe, subscriber, caller, provider, otherAccount, owner} = await loadFixture(deployClocktowerFixture);

            let remits = 5

            //sets remits to 5
            expect(await hardhatClockSubscribe.changeMaxRemits(remits))

            //allows external callers
            //await hardhatClockSubscribe.setExternalCallers(true)

            //adds CLOCK to approved tokens
            await hardhatClockSubscribe.addERC20Contract(await hardhatCLOCKToken.getAddress(), ethers.parseEther(".01"), ClockDecimals)

            await hardhatClockSubscribe.connect(provider).createSubscription(eth, await hardhatCLOCKToken.getAddress(), details,1,1)
            await hardhatClockSubscribe.connect(provider).createSubscription(eth, await hardhatCLOCKToken.getAddress(), details,1,1)
            await hardhatClockSubscribe.connect(provider).createSubscription(eth, await hardhatCLOCKToken.getAddress(), details,1,1)
            await hardhatClockSubscribe.connect(provider).createSubscription(eth, await hardhatCLOCKToken.getAddress(), details,1,1)
            await hardhatClockSubscribe.connect(provider).createSubscription(eth, await hardhatCLOCKToken.getAddress(), details,1,1)
            await hardhatClockSubscribe.connect(provider).createSubscription(eth, await hardhatCLOCKToken.getAddress(), details,1,1)
            await hardhatClockSubscribe.connect(provider).createSubscription(eth, await hardhatCLOCKToken.getAddress(), details,1,1)

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
                    //exists: subscriptions[i].subscription[4],
                    cancelled: subscriptions[i].subscription[4],
                    frequency: subscriptions[i].subscription[5],
                    dueDay: subscriptions[i].subscription[6]
                })
            }

            //console.log(await hardhatCLOCKToken.balanceOf(subscriber.address))

            await hardhatClockSubscribe.connect(subscriber).subscribe(subArray[0])
            await hardhatClockSubscribe.connect(subscriber).subscribe(subArray[1])
            await hardhatClockSubscribe.connect(subscriber).subscribe(subArray[2])
            await hardhatClockSubscribe.connect(subscriber).subscribe(subArray[3])
            await hardhatClockSubscribe.connect(subscriber).subscribe(subArray[4])
            await hardhatClockSubscribe.connect(subscriber).subscribe(subArray[5])
            await hardhatClockSubscribe.connect(subscriber).subscribe(subArray[6])

            //console.log(subArray[0].id)

             //gets next unchecked day number
             const nextUncheckedDay4 = await hardhatClockSubscribe.nextUncheckedDay();

             //console.log(nextUncheckedDay4)
 
            
            await time.increaseTo(twoHoursAhead);

            let subscribersId = await hardhatClockSubscribe.getSubscribersById(subArray[0].id)

            expect(subscribersId[0].subscriber).to.equal("0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC")
            expect(ethers.formatEther(subscribersId[0].feeBalance)).to.equal("0.02")

            let isFinished = false
            let pageCounter = 0



            //balance befoe remmitance
            //console.log(await hardhatCLOCKToken.balanceOf(subscriber.address))
            await hardhatClockSubscribe.connect(caller).remit();
            const coordinateDay = await hardhatClockSubscribe.nextUncheckedDay();
             //gets next unchecked day number
              //console.log(await hardhatCLOCKToken.balanceOf(subscriber.address))
            await hardhatClockSubscribe.connect(caller).remit();
              //console.log(await hardhatCLOCKToken.balanceOf(subscriber.address))

            let otherBalance = await hardhatCLOCKToken.balanceOf(subscriber.address)

            let expected = ethers.parseEther("92.86");

            //gets fee balance
            expect(ethers.formatEther(await hardhatClockSubscribe.feeBalance(subArray[0].id,subscriber.address))).to.equal("0.25")

            expect(otherBalance).to.equal(convert(expected))

            //resets remittance to beginning
            await hardhatClockSubscribe.connect(owner).setNextUncheckedDay(coordinateDay)

            //balance befoe remmitance
            //console.log(await hardhatCLOCKToken.balanceOf(subscriber.address))
            await hardhatClockSubscribe.connect(caller).remit();
            //console.log(await hardhatCLOCKToken.balanceOf(subscriber.address))
            await hardhatClockSubscribe.connect(caller).remit();
           // console.log(await hardhatCLOCKToken.balanceOf(subscriber.address))
            expect(await hardhatCLOCKToken.balanceOf(subscriber.address)).to.equal(convert(ethers.parseEther("85.86")))

            //resets remittance to beginning
            await hardhatClockSubscribe.connect(owner).setNextUncheckedDay(coordinateDay)

            const pageStart = {
                id: subArray[5].id,
                subscriberIndex: 1,
                subscriptionIndex: 7,
                frequency: 1,
                initialized: true
            }
            //sets coordinates within day ahead
            await hardhatClockSubscribe.connect(owner).setPageStart(pageStart)


            //balance before remmitance
            //console.log(await hardhatCLOCKToken.balanceOf(subscriber.address))
            await hardhatClockSubscribe.connect(caller).remit();
            //console.log(await hardhatCLOCKToken.balanceOf(subscriber.address))
            await hardhatClockSubscribe.connect(caller).remit();
           // console.log(await hardhatCLOCKToken.balanceOf(subscriber.address))
            expect(await hardhatCLOCKToken.balanceOf(subscriber.address)).to.equal(convert(ethers.parseEther("79.86")))

        })
        it("Restricts the ownership functions to the owner and transfers with two step", async function() {
            const {hardhatCLOCKToken, hardhatClockSubscribe, subscriber, caller, provider, otherAccount, owner} = await loadFixture(deployClocktowerFixture);

            //checks that admin rights are protected
            await expect(hardhatClockSubscribe.connect(subscriber).addERC20Contract(await hardhatCLOCKToken.getAddress(), ethers.parseEther(".01"), ClockDecimals)).to.be.revertedWithCustomError(hardhatClockSubscribe, "AccessControlUnauthorizedAccount");

            //transfers ownership
            //expect( await hardhatClockSubscribe.connect(owner).transferOwnership(otherAccount))
            //expect( await hardhatClockSubscribe.connect(owner).grantRole(await hardhatClockSubscribe.DEFAULT_ADMIN_ROLE(), otherAccount))
            expect( await hardhatClockSubscribe.connect(owner).beginDefaultAdminTransfer(otherAccount))

            //moves forward time a day
            await time.increase((dayAhead * 2))

            //should still block 
            await expect(hardhatClockSubscribe.connect(otherAccount).addERC20Contract(await hardhatCLOCKToken.getAddress(), ethers.parseEther(".01"), ClockDecimals)).to.be.revertedWithCustomError(hardhatClockSubscribe, "1");

            //accepts transfer
            expect( await hardhatClockSubscribe.connect(otherAccount).acceptDefaultAdminTransfer())

            //now blocks old owner
            await expect(hardhatClockSubscribe.connect(owner).addERC20Contract(await hardhatCLOCKToken.getAddress(), ethers.parseEther(".01"), ClockDecimals)).to.be.revertedWithCustomError(hardhatClockSubscribe, "1");

            //allows new owner to run protected functions
            expect( await hardhatClockSubscribe.connect(otherAccount).changeMaxRemits(5))

        })
        it("Allows for tokens to be paused and unpaused", async function() {
            const {hardhatCLOCKToken, hardhatClockSubscribe, subscriber, caller, provider, otherAccount, owner} = await loadFixture(deployClocktowerFixture);

            //adds CLOCK to approved tokens
            await hardhatClockSubscribe.addERC20Contract(await hardhatCLOCKToken.getAddress(), ethers.parseEther(".01"), ClockDecimals)

            //creates subscriptions
            await hardhatClockSubscribe.connect(provider).createSubscription(eth, await hardhatCLOCKToken.getAddress(), details,1,1)
            await hardhatClockSubscribe.connect(provider).createSubscription(eth, await hardhatCLOCKToken.getAddress(), details,1,1)
            await hardhatClockSubscribe.connect(provider).createSubscription(eth, await hardhatCLOCKToken.getAddress(), details,1,1)

            let subscriptions = await hardhatClockSubscribe.connect(provider).getAccountSubscriptions(false, provider.address);


            let subArray =[]

            //subscriptions
            for (let i = 0; i < subscriptions.length; i++) {
                subArray.push({
                    id: subscriptions[i].subscription[0],
                    amount: subscriptions[i].subscription[1],
                    provider: subscriptions[i].subscription[2],
                    token: subscriptions[i].subscription[3],
                    cancelled: subscriptions[i].subscription[4],
                    frequency: subscriptions[i].subscription[5],
                    dueDay: subscriptions[i].subscription[6]
                })
            }

            await hardhatClockSubscribe.connect(subscriber).subscribe(subArray[0])
            await hardhatClockSubscribe.connect(subscriber).subscribe(subArray[1])
            await hardhatClockSubscribe.connect(subscriber).subscribe(subArray[2])
            
            //tries to unpause token that isn't paused
            await expect(hardhatClockSubscribe.connect(owner).pauseToken(hardhatCLOCKToken.getAddress(), false)).to.be.revertedWithoutReason(ethers);

            //pauses token 
            expect( await hardhatClockSubscribe.connect(owner).pauseToken(hardhatCLOCKToken.getAddress(), true))

            const preRemit = await hardhatCLOCKToken.balanceOf(subscriber.address)

            //remit is called and shouldn't make any payments since all subscriptions have paused tokens
            await hardhatClockSubscribe.connect(caller).remit();

            //subscriber balance hasn't changed
            expect( await hardhatCLOCKToken.balanceOf(subscriber.address)).to.be.equal(preRemit);

            //fast forward a month
            await time.increase((dayAhead * 32))

            //unpauses token 
            expect( await hardhatClockSubscribe.connect(owner).pauseToken(hardhatCLOCKToken.getAddress(), false))

            //remit is called and shouldn't make any payments since all subscriptions have paused tokens
            await hardhatClockSubscribe.connect(caller).remit();

            //subscriber balance to decrease
            expect( await hardhatCLOCKToken.balanceOf(subscriber.address)).to.be.equal(convert(ethers.parseEther("96.94")));


        })
        it("Allows janitor to cleanup subscriptions in cancelled subs", async function() {
            const {hardhatCLOCKToken, hardhatClockSubscribe, subscriber, caller, provider, otherAccount, owner} = await loadFixture(deployClocktowerFixture);

            //adds CLOCK to approved tokens
            await hardhatClockSubscribe.addERC20Contract(await hardhatCLOCKToken.getAddress(), ethers.parseEther(".01"), ClockDecimals)

            //creates subscriptions
            await hardhatClockSubscribe.connect(provider).createSubscription(eth, await hardhatCLOCKToken.getAddress(), details,1,1)

            let subscriptions = await hardhatClockSubscribe.connect(provider).getAccountSubscriptions(false, provider.address);


            let subArray =[]

            //subscriptions
            for (let i = 0; i < subscriptions.length; i++) {
                subArray.push({
                    id: subscriptions[i].subscription[0],
                    amount: subscriptions[i].subscription[1],
                    provider: subscriptions[i].subscription[2],
                    token: subscriptions[i].subscription[3],
                    cancelled: subscriptions[i].subscription[4],
                    frequency: subscriptions[i].subscription[5],
                    dueDay: subscriptions[i].subscription[6]
                })
            }


            await hardhatClockSubscribe.connect(subscriber).subscribe(subArray[0])
            await hardhatClockSubscribe.connect(otherAccount).subscribe(subArray[0])

            //cancels subscription
            await hardhatClockSubscribe.connect(provider).cancelSubscription(subArray[0])
            

            //checks that its actually the janitor
            await expect(hardhatClockSubscribe.connect(subscriber).cleanupCancelledSubscribers(subArray[0])).to.be.rejectedWith("8")

            let account2 = await hardhatClockSubscribe.connect(subscriber).getAccount(subscriber)

            //expect(account2.subscriptions).to.be.empty

            expect( await hardhatClockSubscribe.connect(otherAccount).cleanupCancelledSubscribers(subArray[0]))

            let account = await hardhatClockSubscribe.connect(subscriber).getAccount(subscriber)
            let account3 = await hardhatClockSubscribe.connect(otherAccount).getAccount(otherAccount)

            //checks that it unsubscribes
            expect(account.subscriptions[0].status).to.be.equal(1n)
            expect(account3.subscriptions[0].status).to.be.equal(1n)

            //creates subscriptions
            await hardhatClockSubscribe.connect(provider).createSubscription(eth, await hardhatCLOCKToken.getAddress(), details,1,1)
            
            let subscriptions2 = await hardhatClockSubscribe.connect(provider).getAccountSubscriptions(false, provider.address);

            let subArray2 =[]

            //subscriptions
            for (let i = 0; i < subscriptions2.length; i++) {
                subArray2.push({
                    id: subscriptions2[i].subscription[0],
                    amount: subscriptions2[i].subscription[1],
                    provider: subscriptions2[i].subscription[2],
                    token: subscriptions2[i].subscription[3],
                    cancelled: subscriptions2[i].subscription[4],
                    frequency: subscriptions2[i].subscription[5],
                    dueDay: subscriptions2[i].subscription[6]
                })
            }

            await hardhatClockSubscribe.connect(subscriber).subscribe(subArray2[1])
            await hardhatClockSubscribe.connect(otherAccount).subscribe(subArray2[1])

            //sets cancel limit lower than subscribers
            await hardhatClockSubscribe.connect(owner).setCancelLimit(1n)

             //cancels subscription
             await hardhatClockSubscribe.connect(provider).cancelSubscription(subArray2[1])

            expect( await hardhatClockSubscribe.connect(otherAccount).cleanupCancelledSubscribers(subArray2[1]))

            let account4 = await hardhatClockSubscribe.connect(subscriber).getAccount(subscriber)
            let account5 = await hardhatClockSubscribe.connect(otherAccount).getAccount(otherAccount)

            //checks that it unsubscribes only one
            expect(account4.subscriptions[1].status).to.be.equal(0)
            expect(account5.subscriptions[1].status).to.be.equal(1n)

        })
        it("Allows janitor to cleanup unsubscribed mapping", async function() {
            const {hardhatCLOCKToken, hardhatClockSubscribe, subscriber, caller, provider, otherAccount, owner, subscriber2, subscriber3, subscriber4, subscriber5} = await loadFixture(deployClocktowerFixture);

            //adds CLOCK to approved tokens
            await hardhatClockSubscribe.addERC20Contract(await hardhatCLOCKToken.getAddress(), ethers.parseEther(".01"), ClockDecimals)

            //creates subscriptions
            await hardhatClockSubscribe.connect(provider).createSubscription(eth, await hardhatCLOCKToken.getAddress(), details,1,1)

            let subscriptions = await hardhatClockSubscribe.connect(provider).getAccountSubscriptions(false, provider.address);

            let subArray =[]

            //subscriptions
            for (let i = 0; i < subscriptions.length; i++) {
                subArray.push({
                    id: subscriptions[i].subscription[0],
                    amount: subscriptions[i].subscription[1],
                    provider: subscriptions[i].subscription[2],
                    token: subscriptions[i].subscription[3],
                    cancelled: subscriptions[i].subscription[4],
                    frequency: subscriptions[i].subscription[5],
                    dueDay: subscriptions[i].subscription[6]
                })
            }

            await hardhatClockSubscribe.connect(subscriber).subscribe(subArray[0])
            await hardhatClockSubscribe.connect(subscriber2).subscribe(subArray[0])
            await hardhatClockSubscribe.connect(subscriber3).subscribe(subArray[0])

            //unsubscribes during pagination
            const pageStart = {
                id: subArray[0].id,
                subscriberIndex: 3,
                subscriptionIndex: 1,
                frequency: 1,
                initialized: true
            }

            //checks that in a paginated state the subscriber stays in the list but is added to the unsubscribe map
            await hardhatClockSubscribe.connect(owner).setPageStart(pageStart)

            await hardhatClockSubscribe.connect(subscriber).unsubscribe(subArray[0])
            await hardhatClockSubscribe.connect(subscriber2).unsubscribe(subArray[0])
            await hardhatClockSubscribe.connect(subscriber3).unsubscribe(subArray[0])

            expect(await hardhatClockSubscribe.getUnsubscribedLength(subArray[0].id)).to.be.equal(3)

            //sets cancelLimit to 2
            await hardhatClockSubscribe.connect(owner).setCancelLimit(2n)

            //still paginating so it wont work
            await expect(hardhatClockSubscribe.connect(otherAccount).cleanUnsubscribeList(subArray[0].id)).to.be.revertedWithoutReason(ethers)

            //turns off pagination
            const pageStart2 = {
                id: ethers.ZeroHash,
                subscriberIndex: 0,
                subscriptionIndex: 0,
                frequency: 0,
                initialized: false
            }
            await hardhatClockSubscribe.connect(owner).setPageStart(pageStart2)

            await hardhatClockSubscribe.connect(otherAccount).cleanUnsubscribeList(subArray[0].id)
            
            expect(await hardhatClockSubscribe.getUnsubscribedLength(subArray[0].id)).to.be.equal(1)

            await hardhatClockSubscribe.connect(otherAccount).cleanUnsubscribeList(subArray[0].id)

            expect(await hardhatClockSubscribe.getUnsubscribedLength(subArray[0].id)).to.be.equal(0)

        })
        it("Order the subscribers correctly when remitting", async function() {
            const {hardhatCLOCKToken, hardhatClockSubscribe, subscriber, caller, provider, otherAccount, owner, subscriber2, subscriber3, subscriber4, subscriber5} = await loadFixture(deployClocktowerFixture);

            //adds CLOCK to approved tokens
            await hardhatClockSubscribe.addERC20Contract(await hardhatCLOCKToken.getAddress(), ethers.parseEther(".01"), ClockDecimals)

            //creates subscriptions
            await hardhatClockSubscribe.connect(provider).createSubscription(eth, await hardhatCLOCKToken.getAddress(), details,1,1)

            let subscriptions = await hardhatClockSubscribe.connect(provider).getAccountSubscriptions(false, provider.address);

            let subArray =[]

            //subscriptions
            for (let i = 0; i < subscriptions.length; i++) {
                subArray.push({
                    id: subscriptions[i].subscription[0],
                    amount: subscriptions[i].subscription[1],
                    provider: subscriptions[i].subscription[2],
                    token: subscriptions[i].subscription[3],
                    cancelled: subscriptions[i].subscription[4],
                    frequency: subscriptions[i].subscription[5],
                    dueDay: subscriptions[i].subscription[6]
                })
            }

            await hardhatClockSubscribe.connect(subscriber).subscribe(subArray[0])
            await hardhatClockSubscribe.connect(subscriber2).subscribe(subArray[0])
            await hardhatClockSubscribe.connect(subscriber3).subscribe(subArray[0])
            await hardhatClockSubscribe.connect(subscriber4).subscribe(subArray[0])
            await hardhatClockSubscribe.connect(subscriber5).subscribe(subArray[0])

            await hardhatClockSubscribe.connect(owner).changeMaxRemits(3n)

            //revokes approval in subscriber 2 and 3
            await hardhatCLOCKToken.connect(subscriber3).approve(hardhatClockSubscribe.getAddress(), 0n)
            await hardhatCLOCKToken.connect(subscriber2).approve(hardhatClockSubscribe.getAddress(), 0n)
            
            //checks that it emits the first three coordinates
            const tx = await hardhatClockSubscribe.connect(caller).remit()
            await expect(tx).to.emit(hardhatClockSubscribe, "Coordinates").withArgs(subArray[0].id, 5, 1, 1, anyValue)
            await expect(tx).to.emit(hardhatClockSubscribe, "Coordinates").withArgs(subArray[0].id, 4, 1, 1, anyValue)
            await expect(tx).to.emit(hardhatClockSubscribe, "Coordinates").withArgs(subArray[0].id, 3, 1, 1, anyValue)
            

            //await hardhatClockSubscribe.connect(caller).remit();
            const tx2 = await hardhatClockSubscribe.connect(caller).remit()
            await expect(tx2).to.emit(hardhatClockSubscribe, "Coordinates").withArgs(subArray[0].id, 2, 1, 1, anyValue)
            await expect(tx2).to.emit(hardhatClockSubscribe, "Coordinates").withArgs(subArray[0].id, 1, 1, 1, anyValue)

            //unsubscribed
            expect(await hardhatCLOCKToken.balanceOf(subscriber3.address)).to.be.equal(convert(ethers.parseEther("99.98")))
            //normal
            expect(await hardhatCLOCKToken.balanceOf(subscriber4.address)).to.be.equal(convert(ethers.parseEther("98.98")))

            await time.increase((dayAhead * 40))

            const tx3 = await hardhatClockSubscribe.connect(caller).remit();
            await expect(tx3).to.emit(hardhatClockSubscribe, "Coordinates").withArgs(subArray[0].id, 3, 1, 1, anyValue)
            await expect(tx3).to.emit(hardhatClockSubscribe, "Coordinates").withArgs(subArray[0].id, 2, 1, 1, anyValue)
            await expect(tx3).to.emit(hardhatClockSubscribe, "Coordinates").withArgs(subArray[0].id, 1, 1, 1, anyValue)

        })
        /*
        it("Should do offset proration of payment day before remit", async function() {
            const {hardhatCLOCKToken, hardhatClockSubscribe, subscriber, caller, provider, otherAccount, owner, subscriber2, subscriber3, subscriber4, subscriber5} = await loadFixture(deployClocktowerFixture);

            //adds CLOCK to approved tokens
            await hardhatClockSubscribe.addERC20Contract(await hardhatCLOCKToken.getAddress(), ethers.parseEther(".01"), ClockDecimals)

            const latestTimestamp = await time.latest();
            const date = new Date(latestTimestamp * 1000);
            const currentDay = date.getDay();

            //console.log(currentDay)

            //starts on Saturday

            //creates subscriptions
            await hardhatClockSubscribe.connect(provider).createSubscription(eth, await hardhatCLOCKToken.getAddress(), details,0,6)

            let subscriptions = await hardhatClockSubscribe.connect(provider).getAccountSubscriptions(false, provider.address);

            let subArray =[]

            //subscriptions
            for (let i = 0; i < subscriptions.length; i++) {
                subArray.push({
                    id: subscriptions[i].subscription[0],
                    amount: subscriptions[i].subscription[1],
                    provider: subscriptions[i].subscription[2],
                    token: subscriptions[i].subscription[3],
                    cancelled: subscriptions[i].subscription[4],
                    frequency: subscriptions[i].subscription[5],
                    dueDay: subscriptions[i].subscription[6]
                })
            }

            await hardhatClockSubscribe.connect(subscriber).subscribe(subArray[0])

            await hardhatClockSubscribe.connect(caller).remit()

            await time.increase(dayAhead * 7)

            await hardhatClockSubscribe.connect(otherAccount).subscribe(subArray[0])



        })
        */
        it("Should feefill correctly on subscribing", async function() {
            const {hardhatCLOCKToken, hardhatClockSubscribe, subscriber, caller, provider, otherAccount, owner, subscriber2, subscriber3, subscriber4, subscriber5} = await loadFixture(deployClocktowerFixture);

            //adds CLOCK to approved tokens
            await hardhatClockSubscribe.addERC20Contract(await hardhatCLOCKToken.getAddress(), ethers.parseEther(".01"), ClockDecimals)

            //creates subscriptions (yearly with low proration amount)
            await hardhatClockSubscribe.connect(provider).createSubscription(eth, await hardhatCLOCKToken.getAddress(), details,3,3)
            //creates subscriptions (prorated)
            await hardhatClockSubscribe.connect(provider).createSubscription(eth, await hardhatCLOCKToken.getAddress(), details,3,15)
            //creates subscriptions (maxed out and divided)
            await hardhatClockSubscribe.connect(provider).createSubscription(eth, await hardhatCLOCKToken.getAddress(), details,3,250)

            //creates subscriptions (prorated)
            await hardhatClockSubscribe.connect(provider).createSubscription(eth, await hardhatCLOCKToken.getAddress(), details,1,4)
            //creates subscriptions (maxed out and divided)
            await hardhatClockSubscribe.connect(provider).createSubscription(eth, await hardhatCLOCKToken.getAddress(), details,1,20)

             let subscriptions = await hardhatClockSubscribe.connect(provider).getAccountSubscriptions(false, provider.address);

             let subArray =[]
 
             //subscriptions
             for (let i = 0; i < subscriptions.length; i++) {
                 subArray.push({
                     id: subscriptions[i].subscription[0],
                     amount: subscriptions[i].subscription[1],
                     provider: subscriptions[i].subscription[2],
                     token: subscriptions[i].subscription[3],
                     cancelled: subscriptions[i].subscription[4],
                     frequency: subscriptions[i].subscription[5],
                     dueDay: subscriptions[i].subscription[6]
                 })
             }

             const clockSubscribeAddress = await hardhatClockSubscribe.getAddress()

             //checks that prorated amount below caller fee will feefill to caller fee
             await hardhatClockSubscribe.connect(subscriber).subscribe(subArray[0])

             expect(ethers.formatEther(convertToWei(await hardhatCLOCKToken.balanceOf(clockSubscribeAddress)))).to.equal("0.02")

             //checks that amount is prorated
             await hardhatClockSubscribe.connect(subscriber).subscribe(subArray[1])

             expect(ethers.formatEther(convertToWei(await hardhatCLOCKToken.balanceOf(clockSubscribeAddress)))).to.equal("0.058356")

             //checks that amount is equal to 8% (a week)
             await expect(hardhatClockSubscribe.connect(subscriber).subscribe(subArray[2]))
             .to.emit(hardhatClockSubscribe, "SubLog").withArgs(anyValue, provider.address, anyValue, anyValue, "599191780821917740", await hardhatCLOCKToken.getAddress(), 2)

             expect(ethers.formatEther(convertToWei(await hardhatCLOCKToken.balanceOf(clockSubscribeAddress)))).to.equal("0.141356")

             //checks that amount is prorated
             await hardhatClockSubscribe.connect(subscriber2).subscribe(subArray[3])

             expect(ethers.formatEther(convertToWei(await hardhatCLOCKToken.balanceOf(clockSubscribeAddress)))).to.equal("0.239986")

            //checks that amount is equal to 25%
            await hardhatClockSubscribe.connect(subscriber2).subscribe(subArray[4])

            expect(ethers.formatEther(convertToWei(await hardhatCLOCKToken.balanceOf(clockSubscribeAddress)))).to.equal("0.489986")

        })   
        it("Should set provider details", async function() {
            const {hardhatCLOCKToken, hardhatClockSubscribe, subscriber, caller, provider, otherAccount, owner, subscriber2, subscriber3, subscriber4, subscriber5} = await loadFixture(deployClocktowerFixture);

            const provDetails = {
                description : "testDescription",
                company: "testCompany",
                url: "testUrl",
                domain: "testDomain",
                email: "testEmail",
                misc: "testMisc"

            }

            await expect(hardhatClockSubscribe.connect(provider).editProvDetails(provDetails))
            .to.emit(hardhatClockSubscribe, "ProvDetailsLog").withArgs(provider.address, anyValue, "testDescription", "testCompany", "testUrl", "testDomain", "testEmail", "testMisc")
        })
    })
 
})