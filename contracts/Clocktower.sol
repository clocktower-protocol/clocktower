// SPDX-License-Identifier: UNLICENSED
//Written by Hugo Marx
pragma solidity ^0.8.9;

import "hardhat/console.sol";

contract Clocktower {

    constructor() payable {
    }

    //DATA-------------------------------------------------------
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
        uint40[] timeTriggers;
    }

    //batch struct
    struct Batch {
        address payable receiver;
        uint40 unixTime;
        uint payload;
    }

    //Account map
    mapping(address => Account) private accountMap;
     //creates lookup table for mapping
    address[] private accountLookup;

    
    //creates lookup table for transactions
    bytes32[] private transactionLookup;

    //Map of transactions based on hour to be sent
    mapping(uint40 => Transaction[]) private timeMap;

    //admin addresses
    address admin = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;

    //circuit breaker
    bool stopped = false;

    //seconds since merge
    uint40 unixMergeTime = 1663264800;

    //TODO: set fee(0.003%? same as Uniswap)
    uint fee = 1;

    //variable for last checked by hour
    uint40 lastCheckedTimeSlot = (hoursSinceMerge(uint40(block.timestamp)) - 1);

    //---------------------------------------------------------------------------------
    
    //Emits
    event TransactionAdd(address sender, address receiver, uint40 timeTrigger, uint payload);
    event Status(string output);
    event CheckStatus(string output2);
    event TransactionSent(bool sent);
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
    
    //checks if user is admin
    modifier isAdmin() {
        require(msg.sender == admin);
        _;
    }

    function changeAdmin(address newAddress) isAdmin external {
        require((msg.sender == newAddress) && (newAddress != address(0)));

        admin = newAddress;
    }

    //emergency circuit breaker controls
    function toggleContractActive() isAdmin external {
        // You can add an additional modifier that restricts stopping a contract to be based on another action, such as a vote of users
        stopped = !stopped;
    }
    modifier stopInEmergency { if (!stopped) _; }
    modifier onlyInEmergency { if (stopped) _; }

    //TODO:
    
    //returns array containing all transactions
    function allTransactions() isAdmin external view returns (Transaction[] memory){

        Transaction[] memory totalTransactions = new Transaction[](transactionLookup.length);

        uint count = 0;

        //for each account
        for(uint i = 0; i < accountLookup.length; i++) {

            //&&
            Transaction[] memory accountTransactions = getTransactionsByAccount(accountLookup[i]);
            
            //adds each transaction to total array
            for(uint j = 0; j < accountTransactions.length; j++) {
                //Transaction memory transaction = accountTransactions[j];
                totalTransactions[count] = accountTransactions[j];
                count++;
            }
        }

        return totalTransactions;
    }

    //returns all accounts
    function allAccounts() isAdmin external view returns(Account[] memory){

        Account[] memory totalAccounts = new Account[](accountLookup.length);

        //for each account
        for(uint i = 0; i < accountLookup.length; i++) {
            totalAccounts[i] = accountMap[accountLookup[i]];
        }

        return totalAccounts;
    }

    function getTransactionsByAccount(address account) isAdmin public view returns (Transaction[] memory){
       
        uint40[] memory timeTriggers = accountMap[account].timeTriggers;

        //gets total amount of transactions
        uint total = 0;
        for(uint i = 0; i < timeTriggers.length; i++) {
            Transaction[] memory lengthArray = timeMap[timeTriggers[i]];
            total += lengthArray.length;
        }
        
        Transaction[] memory subsetTransactions = new Transaction[](total);
        Transaction[] memory totalTransactions = new Transaction[](total);
        uint count = 0;

        //loops through time triggers
        for(uint i = 0; i < timeTriggers.length; i++) {
            subsetTransactions = timeMap[timeTriggers[i]];

            //adds transactions to total
            for(uint j = 0; j < subsetTransactions.length; j++) {
                totalTransactions[count] = subsetTransactions[j];
                count++;
            }
        }

        
         //iterates through array and changes dates to unixEpochTime
        for(uint i = 0; i < totalTransactions.length; i++) {
                totalTransactions[i].timeTrigger = unixFromHours(totalTransactions[i].timeTrigger);
        }
    
        //return transactions;
        return totalTransactions;

    }
    

    //**************************************************

    //UTILITY FUNCTIONS-----------------------------------

    function getBalance() internal view returns (uint){
        return address(this).balance;
    }
    //////////////////////

    //gets time TESTING FUNCTION
    function getTime() external view returns (uint) {
        return block.timestamp;
    }

     //converts time to hours after merge
    function hoursSinceMerge(uint40 unixTime) public view returns(uint40 hourCount){

        //TODO: need to do with safe math libraries. Leap years don't work. Could maybe fix?

        hourCount = (unixTime - unixMergeTime)/3600;

        return hourCount;
    }

    //converts hours since merge to unix epoch utc time
    function unixFromHours(uint40 timeTrigger) private view returns(uint40 unixTime) {
        unixTime = (unixMergeTime + (timeTrigger*3600));
        return unixTime;
    }

    //gets transactions from account
    function getAccountTransactions() external view returns (Transaction[] memory){
        //account info can only be accessed by itself
       
        uint40[] memory timeTriggers = accountMap[msg.sender].timeTriggers;

        //gets total amount of transactions
        uint total = 0;
        for(uint i = 0; i < timeTriggers.length; i++) {
            Transaction[] memory lengthArray = timeMap[timeTriggers[i]];
            total += lengthArray.length;
        }
        
        Transaction[] memory subsetTransactions = new Transaction[](total);
        Transaction[] memory totalTransactions = new Transaction[](total);
        uint count = 0;

        //loops through time triggers
        for(uint i = 0; i < timeTriggers.length; i++) {
            subsetTransactions = timeMap[timeTriggers[i]];

            //adds transactions to total
            for(uint j = 0; j < subsetTransactions.length; j++) {
                totalTransactions[count] = subsetTransactions[j];
                count++;
            }
        }

        
         //iterates through array and changes dates to unixEpochTime
        for(uint i = 0; i < totalTransactions.length; i++) {
                totalTransactions[i].timeTrigger = unixFromHours(totalTransactions[i].timeTrigger);
        }
        
        //--------------------------
    
        //return transactions;
        return totalTransactions;
    }
    
    //sets Transaction
    function setTransaction(address sender, address payable receiver, uint40 timeTrigger, uint payload) internal view returns(Transaction memory _transaction){
        
            //creates id hash
            bytes32 id = keccak256(abi.encodePacked(sender, timeTrigger, block.timestamp));
            
            _transaction = Transaction(id, sender, receiver, timeTrigger, false, false, payload);

            return _transaction;
    }

    //------------------------------------------------------------

    //cancels transaction and refunds money
    function cancelTransaction(bytes32 id, uint40 timeTrigger) payable external {

        //converts time trigger to hour
        timeTrigger = hoursSinceMerge(timeTrigger);

        Transaction[] memory timeTransactions = timeMap[timeTrigger];
        Transaction[] storage timeStorageT = timeMap[timeTrigger];

        Transaction memory transaction;

        //loops through time transactions to find cancelled one
        for(uint i = 0; i < timeTransactions.length; i++) {

            //console.log(timeTransactions.length);
            
            if(timeTransactions[i].id == id){
                //console.log("yes");
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

        //accountTransactionsMap[msg.sender] = accountStorageT;
        timeMap[timeTrigger] = timeStorageT;

    }

    //sends transaction
    function sendTransaction(Transaction memory transaction) stopInEmergency private {

        //TODO: could change from send bool to transaction confirm hash

        //checks contract has enough ETH
        require(getBalance() > transaction.payload);
       
        Transaction[] memory timeTransactions = timeMap[transaction.timeTrigger];
        Transaction[] storage timeStorageT = timeMap[transaction.timeTrigger];

        //loops through time transactions to stamp sent one
        for(uint i = 0; i < timeTransactions.length; i++) {
            if(timeTransactions[i].id == transaction.id){
                transaction = timeTransactions[i];
                transaction.sent = true;
                timeStorageT[i] = transaction;
                break;
            }
        }

        //puts back in map
        timeMap[transaction.timeTrigger] = timeStorageT;
       
        //sends at the end to avoid re-entry attack
        (bool success, ) = transaction.receiver.call{value:transaction.payload}("");
        require(success, "Transfer failed.");
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

         //creates transaction
        Transaction memory transaction = setTransaction(msg.sender, receiver, timeTrigger, payload);

        timeStorageArray.push() = transaction;

        emit TransactionAdd(msg.sender, receiver, timeTrigger, payload);
        emit Status("Pushed");

        //adds transaction to lookup
        transactionLookup.push() = transaction.id;

        //puts appended arrays back in maps
        timeMap[timeTrigger] = timeStorageArray;    
        
        //adds or updates account
        Account storage account = accountMap[msg.sender];

        //updates account
        account.balance = msg.value + account.balance;
        
        //updates timeTrigger Array
        bool exists = false;

        uint40[] memory accountTriggers = account.timeTriggers;

        for(uint i; i < accountTriggers.length; i++){
            if(accountTriggers[i] == timeTrigger) {
                exists = true;
            }
        }

        if(exists == false) {
             account.timeTriggers.push() = timeTrigger;
        }

        //new account
        if(accountMap[msg.sender].exists == false) {
            account.accountAddress = msg.sender;
            //adds to lookup table
            accountLookup.push() = account.accountAddress;
            account.exists = true;
        }

        //adds account to account map
        accountMap[msg.sender] = account;
    }

    //REQUIRE transactions all be scheduled for the same time
    function addBatchTransactions(Batch[] memory batch) payable external {

        //TODO: could change to accept a single transaction
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

        //creates transaction array
        for(uint16 i = 0; i < batch.length; i++) {

            //creates internal transaction struct
            Transaction memory transaction = setTransaction(msg.sender, batch[i].receiver, timeTrigger, batch[i].payload);

            transactionStorageArray.push() = transaction;
             //adds transaction to lookup
            transactionLookup.push() = transaction.id;
        }

        timeMap[timeTrigger] = transactionStorageArray; 

        //updates account
        Account storage account = accountMap[msg.sender];

        account.balance = msg.value + account.balance;

        //updates timeTrigger Array
        //checks if timetrigger already exists in account
        bool exists = false;

        uint40[] memory accountTriggers = account.timeTriggers;

        for(uint i; i < accountTriggers.length; i++){
            if(accountTriggers[i] == timeTrigger) {
                exists = true;
            }
        }

        if(exists == false) {
             account.timeTriggers.push() = timeTrigger;
        }

        if(accountMap[msg.sender].exists == false) {
            account.accountAddress = msg.sender;
             //adds to lookup table
            accountLookup.push() = account.accountAddress;
            account.exists = true;
        }

        //adds account to account map
        accountMap[msg.sender] = account;

    }


    //checks list of blocks between now and when it was last checked (ONLY CAN BE CALLED BY ADMIN CURRENTLY)
    function checkTime() external isAdmin {

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