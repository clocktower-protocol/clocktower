import { loadFixture } from "@nomicfoundation/hardhat-network-helpers";
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
    //hour merge occured
    //let mergeTime = 1663264800;
    let mergeTime = 0;
    let hoursSinceMerge = Math.floor((currentTime - mergeTime) /3600);
    //eth sent
    let eth = ethers.utils.parseEther("1.0")

    //sends test data of an hour ago
    let hourAgo = currentTime - 3600;
    let hourAhead = currentTime + 3600;
    let twoHoursAhead = hourAhead + 3600;
    let threeHoursAhead = twoHoursAhead + 3600;

    //CLOCKtoken address
    const clockTokenAddress = "0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512";
    //DAI address
    const daiAddress = "0x6B175474E89094C44Da98b954EedeAC495271d0F";

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

        const Clocktower = await ethers.getContractFactory("Clocktower");
        const ClockToken = await ethers.getContractFactory("CLOCKToken");
        const [owner, otherAccount] = await ethers.getSigners();

        const hardhatClocktower = await Clocktower.deploy();
        const hardhatCLOCKToken = await ClockToken.deploy(ethers.utils.parseEther("100000"));
        const addressZero = ethers.constants.AddressZero;

        await hardhatClocktower.deployed();
        await hardhatCLOCKToken.deployed();

         //starts contract with 100 ETH
         const params = {
            from: owner.address,
            to: hardhatClocktower.address,
            value: ethers.utils.parseEther("100.0")
        };
        await owner.sendTransaction(params);

        let params2 = {
            value: eth
        }

        //approves token
        //await hardhatClocktower.addERC20Contract(hardhatCLOCKToken.address);
         //signs permit
         //let signedPermit = await setPermit(owner, hardhatClocktower.address, "1", 1766556423)

        await hardhatCLOCKToken.approve(hardhatClocktower.address, infiniteApproval)


        //creates several transaactions to test transaction list
       // await hardhatClocktower.addTransaction(otherAccount.address, 1672560000, eth, hardhatCLOCKToken.address, signedPermit, params2);
        await hardhatClocktower.addTransaction(otherAccount.address, hourAhead, eth, ethers.constants.AddressZero,params2);
        await hardhatClocktower.addTransaction(otherAccount.address, hourAhead, eth, ethers.constants.AddressZero,params2);
    

        //moves time 2 hours to 2023/01/01 3:00
        //await time.increaseTo(1672563600);


        return { Clocktower, hardhatClocktower, owner, otherAccount, hardhatCLOCKToken } ;
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

    //Account tests
    describe("Account", function() {

        const testParams = {
            value: eth
        };


        it("Should get transactions by account", async function() {
            const {hardhatClocktower, owner, otherAccount} = await loadFixture(deployClocktowerFixture);
            await hardhatClocktower.addTransaction(otherAccount.address, hourAhead, eth, ethers.constants.AddressZero, testParams)
            let transactions: any = await hardhatClocktower.getAccountTransactions();
            
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

        it("Should add transactions", async function(){
            const {hardhatClocktower, owner, otherAccount} = await loadFixture(deployClocktowerFixture);

            //Add transaction to contract
            await expect(
                hardhatClocktower.addTransaction(otherAccount.address, hourAhead ,eth , ethers.constants.AddressZero, testParams)
            ).to.emit(hardhatClocktower, "TransactionAdd")
            .withArgs(owner.address, otherAccount.address, ((currentTime / 3600) + 1), eth);
        })
        it("Should output status", async function() {
            const {hardhatClocktower, owner, otherAccount} = await loadFixture(deployClocktowerFixture);
            //get status output
            await expect(
                hardhatClocktower.addTransaction(otherAccount.address, hourAhead, eth, ethers.constants.AddressZero, testParams)
            ).to.emit(hardhatClocktower, "StatusEmit")
            .withArgs("Pushed");
        })
        it("Should send eth with the transaction", async function() {
            const {hardhatClocktower, owner, otherAccount} = await loadFixture(deployClocktowerFixture);
           
            await hardhatClocktower.addTransaction(otherAccount.address, hourAhead, eth, ethers.constants.AddressZero, testParams)
            expect(
                await ethers.provider.getBalance(hardhatClocktower.address)
            ).to.equals(ethers.utils.parseEther("103.0"))

        })

        it("Should remove transaction", async function() {
            const {hardhatClocktower, owner, otherAccount} = await loadFixture(deployClocktowerFixture);
            //await hardhatClocktower.addTransaction(otherAccount.address, hourAhead, eth, testParams)
            let transactions: any = await hardhatClocktower.getAccountTransactions();
            await hardhatClocktower.cancelTransaction(transactions[0].id, transactions[0].timeTrigger, transactions[0].token)
            let transactions2: any = await hardhatClocktower.getAccountTransactions();
            expect(
                transactions2.length
            ).lessThan(transactions.length);

        })
        
    })
    
    describe("Send Time", function(){
        
        it("Should send transactions", async function(){
            const {hardhatClocktower, owner, otherAccount} = await loadFixture(deployClocktowerFixture);
            await time.increaseTo(twoHoursAhead);
            await expect(
                hardhatClocktower.sendTime()
            ).to.emit(hardhatClocktower, "TransactionSent")
            .withArgs(true);
        }) 
        it("Should send ether to addresses", async function() {
            const {hardhatClocktower, owner, otherAccount} = await loadFixture(deployClocktowerFixture);
            await hardhatClocktower.sendTime();
            expect(
                await ethers.provider.getBalance(otherAccount.address)
            ).to.greaterThan(ethers.utils.parseEther("1007.0"))
        })
        it("Should find day of month", async function() {
            const {hardhatClocktower, owner, otherAccount} = await loadFixture(deployClocktowerFixture);
            expect(await hardhatClocktower.unixTimeToDayMonthYear(1739340000))

        })
        
    })
    
    describe("Batch Functions", function() {
        it("Should add transactions", async function() {
            const {hardhatClocktower, hardhatCLOCKToken, owner, otherAccount} = await loadFixture(deployClocktowerFixture);

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
            await hardhatClocktower.addERC20Contract(clockTokenAddress)
            await hardhatClocktower.addERC20Contract(daiAddress)

            //gives approval to token transfer
            await hardhatCLOCKToken.approve(hardhatClocktower.address, eths)

            //add batch
            // await hardhatClocktower.addBatchTransactions(transactions, testParams)
            await hardhatClocktower.addBatchTransactions(transactions, testParams)

            //gets total claims
            let claims = await hardhatClocktower.getTotalClaims(clockTokenAddress);

            let returnTransactions: any = await hardhatClocktower.getAccountTransactions();


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
            const {hardhatClocktower, owner, otherAccount} = await loadFixture(deployClocktowerFixture);

            let returnTransactions: any = await hardhatClocktower.allTransactions();

            expect(returnTransactions.length).to.equal(2)
            expect(returnTransactions[1].payload).to.equal(eth)
            
        })
        it("Should get accounts snapshot", async function() {
            const {hardhatClocktower, owner, otherAccount} = await loadFixture(deployClocktowerFixture);

            let returnAccounts: any = await hardhatClocktower.allAccounts();

            expect(returnAccounts.length).to.equal(1)
            expect(returnAccounts[0].accountAddress).to.equal(owner.address)
        })
        it("Should allow to remove ERC20", async function(){
            const {hardhatClocktower, owner, otherAccount} = await loadFixture(deployClocktowerFixture);

            await hardhatClocktower.addERC20Contract("0x6B175474E89094C44Da98b954EedeAC495271d0F")
            await hardhatClocktower.addERC20Contract("0xdAC17F958D2ee523a2206206994597C13D831ec7")
            expect(await hardhatClocktower.removeERC20Contract("0x6B175474E89094C44Da98b954EedeAC495271d0F"))
        })
        it("Should get balance of CLOCK token", async function() {
            const {hardhatCLOCKToken, owner, otherAccount} = await loadFixture(deployClocktowerFixture);

            let amount = await hardhatCLOCKToken.balanceOf(owner.address)

            expect(amount).to.equal(ethers.utils.parseEther("100000"))
        })
        it("Should change fee", async function() {
            const {hardhatClocktower, owner, otherAccount} = await loadFixture(deployClocktowerFixture);
            await hardhatClocktower.changeFee(102);
            await hardhatClocktower.addTransaction(otherAccount.address, hourAhead, eth, ethers.constants.AddressZero, testParams)
            let returnTransactions: any = await hardhatClocktower.allTransactions();
            expect(returnTransactions.length).to.equal(3)
        })
       
    })
 
    describe("ERC20 Functions", function() {
        const testParams = {
            value: eth
        };

        it("Should add an ERC20 Transaction", async function() {
            const {hardhatCLOCKToken, hardhatClocktower, owner, otherAccount} = await loadFixture(deployClocktowerFixture);
            //adds CLOCK to approved tokens
            await hardhatClocktower.addERC20Contract(clockTokenAddress)
            //User gives approval for clocktower to use their tokens
            await hardhatCLOCKToken.approve(hardhatClocktower.address, infiniteApproval)
           // let signedPermit = await setPermit(owner, hardhatClocktower.address, "1", 1766556423)

            await hardhatClocktower.addTransaction(otherAccount.address, hourAhead, eth, ethers.utils.getAddress(clockTokenAddress), testParams)

            //expect(await hardhatCLOCKToken.balanceOf(hardhatClocktower.address)).to.equal(eth)
        })
        
        it("Should send ERC20 Tokens", async function() {
            const {hardhatCLOCKToken, hardhatClocktower, owner, otherAccount} = await loadFixture(deployClocktowerFixture);
            //adds CLOCK to approved tokens
            await hardhatClocktower.addERC20Contract(clockTokenAddress)

            //User gives approval for clocktower to use their tokens
            //await hardhatCLOCKToken.approve(hardhatClocktower.address, eth)
            //signs permit
            let signedPermit = await setPermit(owner, hardhatClocktower.address, "1", 1766556423)
            await hardhatClocktower.addPermitTransaction(otherAccount.address, hourAhead, eth, ethers.utils.getAddress(clockTokenAddress), signedPermit, testParams)
            let signedPermit2 = await setPermit(owner, hardhatClocktower.address, "1", 1766556423)
            await hardhatClocktower.addPermitTransaction(otherAccount.address, hourAhead, eth, ethers.utils.getAddress(clockTokenAddress), signedPermit2, testParams)

            //moves time 2 hours to 2023/01/01 3:00
            //await time.increaseTo(1672563600);
            await time.increaseTo(twoHoursAhead);
            await hardhatClocktower.sendTime();
            expect(await hardhatCLOCKToken.balanceOf(otherAccount.address)).to.equal(ethers.utils.parseEther("2.0"))
        })

        it("Should accept Permit signatures", async function() {
            const {hardhatCLOCKToken, hardhatClocktower, owner, otherAccount} = await loadFixture(deployClocktowerFixture);
            //adds CLOCK to approved tokens
            await hardhatClocktower.addERC20Contract(clockTokenAddress)

            //console.log(await hardhatCLOCKToken.DOMAIN_SEPARATOR());
            
            //signs permit
            let signedPermit = await setPermit(owner, hardhatClocktower.address, "1", 1766556423)

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
            
        
            expect(await hardhatClocktower.addPermitTransaction(otherAccount.address, hourAhead, eth, ethers.utils.getAddress(clockTokenAddress), signedPermit, testParams))
           // expect(await hardhatCLOCKToken.balanceOf(hardhatClocktower.address)).to.equal(ethers.utils.parseEther("1"));

        })

    })
})