import { loadFixture, setBlockGasLimit } from "@nomicfoundation/hardhat-network-helpers";
import { time } from "@nomicfoundation/hardhat-network-helpers";
//import { anyValue } from "@nomicfoundation/hardhat-chai-matchers/withArgs";
import { expect } from "chai";
import { ethers } from "hardhat";
import { signERC2612Permit } from "eth-permit";

//Written by Hugo Marx

describe("Clocktower", function(){

  
    let currentTime = 1704088800;
    let mergeTime = 0;
    let hoursSinceMerge = Math.floor((currentTime - mergeTime) /3600);
    //eth sent
    let eth = ethers.utils.parseEther("1.0")
    let centEth = ethers.utils.parseEther("100.0")

    //sends test data of an hour ago
    let hourAgo = currentTime - 3600;
    let hourAhead = currentTime + 3600;
    let twoHoursAhead = hourAhead + 3600;
    let threeHoursAhead = twoHoursAhead + 3600;

    //CLOCKtoken address
    const clockTokenAddress = "0x5FbDB2315678afecb367f032d93F642f64180aa3";

    //Infinite approval
    const infiniteApproval = BigInt(Math.pow(2,255))
    
    let addressZero = ethers.constants.AddressZero;

    let byteArray = []
    //creates empty 32 byte array
    for(let i = 0; i < 32; i++) {
        byteArray[i] = 0x0
    }

    //empty permit
    let permit = {owner: addressZero, spender: addressZero, value: 0, deadline: 0, v:0, r: byteArray , s: byteArray};
    
    
    //function that creates permit
    async function setPermit(owner:any , spender: string, value: string, deadline: number) {
        
        //let _value = String(ethers.utils.parseEther(value))
        let Big2 = ethers.BigNumber.from(2);
        let _value = String(Big2.pow(255));
        //signs permit
        const result = await signERC2612Permit(
            owner,
            clockTokenAddress,
            owner.address,
            spender,
            _value,
            deadline
        );

        let _permit = {
            owner: owner.address, 
            spender: spender, 
            value: result.value, 
            deadline: result.deadline, 
            v: result.v, r: result.r , s: result.s};

        return _permit
    }
    

    //fixture to deploy contract
    async function deployClocktowerFixture() {

        //sets time to 2023/01/01 1:00
        await time.increaseTo(currentTime);
        

        const ClockToken = await ethers.getContractFactory("CLOCKToken");

        const ClockSubscribe = await ethers.getContractFactory("ClockTowerSubscribe")
        const ClockPayment = await ethers.getContractFactory("ClockTowerPayment")

        const [owner, otherAccount, subscriber, provider, caller] = await ethers.getSigners();

        //const hardhatClocktower = await Clocktower.deploy();
        const hardhatCLOCKToken = await ClockToken.deploy(ethers.utils.parseEther("100100"));
        const hardhatClockSubscribe = await ClockSubscribe.deploy();
        const hardhatClockPayment = await ClockPayment.deploy();

        const addressZero = ethers.constants.AddressZero;

       // await hardhatClocktower.deployed();
        await hardhatCLOCKToken.deployed();
        await hardhatClockSubscribe.deployed();
        await hardhatClockPayment.deployed();

        console.log(hardhatCLOCKToken.address);
         //starts contract with 100 ETH
         const params = {
            from: owner.address,
            to: hardhatClockPayment.address,
            value: centEth
        };

        await owner.sendTransaction(params);

        //funds other account with eth
        const paramsOther = {
            from: owner.address,
            to: otherAccount.address,
            value: centEth
        };
        await owner.sendTransaction(paramsOther)

        let params2 = {
            value: eth
        }
        
        //approves token
        //await hardhatClocktower.addERC20Contract(hardhatCLOCKToken.address);
         //signs permit
         //let signedPermit = await setPermit(owner, hardhatClocktower.address, "1", 1766556423)

      //  await hardhatCLOCKToken.approve(hardhatClocktower.address, infiniteApproval)
        await hardhatCLOCKToken.approve(hardhatClockSubscribe.address, infiniteApproval)
        await hardhatCLOCKToken.approve(hardhatClockPayment.address, infiniteApproval)
        await hardhatCLOCKToken.connect(otherAccount).approve(hardhatClockSubscribe.address, infiniteApproval)
        await hardhatCLOCKToken.connect(subscriber).approve(hardhatClockSubscribe.address, infiniteApproval)

        //creates several transaactions to test transaction list
       // await hardhatClocktower.addTransaction(otherAccount.address, 1672560000, eth, hardhatCLOCKToken.address, signedPermit, params2);
        await hardhatClockPayment.addPayment(otherAccount.address, hourAhead, eth, ethers.constants.AddressZero,params2);
        await hardhatClockPayment.addPayment(otherAccount.address, hourAhead, eth, ethers.constants.AddressZero,params2);
    
         //sends 100 clocktoken to other account
        // await hardhatCLOCKToken.transfer(otherAccount.address, centEth)
        //moves time 2 hours to 2023/01/01 3:00
        //await time.increaseTo(1672563600);
        await hardhatCLOCKToken.transfer(otherAccount.address, centEth)
        await hardhatCLOCKToken.transfer(subscriber.address, centEth)
        await hardhatCLOCKToken.transfer(provider.address, centEth)
        await hardhatCLOCKToken.transfer(caller.address, centEth)

        return {owner, otherAccount, subscriber, provider, caller, hardhatCLOCKToken, hardhatClockSubscribe , hardhatClockPayment} ;
    }

    //test sending ether
    describe("Sending Ether", function() {
        it("Should receive ether", async function() {
            const {owner, otherAccount, hardhatClockPayment} = await loadFixture(deployClocktowerFixture);
            
            const params = {
                from: owner.address,
                to: hardhatClockPayment.address,
                value: ethers.utils.parseEther("1.0")
            };

            await owner.sendTransaction(params);

            
            expect(
                await ethers.provider.getBalance(hardhatClockPayment.address)
            ).to.greaterThanOrEqual(eth)
        })
    })

    //Account tests
    describe("Account", function() {

        const testParams = {
            value: eth
        };


        it("Should get transactions by account", async function() {
            const {hardhatClockPayment, owner, otherAccount} = await loadFixture(deployClocktowerFixture);
            await hardhatClockPayment.addPayment(otherAccount.address, hourAhead, eth, ethers.constants.AddressZero, testParams)
            let transactions: any = await hardhatClockPayment.getAccountPayments();
            
            expect(transactions[0].payload).to.equal(eth)
            expect(transactions[0].sender).to.equal(owner.address)
            expect(transactions[0].receiver).to.equal(otherAccount.address)
            expect(transactions.length).to.equal(3)
        })
    
    })

    
    //tests adding transaction
    describe("Transactions", function(){

        const testParams = {
            value: eth
        };

        it("Should send eth with the transaction", async function() {
            const {hardhatClockPayment, owner, otherAccount} = await loadFixture(deployClocktowerFixture);
           
            await hardhatClockPayment.addPayment(otherAccount.address, hourAhead, eth, ethers.constants.AddressZero, testParams)
            expect(
                await ethers.provider.getBalance(hardhatClockPayment.address)
            ).to.equals(ethers.utils.parseEther("103.0"))

        })

        it("Should remove transaction", async function() {
            const {hardhatClockPayment, owner, otherAccount} = await loadFixture(deployClocktowerFixture);
            //await hardhatClocktower.addTransaction(otherAccount.address, hourAhead, eth, testParams)
            let transactions: any = await hardhatClockPayment.getAccountPayments();
            await hardhatClockPayment.cancelTransaction(transactions[0].id, transactions[0].timeTrigger, transactions[0].token)
            let transactions2: any = await hardhatClockPayment.getAccountPayments();
            expect(
                transactions2.length
            ).lessThan(transactions.length);

        })
        
    })
    
    describe("Send Time", function(){
        

        it("Should send ether to addresses", async function() {
            const {hardhatClockPayment, owner, otherAccount} = await loadFixture(deployClocktowerFixture);
            await hardhatClockPayment.sendPayments();
            expect(
                await ethers.provider.getBalance(otherAccount.address)
            ).to.greaterThan(ethers.utils.parseEther("1007.0"))
        })
        it("Should find day of month", async function() {
            const {owner, otherAccount} = await loadFixture(deployClocktowerFixture);
            //expect(await hardhatClocktower.unixTimeToDayMonthYear(1739340000))

        })
        
    })
    
    describe("Batch Functions", function() {
        it("Should add transactions", async function() {
            const {hardhatClockPayment, hardhatCLOCKToken, owner, otherAccount} = await loadFixture(deployClocktowerFixture);

            const eths = ethers.utils.parseEther("3.0")
            const testParams = {
                value: eths
            };

            //creates two transaction objects
            let transaction1 = {receiver: otherAccount.address, unixTime: hourAhead, payload: eth, token: hardhatCLOCKToken.address}//2
            let transaction2 = {receiver: otherAccount.address, unixTime: hourAhead, payload: eth, token: hardhatCLOCKToken.address}//3
            let transaction3 = {receiver: otherAccount.address, unixTime: hourAhead, payload: eth, token: hardhatCLOCKToken.address}//4

            let transactions = [transaction1, transaction2, transaction3]

           // let transactions = [transaction1]

            //adds CLOCK to approved tokens
            await hardhatClockPayment.addERC20Contract(hardhatCLOCKToken.address)
            //await hardhatClockPayment.addERC20Contract(daiAddress)

            //gives approval to token transfer
            await hardhatCLOCKToken.approve(hardhatClockPayment.address, eths)

            //add batch
            // await hardhatClocktower.addBatchTransactions(transactions, testParams)
            await hardhatClockPayment.addBatchPayments(transactions, testParams)

            //gets total claims
            let claims = await hardhatClockPayment.getTotalClaims(hardhatCLOCKToken.address);

            let returnTransactions: any = await hardhatClockPayment.getAccountPayments();


            expect(returnTransactions.length).to.equal(5)
            expect(returnTransactions[2].payload).to.equal(eth)
            expect(returnTransactions[2].receiver).to.equal(otherAccount.address)
            expect(returnTransactions[3].payload).to.equal(eth)
            expect(claims).to.equal(eths);
        })
      
    })

    describe("Admin Functions", function() {

        const testParams = {
            value: ethers.utils.parseEther("1.02")
        };

        it("Should get transaction snapshot", async function() {
            const {hardhatClockPayment, owner, otherAccount} = await loadFixture(deployClocktowerFixture);

            let returnTransactions: any = await hardhatClockPayment.allTransactions();

            expect(returnTransactions.length).to.equal(2)
            expect(returnTransactions[1].payload).to.equal(eth)
            
        })
        it("Should get accounts snapshot", async function() {
            const {hardhatClockPayment, owner, otherAccount} = await loadFixture(deployClocktowerFixture);

            let returnAccounts: any = await hardhatClockPayment.allAccounts();

            expect(returnAccounts.length).to.equal(1)
            expect(returnAccounts[0].accountAddress).to.equal(owner.address)
        })
        it("Should allow to remove ERC20", async function(){
            const {hardhatClockPayment, owner, otherAccount} = await loadFixture(deployClocktowerFixture);

            await hardhatClockPayment.addERC20Contract("0x6B175474E89094C44Da98b954EedeAC495271d0F")
            await hardhatClockPayment.addERC20Contract("0xdAC17F958D2ee523a2206206994597C13D831ec7")
            expect(await hardhatClockPayment.removeERC20Contract("0x6B175474E89094C44Da98b954EedeAC495271d0F"))
        })
        it("Should get balance of CLOCK token", async function() {
            const {hardhatCLOCKToken, owner, otherAccount} = await loadFixture(deployClocktowerFixture);

            let amount = await hardhatCLOCKToken.balanceOf(owner.address)

            expect(amount).to.equal(ethers.utils.parseEther("99700"))
        })
        it("Should change fee", async function() {
            const {hardhatClockPayment, owner, otherAccount} = await loadFixture(deployClocktowerFixture);
            await hardhatClockPayment.changeFee(102);
            await hardhatClockPayment.addPayment(otherAccount.address, hourAhead, eth, ethers.constants.AddressZero, testParams)
            let returnTransactions: any = await hardhatClockPayment.allTransactions();
            expect(returnTransactions.length).to.equal(3)
        })
       
    })

 
    describe("ERC20 Functions", function() {
        const testParams = {
            value: eth
        };

        it("Should add an ERC20 Transaction", async function() {
            const {hardhatCLOCKToken, hardhatClockPayment, owner, otherAccount} = await loadFixture(deployClocktowerFixture);
            //adds CLOCK to approved tokens
            await hardhatClockPayment.addERC20Contract(hardhatCLOCKToken.address)
            //User gives approval for clocktower to use their tokens
            await hardhatCLOCKToken.approve(hardhatClockPayment.address, infiniteApproval)
           // let signedPermit = await setPermit(owner, hardhatClocktower.address, "1", 1766556423)

            await hardhatClockPayment.addPayment(otherAccount.address, hourAhead, eth, ethers.utils.getAddress(hardhatCLOCKToken.address), testParams)

            //expect(await hardhatCLOCKToken.balanceOf(hardhatClocktower.address)).to.equal(eth)
        })
        
        it("Should send ERC20 Tokens", async function() {
            const {hardhatCLOCKToken, hardhatClockPayment, owner, otherAccount} = await loadFixture(deployClocktowerFixture);
            //adds CLOCK to approved tokens
            await hardhatClockPayment.addERC20Contract(hardhatCLOCKToken.address)

            //User gives approval for clocktower to use their tokens
            //await hardhatCLOCKToken.approve(hardhatClocktower.address, eth)
            //signs permit
            let signedPermit = await setPermit(owner, hardhatClockPayment.address, "1", 1766556423)
            await hardhatClockPayment.addPayment(otherAccount.address, hourAhead, eth, ethers.utils.getAddress(hardhatCLOCKToken.address), testParams)
            let signedPermit2 = await setPermit(owner, hardhatClockPayment.address, "1", 1766556423)
            await hardhatClockPayment.addPayment(otherAccount.address, hourAhead, eth, ethers.utils.getAddress(hardhatCLOCKToken.address), testParams)

            //moves time 2 hours to 2023/01/01 3:00
            //await time.increaseTo(1672563600);
            await time.increaseTo(twoHoursAhead);
            await hardhatClockPayment.sendPayments();
            expect(await hardhatCLOCKToken.balanceOf(otherAccount.address)).to.equal(ethers.utils.parseEther("102.0"))
        })

        
        it("Should accept Permit signatures", async function() {
            const {hardhatCLOCKToken, hardhatClockPayment, owner, otherAccount} = await loadFixture(deployClocktowerFixture);
            //adds CLOCK to approved tokens
            await hardhatClockPayment.addERC20Contract(hardhatCLOCKToken.address)

            //console.log(await hardhatCLOCKToken.DOMAIN_SEPARATOR());
            
            //signs permit
            let signedPermit = await setPermit(owner, hardhatClockPayment.address, "1", 1766556423)

           // console.log(_permit)
            
            /*
            const result = await signERC2612Permit(
                owner,
                hardhatCLOCKToken.address,
                owner.address,
                hardhatClocktower.address,
                String(ethers.utils.parseEther("3")),
                1766556423
            );

            let _permit2 = {
                owner: owner.address, 
                spender: hardhatClocktower.address, 
                value: result.value, 
                deadline: result.deadline, 
                v: result.v, r: result.r , s: result.s};

            console.log(_permit2)
            */
            
        
            expect(await hardhatClockPayment.addPermitPayment(otherAccount.address, hourAhead, eth, ethers.utils.getAddress(hardhatCLOCKToken.address), signedPermit, testParams))
           // expect(await hardhatCLOCKToken.balanceOf(hardhatClocktower.address)).to.equal(ethers.utils.parseEther("1"));

        })
        

    })
    describe("Subscriptions", function() {
        const testParams = {
            value: eth
        };

        it("Should create Subscription", async function() {
            const {hardhatCLOCKToken, hardhatClockSubscribe, owner, otherAccount} = await loadFixture(deployClocktowerFixture);
            
            //adds CLOCK to approved tokens
            await hardhatClockSubscribe.addERC20Contract(hardhatCLOCKToken.address)

            expect(await hardhatClockSubscribe.createSubscription(eth, hardhatCLOCKToken.address, "Test",1,15, testParams))

        })

        it("Should get created subscriptions", async function() {
            const {hardhatCLOCKToken, hardhatClockSubscribe, owner, otherAccount} = await loadFixture(deployClocktowerFixture);
            
            //adds CLOCK to approved tokens
            await hardhatClockSubscribe.addERC20Contract(hardhatCLOCKToken.address)
            await hardhatClockSubscribe.createSubscription(eth, hardhatCLOCKToken.address, "Test" ,1, 15, testParams)
            await hardhatClockSubscribe.createSubscription(eth, hardhatCLOCKToken.address, "Test" ,2, 15, testParams)
            let subscriptions = await hardhatClockSubscribe.getAccountSubscriptions(false)

            expect(subscriptions[1].subscription.description).to.equal("Test")
            expect(subscriptions[1].subscription.amount).to.equal(eth);
            expect(subscriptions[1].subscription.token).to.equal(hardhatCLOCKToken.address);
            expect(subscriptions[1].subscription.dueDay).to.equal(15);
        })
        
        it("Should allow user to subscribe", async function() {

            const testParams2 = {
                value: eth,
                gasLimit: 3000000
            };
    
            
            const {hardhatCLOCKToken, hardhatClockSubscribe, owner, otherAccount} = await loadFixture(deployClocktowerFixture);
            
            //adds CLOCK to approved tokens
            await hardhatClockSubscribe.addERC20Contract(hardhatCLOCKToken.address)
            await hardhatClockSubscribe.createSubscription(eth, hardhatCLOCKToken.address, "Test",1,15, testParams)
            await hardhatClockSubscribe.createSubscription(eth, hardhatCLOCKToken.address, "Test2",3,15, testParams)

            let subscriptions = await hardhatClockSubscribe.getAccountSubscriptions(false)

            await hardhatClockSubscribe.subscribe(subscriptions[1].subscription, testParams2)

            let aSubscriptions = await hardhatClockSubscribe.getAccountSubscriptions(true)

            expect(aSubscriptions[0].subscription.description).to.equal("Test2");
            
        })
        it("Should allow user to unsubscribe", async function() {
            const {hardhatCLOCKToken, hardhatClockSubscribe, owner, otherAccount} = await loadFixture(deployClocktowerFixture);
            
            //adds CLOCK to approved tokens
            await hardhatClockSubscribe.addERC20Contract(hardhatCLOCKToken.address)
            await hardhatClockSubscribe.createSubscription(eth, hardhatCLOCKToken.address, "Test",1,15, testParams)
            await hardhatClockSubscribe.createSubscription(eth, hardhatCLOCKToken.address, "Test",2,15, testParams)

            let subscriptions = await hardhatClockSubscribe.getAccountSubscriptions(false)

            await hardhatClockSubscribe.subscribe(subscriptions[1].subscription, testParams)

            let result2 = await hardhatClockSubscribe.getSubscribers(subscriptions[1].subscription.id)
            await hardhatClockSubscribe.unsubscribe(subscriptions[1].subscription, testParams);

            let result = await hardhatClockSubscribe.getAccountSubscriptions(true)
            let result3 = await hardhatClockSubscribe.getSubscribers(subscriptions[1].subscription.id)
            
            expect(result[0].status).to.equal(2)
            expect(result2.length).to.equal(1)
            expect(result3.length).to.equal(0)
        })
        it("Should cancel subscription", async function(){
            const {hardhatCLOCKToken, hardhatClockSubscribe, owner, otherAccount} = await loadFixture(deployClocktowerFixture);
            
            //adds CLOCK to approved tokens
            await hardhatClockSubscribe.addERC20Contract(hardhatCLOCKToken.address)
            await hardhatClockSubscribe.createSubscription(eth, hardhatCLOCKToken.address, "Test",1,15, testParams)
            await hardhatClockSubscribe.createSubscription(eth, hardhatCLOCKToken.address, "Test",2,15, testParams)

            let subscriptions = await hardhatClockSubscribe.getAccountSubscriptions(false)

            await hardhatClockSubscribe.subscribe(subscriptions[1].subscription, testParams)

            await hardhatClockSubscribe.cancelSubscription(subscriptions[1].subscription)

            let result = await hardhatClockSubscribe.getAccountSubscriptions(true)
            //let subscriptions2 = await hardhatClockSubscribe.getAccountSubscriptions(false)
            //sees if subscriber sees cancelled status
            expect(result[0].status).to.equal(1);
            expect(result[0].subscription.cancelled).to.equal(true)
        })
        it("Should complete transactions at the right time", async function(){
            const {hardhatCLOCKToken, hardhatClockSubscribe, owner, otherAccount} = await loadFixture(deployClocktowerFixture);
            
            //adds CLOCK to approved tokens
            await hardhatClockSubscribe.addERC20Contract(hardhatCLOCKToken.address)

            await hardhatClockSubscribe.createSubscription(eth, hardhatCLOCKToken.address, "Test",1,1, testParams)
            await hardhatClockSubscribe.createSubscription(eth, hardhatCLOCKToken.address, "Test",1,1, testParams)
            await hardhatClockSubscribe.createSubscription(eth, hardhatCLOCKToken.address, "Test",1,1, testParams)
            await hardhatClockSubscribe.createSubscription(eth, hardhatCLOCKToken.address, "Test",1,1, testParams)
            await hardhatClockSubscribe.createSubscription(eth, hardhatCLOCKToken.address, "Test",1,1, testParams)
            await hardhatClockSubscribe.createSubscription(eth, hardhatCLOCKToken.address, "Test",1,1, testParams)
            await hardhatClockSubscribe.createSubscription(eth, hardhatCLOCKToken.address, "Test",1,1, testParams)
            

            let subscriptions = await hardhatClockSubscribe.getAccountSubscriptions(false)
            
            await hardhatClockSubscribe.connect(otherAccount).subscribe(subscriptions[0].subscription, testParams)
            await hardhatClockSubscribe.connect(otherAccount).subscribe(subscriptions[1].subscription, testParams)
            await hardhatClockSubscribe.connect(otherAccount).subscribe(subscriptions[2].subscription, testParams)
            await hardhatClockSubscribe.connect(otherAccount).subscribe(subscriptions[3].subscription, testParams)
            await hardhatClockSubscribe.connect(otherAccount).subscribe(subscriptions[4].subscription, testParams)
            await hardhatClockSubscribe.connect(otherAccount).subscribe(subscriptions[5].subscription, testParams)
            await hardhatClockSubscribe.connect(otherAccount).subscribe(subscriptions[6].subscription, testParams)

            //await hardhatClockSubscribe.unsubscribeByProvider(otherAccount.address, subscriptions[6].subscription.id)
            
            await time.increaseTo(twoHoursAhead);

            //await hardhatClockSubscribe.remit();

            let subscribersId = await hardhatClockSubscribe.getSubscribersById(subscriptions[0].subscription.id)

            console.log(subscribersId[0].subscriber)
            console.log(ethers.utils.formatEther(subscribersId[0].feeBalance))

            let isFinished = false;

            //loops through remit calls to test max remit
            while(!isFinished) {
                //console.log(ethers.utils.formatEther(await hardhatClockSubscribe.feeBalance(subscriptions[0].subscription.id, otherAccount.address)))
                //console.log("here")
                //gets emit
                let tx = await hardhatClockSubscribe.remit();
                let rc = await tx.wait();
                let event = rc.events?.find(event => event.event === 'CallerLog')
                let args = event?.args
                isFinished = args?.isFinished;
            }

            /*
            //gets emit
            const tx = await hardhatClockSubscribe.remit();
            const rc = await tx.wait();
            const event = rc.events?.find(event => event.event === 'RemitLog')
            const args = event?.args
            console.log(args?.isFinished);

            //gets emit
            const tx2 = await hardhatClockSubscribe.remit();
            const rc2 = await tx2.wait();
            const event2 = rc2.events?.find(event => event.event === 'RemitLog')
            const args2 = event2?.args
            console.log(args2?.isFinished);
            */

            //while(await hardhatClockSubscribe.remit());

            let otherBalance = await hardhatCLOCKToken.balanceOf(otherAccount.address)
            let ownerBalance = await hardhatCLOCKToken.balanceOf(owner.address)

            let expected = ethers.utils.parseEther("86.0");

            //gets fee balance
            let feeBalance = await hardhatClockSubscribe.feeBalance(subscriptions[0].subscription.id,otherAccount.address)
            console.log(ethers.utils.formatEther(await hardhatClockSubscribe.feeBalance(subscriptions[0].subscription.id,otherAccount.address)))

            expect(otherBalance).to.equal(expected)
            //expect(ownerBalance).to.equal()

            
        })
        it("Should emit SubscriberLog", async function(){
            const {hardhatCLOCKToken, hardhatClockSubscribe, owner, otherAccount} = await loadFixture(deployClocktowerFixture);
            //adds CLOCK to approved tokens
            await hardhatClockSubscribe.addERC20Contract(hardhatCLOCKToken.address)
            await hardhatClockSubscribe.createSubscription(eth, hardhatCLOCKToken.address, "Test",1,1, testParams)
            let subscriptions = await hardhatClockSubscribe.getAccountSubscriptions(false)
           // await hardhatClockSubscribe.connect(otherAccount).subscribe(subscriptions[0].subscription, testParams)

            let tx = await hardhatClockSubscribe.connect(otherAccount).subscribe(subscriptions[0].subscription, testParams)
            let rc = await tx.wait();
            let event = rc.events?.find(event => event.event === 'SubscriberLog')
            console.log(event)

           /*
            expect(await hardhatClockSubscribe.connect(otherAccount).subscribe(subscriptions[0].subscription, testParams))
            .to.emit(hardhatClockSubscribe, 'SubcriberLog')
            .withArgs(otherAccount.address)
            */

            /*
            let tx = await hardhatClockSubscribe.remit();
            let rc = await tx.wait();
            let event = rc.events?.find(event => event.event === 'CallerLog')
            let args = event?.args
            isFinished = args?.isFinished;
            */

        })
        it("Should test getSubscriptionsByAccount", async function(){
            const {hardhatCLOCKToken, hardhatClockSubscribe, owner, otherAccount} = await loadFixture(deployClocktowerFixture);
            //adds CLOCK to approved tokens
            await hardhatClockSubscribe.addERC20Contract(hardhatCLOCKToken.address)
            await hardhatClockSubscribe.createSubscription(eth, hardhatCLOCKToken.address, "Test",1,1, testParams)
            let subscriptions = await hardhatClockSubscribe.getAccountSubscriptions(false)

            await hardhatClockSubscribe.connect(otherAccount).subscribe(subscriptions[0].subscription, testParams)

            let returnSubs = await hardhatClockSubscribe.getSubscriptionsByAccount(true, otherAccount.address)

            console.log(returnSubs.length)
        })
        it("Should allow external callers", async function() {
            const {hardhatCLOCKToken, hardhatClockSubscribe, owner, otherAccount} = await loadFixture(deployClocktowerFixture);
             //adds CLOCK to approved tokens
             await hardhatClockSubscribe.addERC20Contract(hardhatCLOCKToken.address)
             //creates subscription and subscribes
             await hardhatClockSubscribe.createSubscription(eth, hardhatCLOCKToken.address, "Test",1,1, testParams)
             let subscriptions = await hardhatClockSubscribe.getAccountSubscriptions(false)
             await hardhatClockSubscribe.connect(otherAccount).subscribe(subscriptions[0].subscription, testParams)

            //sets external callers
            await hardhatClockSubscribe.setExternalCallers(true)

            expect(await hardhatClockSubscribe.connect(otherAccount).remit())
        })
        it("Should predict fees", async function() {
            const {hardhatCLOCKToken, hardhatClockSubscribe, owner, otherAccount} = await loadFixture(deployClocktowerFixture);
            //adds CLOCK to approved tokens
            await hardhatClockSubscribe.addERC20Contract(hardhatCLOCKToken.address)
            //creates subscription and subscribes
            await hardhatClockSubscribe.createSubscription(eth, hardhatCLOCKToken.address, "Test",1,1, testParams)
            let subscriptions = await hardhatClockSubscribe.getAccountSubscriptions(false)
            await hardhatClockSubscribe.connect(otherAccount).subscribe(subscriptions[0].subscription, testParams)

            //moves time
            await time.increaseTo(twoHoursAhead);

            //gets fee estimate
            let feeArray = await hardhatClockSubscribe.feeEstimate();

            console.log((feeArray).length)

            feeArray.forEach((estimate) =>{

                console.log(estimate.fee)
                console.log("--------------------")
                console.log(estimate.token)

            })
        })
        it("Should collect system fees", async function() {
            const {hardhatCLOCKToken, hardhatClockSubscribe, owner, otherAccount, provider} = await loadFixture(deployClocktowerFixture);

            const testParams = {
                value: ethers.utils.parseEther("0.011")
            };

            //adds CLOCK to approved tokens
            await hardhatClockSubscribe.addERC20Contract(hardhatCLOCKToken.address)
            //turns on system fee collection
            await hardhatClockSubscribe.systemFeeActivate(true)

            //creates subscription and subscribes
            await hardhatClockSubscribe.connect(provider).createSubscription(eth, hardhatCLOCKToken.address, "Test",1,1, testParams)

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
            await hardhatClockSubscribe.addERC20Contract(hardhatCLOCKToken.address)

            //creates subscription and subscribes
            await hardhatClockSubscribe.connect(provider).createSubscription(eth, hardhatCLOCKToken.address, "Test",1,1, testParams)
            
            let subscriptions = await hardhatClockSubscribe.connect(provider).getAccountSubscriptions(false);
            await hardhatClockSubscribe.connect(subscriber).subscribe(subscriptions[0].subscription, testParams)

            //otherAccount stops approval
            await hardhatCLOCKToken.connect(subscriber).approve(hardhatClockSubscribe.address, 0)

            let subAmount = await hardhatCLOCKToken.balanceOf(subscriber.address)

            await hardhatClockSubscribe.setExternalCallers(true)

            await hardhatClockSubscribe.connect(caller).remit();

            //check that provider has been refunded
            let provAmount = await hardhatCLOCKToken.balanceOf(provider.address)

            //checks caller
            let callerAmount = await hardhatCLOCKToken.balanceOf(caller.address)

            expect(ethers.utils.formatEther(subAmount)).to.equal("99.0")
            expect(ethers.utils.formatEther(provAmount)).to.equal("100.98")    
            expect(ethers.utils.formatEther(callerAmount)).to.equal("100.02")        

        })

        
    })
})