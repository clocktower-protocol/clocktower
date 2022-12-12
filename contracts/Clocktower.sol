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
        //FIXME: arrayIndex probably isn't necessary with id
        //timeTrigger and arrayIndex make a unique key per transaction.
        uint40 timeTrigger;
       // uint16 arrayIndex;
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

    //global struct for Watchers
    struct Watcher {
        address watcherAddress;

    }

    //Account map
    mapping(address => Account) private accountMap;
    //Map of transactions based on account
    mapping(address => Transaction[]) private accountTransactionsMap;

    //Initialize an array of transactions keyed to uint blocknumber.
    //This makes it very fast to look up transactions by time.
    //Map of arrays of transaction structs keyed to block number send time

    mapping(uint => Transaction[]) private timeMap;

    //blocks since merge
    uint32 blockMergeTime = 15537393;
    //seconds since merge
    uint40 unixMergeTime = 1663264800;

    //TODO: set fee
    uint fee = 1;

    //variable for last checked time block
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

    function getAccount() external view returns (Account memory returnAccount){
        
        //account info can only be accessed by itself
        //require(msg.sender == account, "Wrong account access attempted");

        returnAccount = accountMap[msg.sender];
        return returnAccount;

    }

    /*
    //set account
    function setAccount(bool exists, uint balance) internal  view returns (Account memory account){
        account  = Account(msg.sender, exists, balance);

        return account;
    }
    */

    //adds account
    function addAccount(Account memory account) private {

        //checks if account already exists
        if(!accountMap[msg.sender].exists) {

            accountMap[msg.sender] = account; 
            emit AccountCreated("Account created");
        } else {
            emit AccountCreated("Account already exists");
            //updates account
            accountMap[msg.sender] = account;
        }

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


    //gets transaction array from block
    function getTimeTransactions(uint40 timeTrigger) private view returns(Transaction[] storage transactionArray){

       return timeMap[timeTrigger];

    }

    
    //sets transaction array to transaction block map
    function setTransactionArray(Transaction[] storage transactionArray, uint40 timeTrigger) private {
        timeMap[timeTrigger] = transactionArray;

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
        Transaction[] storage _transactionArray = getTimeTransactions(timeTrigger);  
        
        //gets length of array to populate arrayIndex in transaction
        //uint16 arrayLength = uint16(_transactionArray.length);

         //creates transaction
        Transaction memory transaction = setTransaction(msg.sender, receiver, timeTrigger, payload);

        _transactionArray.push() = transaction;

        emit TransactionAdd(msg.sender, receiver, timeTrigger, payload);
        emit Status("Pushed");

        //puts appended array back in time map

        setTransactionArray(_transactionArray, timeTrigger);      
        
        //gets transactions from existing or zero for new and adds new transaction

        if(accountMap[msg.sender].exists == true) {
            Account memory account = accountMap[msg.sender];

            //updates account
            account.balance = msg.value + account.balance;

            Transaction[] storage accountTransactions = accountTransactionsMap[msg.sender];
            
            //updates transaction array
            accountTransactions.push(transaction);

            accountTransactionsMap[msg.sender] = accountTransactions;

            //adds new account to account map
            accountMap[msg.sender] = account;
        } else {
            //new account
            Account memory account = accountMap[msg.sender];

            //updates account
            account.balance = msg.value + account.balance;
            account.accountAddress = msg.sender;
            account.exists = true;

            Transaction[] storage accountTransactions = accountTransactionsMap[msg.sender];
            
            //updates transaction array
            accountTransactions.push(transaction);

            accountTransactionsMap[msg.sender] = accountTransactions;

            //adds new account to account map
            accountMap[msg.sender] = account;
        }
           
    }

    //TODO:
    //REQUIRE they all be sent at the same time?
    /*
    function batchAddTransactions(Batch[] memory batch) payable external {

        require(batch.length > 1, "Batch must have more than one transaction");

        uint payloads  = 0;
        uint40 unixTime = 0;

        //validates data in each transaction
        for(uint i = 0; i <= batch.length; i++) {

            //require transactions to be in the future and to be on the hour
            require(batch[i].unixTime > block.timestamp, "Time data must be in the future");

            require(batch[i].unixTime % 3600 == 0, "Time must be on the hour");

             //catches first time Trigger and compares it to all the others to make sure the batch is sending at the same time
            if(i == 0) {
                unixTime = batch[i].unixTime;
            } else {
                require(unixTime == batch[i].unixTime, "All batch transactions must be sent at the same time");
            }

            //sums up all listed payloads
            payloads += batch[i].payload;
        }

        //makes sure enough ETH was sent in payloads
        //require sent ETH to be higher than payload * fee
        require(payloads <= (msg.value * fee), "Not enough ETH sent with transaction");

        //Looks up array for timeTrigger. If no array exists it populates it. If it already does it appends it.
        Transaction[] storage _transactionArray = getTimeTransactions(hoursSinceMerge(unixTime));

        //gets length of array to populate arrayIndex in transaction
        uint16 arrayLength = uint16(_transactionArray.length);

        Transaction[] memory transactionMemoryArray;

        //creates transaction array
        for(uint16 i = 0; i <= batch.length; i++) {

            //calculates hours since merge from passed unixTime
            uint40 timeTrigger = hoursSinceMerge(batch[i].unixTime);
            //creates internal transaction struct
            Transaction memory transaction = setTransaction(msg.sender, batch[i].receiver, timeTrigger, (i + arrayLength), batch[i].payload);
            transactionMemoryArray[i] = transaction;
        }

        //FIXME: this might make batch transaction use the same or more gas as individual
        _transactionArray.push() = transactionMemoryArray;

    }
    */

    //checks list of blocks between now and when it was last checked
    function checkTime() public {

        //gets current time slot based on hour
        uint40 _currentTimeSlot = hoursSinceMerge(uint40(block.timestamp));

        require(_currentTimeSlot > lastCheckedTimeSlot, "Time already checked for this time slot");

        for(uint i = lastCheckedTimeSlot; i <= _currentTimeSlot; i++) {

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