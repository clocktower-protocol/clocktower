// SPDX-License-Identifier: UNLICENSED
//Written by Hugo Marx
pragma solidity ^0.8.9;

import "hardhat/console.sol";

contract Clocktower {

    constructor() payable {
    }

    //global struct for future transactions
    struct Transaction {
        bytes32 id;
        address sender;
        address payable receiver;
        //timeTrigger and arrayIndex make a unique key per transaction.
        uint40 timeTrigger;
        bool sent;
        bool cancelled;
        //amount of ether sent in wei
        uint payload;
    }

    //acount struct
    struct Account {
        address accountAddress;
        //string description;
        bool exists;
        uint balance;
    }

    //batch struct
    struct Batch {
        address payable receiver;
        uint40 unixTime;
        uint payload;
    }

    /*
    //global struct for Watchers
    struct Watcher {
        address watcherAddress;

    }
    */

    //Account map
    mapping(address => Account) private accountMap;
    //Map of transactions based on account
    mapping(address => Transaction[]) private accountTransactionsMap;

    //Initialize an array of transactions keyed to uint40 hour number.
    //This makes it very fast to look up transactions by time.
    //Map of arrays of transaction structs keyed to hour number send time

    mapping(uint40 => Transaction[]) private timeMap;

    //seconds since merge
    uint40 unixMergeTime = 1663264800;

    //TODO: set fee(0.003%? same as Uniswap)
    uint fee = 1;

    //variable for last checked by hour
    //uint40 lastCheckedTimeSlot = (hoursSinceMerge(uint40(block.timestamp)) - 1);
    uint40 lastCheckedTimeSlot = (hoursSinceMerge(uint40(block.timestamp)) - 1);
    
    //Emits
    event TransactionAdd(address sender, address receiver, uint40 timeTrigger, uint payload);
    event Status(string output);
    event CheckStatus(string output2);
    event TransactionSent(bool sent);
    event HoursCalc(bool houseSent);
    event UnknownFunction(string output3);
    event ReceiveETH(address user, uint amount);
    event AccountCreated(string output4);

    //functions for receiving ether
    receive() external payable{
        emit ReceiveETH(msg.sender, msg.value);
    }
    fallback() external payable{
        emit UnknownFunction("Unknown function");
    }

    //ADMIN METHODS*************************************
    function setAdmin() public  {

    }

    //**************************************************

    function getBalance() internal view returns (uint){
        return address(this).balance;
    }
    //////////////////////

    //gets time TESTING FUNCTION
    function getTime() external view returns (uint) {
        return block.timestamp;
    }

     //converts time to hours after merge
    function hoursSinceMerge(uint40 unixTime) public  returns(uint40 hourCount){

        //TODO: need to do with safe math libraries. Leap years don't work. Could maybe fix?

        hourCount = (unixTime - unixMergeTime)/3600;

        emit HoursCalc(true);

        return hourCount;
    }

    //converts hours since merge to unix epoch utc time
    function unixFromHours(uint40 timeTrigger) private view returns(uint40 unixTime) {
        unixTime = (unixMergeTime + (timeTrigger*3600));
        return unixTime;
    }

    //gets transactions from account
    function getAccountTransactions() public view returns (Transaction[] memory transactions){
        //account info can only be accessed by itself
        //require(msg.sender == account, "Wrong account access attempted");
        transactions = accountTransactionsMap[msg.sender];

        //iterates through array and changes dates to unixEpochTime
        for(uint i = 0; i < transactions.length; i++) {
                transactions[i].timeTrigger = unixFromHours(transactions[i].timeTrigger);
        }
        
        return transactions;

    }
    
    //sets Transaction
    function setTransaction(address sender, address payable receiver, uint40 timeTrigger, uint payload) internal view returns(Transaction memory _transaction){
        
            //creates id hash
            bytes32 id = keccak256(abi.encodePacked(sender, timeTrigger, block.timestamp));
            
            _transaction = Transaction(id, sender, receiver, timeTrigger, false, false, payload);

            return _transaction;

    }

    //cancels transaction and refunds money
    function cancelTransaction(bytes32 id, uint40 timeTrigger) payable public {

        Transaction[] memory accountTransactions = accountTransactionsMap[msg.sender];
        Transaction[] memory timeTransactions = timeMap[timeTrigger];
        Transaction[] storage accountStorageT = accountTransactionsMap[msg.sender];
        Transaction[] storage timeStorageT = timeMap[timeTrigger];

        Transaction memory transaction;

        //loops through account transactions to find cancelled one
        for(uint i = 0; i < accountTransactions.length; i++) {
            if(accountTransactions[i].id == id){
                transaction = accountTransactions[i];
                transaction.cancelled = true;
                accountStorageT[i] = transaction;
                break;
            }
        }
        //loops through time transactions to find cancelled one
        for(uint i = 0; i < timeTransactions.length; i++) {
            //TODO: check if changing this to id works
            if(timeTransactions[i].id == id){
                transaction = timeTransactions[i];
                transaction.cancelled = true;
                timeStorageT[i] = transaction;
                break;
            }
        }
        
        //checks contract has enough ETH
        require(getBalance() > transaction.payload);
        //checks transaction goes through
        require(payable(transaction.sender).send(transaction.payload));

        accountTransactionsMap[msg.sender] = accountStorageT;
        timeMap[timeTrigger] = timeStorageT;

    }

    //sends transaction
    function sendTransaction(Transaction memory transaction) private {

        //TODO: could change from send bool to transaction confirm hash

        //checks contract has enough ETH
        require(getBalance() > transaction.payload);
        //checks transaction goes through
        require(transaction.receiver.send(transaction.payload));

        Transaction[] memory accountTransactions = accountTransactionsMap[transaction.sender];
        Transaction[] memory timeTransactions = timeMap[transaction.timeTrigger];
        Transaction[] storage accountStorageT = accountTransactionsMap[transaction.sender];
        Transaction[] storage timeStorageT = timeMap[transaction.timeTrigger];


        //loops through account transactions to stamp sent one
        for(uint i = 0; i < accountTransactions.length; i++) {
            if(accountTransactions[i].id == transaction.id){
                transaction = accountTransactions[i];
                transaction.sent = true;
                accountStorageT[i] = transaction;
                break;
            }
        }
        //loops through time transactions to stamp sent one
        for(uint i = 0; i < timeTransactions.length; i++) {
            if(timeTransactions[i].id == transaction.id){
                transaction = timeTransactions[i];
                transaction.sent = true;
                timeStorageT[i] = transaction;
                break;
            }
        }
         //updates the transaction to reflect sent status
        //transaction.sent = true; 

        //puts back in map
        accountTransactionsMap[transaction.sender] = accountStorageT;
        timeMap[transaction.timeTrigger] = timeStorageT;
        //Transaction[] memory _transactionArray = timeMap[transaction.timeTrigger];
       // _transactionArray[transaction.arrayIndex] = transaction;

        emit TransactionSent(true);
       
    }

    

    //adds to list of transactions 
    function addTransaction(address payable receiver, uint40 unixTime, uint payload) payable external {

        //require transactions to be in the future and to be on the hour
        require(unixTime > block.timestamp, "Time data must be in the future");

        require(unixTime % 3600 == 0, "Time must be on the hour");
        
        //require sent ETH to be higher than payload * fee
        require(payload <= (msg.value * fee), "Not enough ETH sent with transaction");
        
        //calculates hours since merge from passed unixTime
        uint40 timeTrigger = hoursSinceMerge(unixTime);

        //Looks up array for timeTrigger. If no array exists it populates it. If it already does it appends it.
        Transaction[] storage timeStorageArray = timeMap[timeTrigger]; 
        Transaction[] storage accountStorageArray = accountTransactionsMap[msg.sender]; 

         //creates transaction
        Transaction memory transaction = setTransaction(msg.sender, receiver, timeTrigger, payload);

        timeStorageArray.push() = transaction;
        accountStorageArray.push(transaction);

        emit TransactionAdd(msg.sender, receiver, timeTrigger, payload);
        emit Status("Pushed");

        //puts appended arrays back in maps
 
        timeMap[timeTrigger] = timeStorageArray;   
        accountTransactionsMap[msg.sender] = accountStorageArray;  
        
       //adds or updates account
       Account memory account = accountMap[msg.sender];

        //updates account
        account.balance = msg.value + account.balance;

        if(accountMap[msg.sender].exists == false) {
            account.accountAddress = msg.sender;
            account.exists = true;
        }

        //adds new account to account map
        accountMap[msg.sender] = account;
    }

    //REQUIRE transactions all be scheduled for the same time
    function addBatchTransactions(Batch[] memory batch) payable external {

        require(batch.length > 1, "Batch must have more than one transaction");

        uint payloads  = 0;
        uint40 unixTime = 0;

        //validates data in each transaction
        for(uint i = 0; i < batch.length; i++) {

            //require transactions to be in the future and to be on the hour
            require(batch[i].unixTime > block.timestamp, "Time data must be in the future");

            require(batch[i].unixTime % 3600 == 0, "Time must be on the hour");

             //catches first time Trigger and compares it to all the others to make sure the batch transactions are scheduled for the same time
            if(i == 0) {
                unixTime = batch[i].unixTime;
            } else {
                require(unixTime == batch[i].unixTime, "All batch transactions must be scheduled for the same time");
            }

            //sums up all listed payloads
            payloads += batch[i].payload;
        }

        //makes sure enough ETH was sent in payloads
        //require sent ETH to be higher than payload * fee
        require(payloads <= (msg.value * fee), "Not enough ETH sent with transaction");

        //since unixTime should be the same for all transactions. You only calulate the time trigger once. 
        uint40 timeTrigger = hoursSinceMerge(unixTime);

        //Looks up array for timeTrigger. If no array exists it populates it. If it already does it appends it.
        Transaction[] storage transactionStorageArray = timeMap[timeTrigger];
        Transaction[] storage accountTransactions = accountTransactionsMap[msg.sender];

        //creates transaction array
        for(uint16 i = 0; i < batch.length; i++) {

            //creates internal transaction struct
            Transaction memory transaction = setTransaction(msg.sender, batch[i].receiver, timeTrigger, batch[i].payload);

            transactionStorageArray.push() = transaction;
            accountTransactions.push() = transaction;
        }

        timeMap[timeTrigger] = transactionStorageArray; 
        accountTransactionsMap[msg.sender] = accountTransactions;

        //updates account
        Account memory account = accountMap[msg.sender];

        account.balance = msg.value + account.balance;

        if(accountMap[msg.sender].exists == false) {
            account.accountAddress = msg.sender;
            account.exists = true;
        }

        //adds new account to account map
        accountMap[msg.sender] = account;

    }


    //checks list of blocks between now and when it was last checked
    function checkTime() public {

        //gets current time slot based on hour
        uint40 _currentTimeSlot = hoursSinceMerge(uint40(block.timestamp));

        require(_currentTimeSlot > lastCheckedTimeSlot, "Time already checked for this time slot");

        for(uint40 i = lastCheckedTimeSlot; i <= _currentTimeSlot; i++) {

            //gets transaction array per block
            Transaction[] memory _transactionArray = timeMap[i];

            emit CheckStatus("done");
            
            //if block has transactions add them to transaction list
            if(_transactionArray.length > 0) {
                
                //iterates through transaction array
                for(uint h = 0; h <= (_transactionArray.length - 1); h++){

                    //excludes cancelled transactions
                    if(!_transactionArray[h].cancelled){
                        //sends transactions
                        sendTransaction(_transactionArray[h]);
                    }
                }               
            }
        }

        //updates lastCheckedTimeSlot
        lastCheckedTimeSlot = _currentTimeSlot;

    }

}