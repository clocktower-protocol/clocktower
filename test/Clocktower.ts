import { loadFixture, setBlockGasLimit } from "@nomicfoundation/hardhat-network-helpers";
import { time } from "@nomicfoundation/hardhat-network-helpers";
//import { anyValue } from "@nomicfoundation/hardhat-chai-matchers/withArgs";
import { expect } from "chai";
import { ethers } from "hardhat";
import { signERC2612Permit } from "eth-permit";

//Written by Hugo Marx

describe("Clocktower", function(){

    //const [owner, otherAccount] = await ethers.getSigners();

    //sends receive time in unix epoch seconds

    //let millis = Date.now();
    //let currentTime = Math.floor(millis / 1000);
    let currentTime = 1685595600;
    //let currentTime = 1673058466;
    //hour merge occured
    //let mergeTime = 1663264800;
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
    const clockTokenAddress = "0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512";
    //DAI address
    const daiAddress = "0x6B175474E89094C44Da98b954EedeAC495271d0F";
    const clockLibraryAddress = "0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0";
    const clockPureAddress = "0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0"

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
        
        /*
        const Clocktower = await ethers.getContractFactory("Clocktower", {
            libraries: {
                ClockTowerLibrary: "0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0"
            }
        });
        */
        
        const Clocktower = await ethers.getContractFactory("Clocktower")

        const ClockToken = await ethers.getContractFactory("CLOCKToken");

        const ClockSubscribe = await ethers.getContractFactory("ClockTowerSubscribe")
        const ClockPayment = await ethers.getContractFactory("ClockTowerPayment")

       // const ClockPure = await ethers.getContractFactory("contracts/ClocktowerPure.sol");

        const [owner, otherAccount] = await ethers.getSigners();

        const hardhatClocktower = await Clocktower.deploy();
        const hardhatCLOCKToken = await ClockToken.deploy(ethers.utils.parseEther("100100"));
        const hardhatClockSubscribe = await ClockSubscribe.deploy();
        const hardhatClockPayment = await ClockPayment.deploy();
       // const hardhatClockPure = await ClockPure.deploy();

        const addressZero = ethers.constants.AddressZero;

        await hardhatClocktower.deployed();
        await hardhatCLOCKToken.deployed();
        await hardhatClockSubscribe.deployed();
        await hardhatClockPayment.deployed();
        
        //const ClockLibrary = await ethers.getContractFactory("ClockTowerLibrary");
        //const hardhatClockLibrary = await ClockLibrary.deploy();
        
        //await hardhatClockLibrary.deployed();
        //await hardhatClockPure.deployed();


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

        await hardhatCLOCKToken.approve(hardhatClocktower.address, infiniteApproval)
        await hardhatCLOCKToken.approve(hardhatClockSubscribe.address, infiniteApproval)
        await hardhatCLOCKToken.approve(hardhatClockPayment.address, infiniteApproval)
        await hardhatCLOCKToken.connect(otherAccount).approve(hardhatClockSubscribe.address, infiniteApproval)

        //creates several transaactions to test transaction list
       // await hardhatClocktower.addTransaction(otherAccount.address, 1672560000, eth, hardhatCLOCKToken.address, signedPermit, params2);
        await hardhatClockPayment.addTransaction(otherAccount.address, hourAhead, eth, ethers.constants.AddressZero,params2);
        await hardhatClockPayment.addTransaction(otherAccount.address, hourAhead, eth, ethers.constants.AddressZero,params2);
    
         //sends 100 clocktoken to other account
        // await hardhatCLOCKToken.transfer(otherAccount.address, centEth)
        //moves time 2 hours to 2023/01/01 3:00
        //await time.increaseTo(1672563600);
        await hardhatCLOCKToken.transfer(otherAccount.address, centEth)


        return { Clocktower, hardhatClocktower, owner, otherAccount, hardhatCLOCKToken, hardhatClockSubscribe , hardhatClockPayment} ;
    }

    //test sending ether
    describe("Sending Ether", function() {
        it("Should receive ether", async function() {
            const {hardhatClocktower, owner, otherAccount, hardhatClockPayment} = await loadFixture(deployClocktowerFixture);
            
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
            await hardhatClockPayment.addTransaction(otherAccount.address, hourAhead, eth, ethers.constants.AddressZero, testParams)
            let transactions: any = await hardhatClockPayment.getAccountTransactions();
            
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
           
            await hardhatClockPayment.addTransaction(otherAccount.address, hourAhead, eth, ethers.constants.AddressZero, testParams)
            expect(
                await ethers.provider.getBalance(hardhatClockPayment.address)
            ).to.equals(ethers.utils.parseEther("103.0"))

        })

        it("Should remove transaction", async function() {
            const {hardhatClockPayment, owner, otherAccount} = await loadFixture(deployClocktowerFixture);
            //await hardhatClocktower.addTransaction(otherAccount.address, hourAhead, eth, testParams)
            let transactions: any = await hardhatClockPayment.getAccountTransactions();
            await hardhatClockPayment.cancelTransaction(transactions[0].id, transactions[0].timeTrigger, transactions[0].token)
            let transactions2: any = await hardhatClockPayment.getAccountTransactions();
            expect(
                transactions2.length
            ).lessThan(transactions.length);

        })
        
    })
    
    describe("Send Time", function(){
        

        it("Should send ether to addresses", async function() {
            const {hardhatClockPayment, owner, otherAccount} = await loadFixture(deployClocktowerFixture);
            await hardhatClockPayment.sendTime();
            expect(
                await ethers.provider.getBalance(otherAccount.address)
            ).to.greaterThan(ethers.utils.parseEther("1007.0"))
        })
        it("Should find day of month", async function() {
            const {hardhatClocktower, owner, otherAccount} = await loadFixture(deployClocktowerFixture);
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
            await hardhatClockPayment.addERC20Contract(clockTokenAddress)
            await hardhatClockPayment.addERC20Contract(daiAddress)

            //gives approval to token transfer
            await hardhatCLOCKToken.approve(hardhatClockPayment.address, eths)

            //add batch
            // await hardhatClocktower.addBatchTransactions(transactions, testParams)
            await hardhatClockPayment.addBatchTransactions(transactions, testParams)

            //gets total claims
            let claims = await hardhatClockPayment.getTotalClaims(clockTokenAddress);

            let returnTransactions: any = await hardhatClockPayment.getAccountTransactions();


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

            expect(amount).to.equal(ethers.utils.parseEther("100000"))
        })
        it("Should change fee", async function() {
            const {hardhatClockPayment, owner, otherAccount} = await loadFixture(deployClocktowerFixture);
            await hardhatClockPayment.changeFee(102);
            await hardhatClockPayment.addTransaction(otherAccount.address, hourAhead, eth, ethers.constants.AddressZero, testParams)
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
            await hardhatClockPayment.addERC20Contract(clockTokenAddress)
            //User gives approval for clocktower to use their tokens
            await hardhatCLOCKToken.approve(hardhatClockPayment.address, infiniteApproval)
           // let signedPermit = await setPermit(owner, hardhatClocktower.address, "1", 1766556423)

            await hardhatClockPayment.addTransaction(otherAccount.address, hourAhead, eth, ethers.utils.getAddress(clockTokenAddress), testParams)

            //expect(await hardhatCLOCKToken.balanceOf(hardhatClocktower.address)).to.equal(eth)
        })
        
        it("Should send ERC20 Tokens", async function() {
            const {hardhatCLOCKToken, hardhatClockPayment, owner, otherAccount} = await loadFixture(deployClocktowerFixture);
            //adds CLOCK to approved tokens
            await hardhatClockPayment.addERC20Contract(clockTokenAddress)

            //User gives approval for clocktower to use their tokens
            //await hardhatCLOCKToken.approve(hardhatClocktower.address, eth)
            //signs permit
            let signedPermit = await setPermit(owner, hardhatClockPayment.address, "1", 1766556423)
            await hardhatClockPayment.addTransaction(otherAccount.address, hourAhead, eth, ethers.utils.getAddress(clockTokenAddress), testParams)
            let signedPermit2 = await setPermit(owner, hardhatClockPayment.address, "1", 1766556423)
            await hardhatClockPayment.addTransaction(otherAccount.address, hourAhead, eth, ethers.utils.getAddress(clockTokenAddress), testParams)

            //moves time 2 hours to 2023/01/01 3:00
            //await time.increaseTo(1672563600);
            await time.increaseTo(twoHoursAhead);
            await hardhatClockPayment.sendTime();
            expect(await hardhatCLOCKToken.balanceOf(otherAccount.address)).to.equal(ethers.utils.parseEther("102.0"))
        })

        
        it("Should accept Permit signatures", async function() {
            const {hardhatCLOCKToken, hardhatClockPayment, owner, otherAccount} = await loadFixture(deployClocktowerFixture);
            //adds CLOCK to approved tokens
            await hardhatClockPayment.addERC20Contract(clockTokenAddress)

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
            
        
            expect(await hardhatClockPayment.addPermitTransaction(otherAccount.address, hourAhead, eth, ethers.utils.getAddress(clockTokenAddress), signedPermit, testParams))
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
            await hardhatClockSubscribe.addERC20Contract(clockTokenAddress)

            expect(await hardhatClockSubscribe.createSubscription(eth, hardhatCLOCKToken.address, "Test",1,15, testParams))

        })

        it("Should get created subscriptions", async function() {
            const {hardhatCLOCKToken, hardhatClockSubscribe, owner, otherAccount} = await loadFixture(deployClocktowerFixture);
            
            //adds CLOCK to approved tokens
            await hardhatClockSubscribe.addERC20Contract(clockTokenAddress)
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
            await hardhatClockSubscribe.addERC20Contract(clockTokenAddress)
            await hardhatClockSubscribe.createSubscription(eth, hardhatCLOCKToken.address, "Test",1,15, testParams)
            await hardhatClockSubscribe.createSubscription(eth, hardhatCLOCKToken.address, "Test2",2,15, testParams)

            let subscriptions = await hardhatClockSubscribe.getAccountSubscriptions(false)

            await hardhatClockSubscribe.subscribe(subscriptions[1].subscription, testParams2)

            let aSubscriptions = await hardhatClockSubscribe.getAccountSubscriptions(true)

            expect(aSubscriptions[0].subscription.description).to.equal("Test2");
            
        })
        it("Should allow user to unsubscribe", async function() {
            const {hardhatCLOCKToken, hardhatClockSubscribe, owner, otherAccount} = await loadFixture(deployClocktowerFixture);
            
            //adds CLOCK to approved tokens
            await hardhatClockSubscribe.addERC20Contract(clockTokenAddress)
            await hardhatClockSubscribe.createSubscription(eth, hardhatCLOCKToken.address, "Test",1,15, testParams)
            await hardhatClockSubscribe.createSubscription(eth, hardhatCLOCKToken.address, "Test",2,15, testParams)

            let subscriptions = await hardhatClockSubscribe.getAccountSubscriptions(false)

            await hardhatClockSubscribe.subscribe(subscriptions[1].subscription, testParams)

            await hardhatClockSubscribe.unsubscribe(subscriptions[1].subscription.id, testParams);

            let result = await hardhatClockSubscribe.getAccountSubscriptions(true)
            
            expect(result[0].status).to.equal(2)
        })
        it("Should cancel subscription", async function(){
            const {hardhatCLOCKToken, hardhatClockSubscribe, owner, otherAccount} = await loadFixture(deployClocktowerFixture);
            
            //adds CLOCK to approved tokens
            await hardhatClockSubscribe.addERC20Contract(clockTokenAddress)
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
            await hardhatClockSubscribe.addERC20Contract(clockTokenAddress)

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


            await time.increaseTo(twoHoursAhead);

            await hardhatClockSubscribe.chargeSubs();

            let otherBalance = await hardhatCLOCKToken.balanceOf(otherAccount.address)
            let ownerBalance = await hardhatCLOCKToken.balanceOf(owner.address)

            let expected = ethers.utils.parseEther("93.0");

            expect(otherBalance).to.equal(expected)
            //expect(ownerBalance).to.equal()

            
        })
        
    })
})