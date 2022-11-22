// SPDX-License-Identifier: UNLICENSED
//Written by Hugo Marx
pragma solidity ^0.8.9;

import "hardhat/console.sol";

contract Clocktower {

    constructor() payable {
    }

    //global struct for future transactions
    struct Transaction {
        address sender;
        address payable receiver;
        //timeTrigger and arrayIndex make a unique key per transaction. So you can look it up in the map
        uint40 timeTrigger;
        uint16 arrayIndex;
        bool sent;
        //amount of ether sent in wei
        uint payload;
    }

    //acount struct
    struct Account {
        address accountAddress;
        //string description;
        bool exists;
        //Transaction[] transactions;
        uint balance;
    }

    //global struct for Watchers
    struct Watcher {
        address watcherAddress;

    }

    //Account map
    mapping(address => Account) private accountMap;
    //Map of transactions based on account
    mapping(address => Transaction[]) private transactionsMap;

    //Initialize an array of transactions keyed to uint blocknumber.
    //This makes it very fast to look up transactions by time.
    //Map of arrays of transaction structs keyed to block number send time

    mapping(uint => Transaction[]) private timeMap;

    //blocks since merge
    uint32 blockMergeTime = 15537393;
    //seconds since merge
    uint40 unixMergeTime = 1663264750;

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

    //gets transactions from account
    function getAccountTransactions() external view returns (Transaction[] memory transactions){
        //account info can only be accessed by itself
        //require(msg.sender == account, "Wrong account access attempted");
        transactions = transactionsMap[msg.sender];

        return transactions;

    }

    function getAccount() external view returns (Account memory returnAccount){
        
        //account info can only be accessed by itself
        //require(msg.sender == account, "Wrong account access attempted");

        returnAccount = accountMap[msg.sender];
        return returnAccount;

    }

    //set account
    function setAccount(bool exists, uint balance) internal  view returns (Account memory account){
        account  = Account(msg.sender, exists, balance);

        return account;
    }

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
    function setTransaction(address sender, address payable receiver, uint40 timeTrigger, uint16 arrayIndex, uint payload) internal pure returns(Transaction memory _transaction){
 
            _transaction = Transaction(sender, receiver, timeTrigger, arrayIndex, false, payload);

            return _transaction;

    }

    //gets transaction array from block
    function getTransactionArray(uint40 timeTrigger) private view returns(Transaction[] storage transactionArray){

       return timeMap[timeTrigger];

    }

    
    //sets transaction array to transaction block map
    function setTransactionArray(Transaction[] storage transactionArray, uint40 timeTrigger) private {
        timeMap[timeTrigger] = transactionArray;

    }

    //sends transaction
    function sendTransaction(Transaction memory transaction) private {

        //checks contract has enough ETH
        require(getBalance() > transaction.payload);
        //checks transaction goes through
        require(transaction.receiver.send(transaction.payload));

         //updates the transaction to reflect sent status
        transaction.sent = true; 
        Transaction[] memory _transactionArray = timeMap[transaction.timeTrigger];
        _transactionArray[transaction.arrayIndex] = transaction;

        emit TransactionSent(true);

        /*
        if(transaction.receiver.send(transaction.payload)) {
             emit TransactionSent(true);
                        
                        
            //updates the transaction to reflect sent status
            transaction.sent = true; 
            Transaction[] memory _transactionArray = timeBlocks[transaction.timeTrigger];
            _transactionArray[transaction.arrayIndex] = transaction;
                        

        } else {
            //TODO: add error throw
            emit TransactionSent(false);
        }
        */
       
    }

    

    //adds to list of transactions 
    function addTransaction(address payable receiver, uint40 unixTime, uint payload) payable external {

        //require transactions to be in the future
        require(unixTime > block.timestamp);
        //require sent ETH to be higher than payload * fee
        require(payload >= (msg.value * fee), "Not enough ETH sent with transaction");
        
        //calculates hours since merge from passed unixTime
        uint40 timeTrigger = hoursSinceMerge(unixTime);

        address sender = msg.sender;
        Transaction[] storage _transactionArray;

        
        //Looks up array for blockTrigger. If no array exists it populates it. If it already does it appends it.
        _transactionArray = getTransactionArray(timeTrigger);   
        
        //gets length of array to populate arrayIndex in transaction
        uint16 arrayLength = uint16(_transactionArray.length);

         //creates transaction
        Transaction memory transaction = setTransaction(sender, receiver, timeTrigger, arrayLength, payload);

        _transactionArray.push() = transaction;

        emit TransactionAdd(sender, receiver, timeTrigger, payload);
        emit Status("Pushed");

        //puts appended array back in time map

        setTransactionArray(_transactionArray, timeTrigger);      

        
        //gets transactions from existing or zero for new and adds new transaction

        if(accountMap[msg.sender].exists == true) {
            Account memory account = accountMap[msg.sender];

            //updates account
            account.balance = msg.value + account.balance;

            Transaction[] storage accountTransactions = transactionsMap[msg.sender];
            
            //updates transaction array
            accountTransactions.push(transaction);

            transactionsMap[msg.sender] = accountTransactions;

            //adds new account to account map
            accountMap[msg.sender] = account;
        } else {
            
            Account memory account = accountMap[msg.sender];

            //updates account
            account.balance = msg.value + account.balance;
            account.accountAddress = msg.sender;
            account.exists = true;

            Transaction[] storage accountTransactions = transactionsMap[msg.sender];
            
            //updates transaction array
            accountTransactions.push(transaction);

            transactionsMap[msg.sender] = accountTransactions;

            //adds new account to account map
            accountMap[msg.sender] = account;
        }
           
    }
    

    //checks list of blocks between now and when it was last checked
    function checkTime() public {

        //gets current time slot based on hour
        uint40 _currentTimeSlot = hoursSinceMerge(uint40(block.timestamp));

        require(_currentTimeSlot > lastCheckedTimeSlot, "Time already checked for this time slot");

        for(uint i = lastCheckedTimeSlot; i <= _currentTimeSlot; i++) {

            Transaction[] memory _transactionArray;

            emit CheckStatus("done");
            
            //gets transaction array per block
            _transactionArray = timeMap[i];

            
            //if block has transactions add them to transaction list
            if(_transactionArray.length > 0) {
                
                //iterates through transaction array
                for(uint h = 0; h <= (_transactionArray.length - 1); h++){

                    //sends transactions
                    sendTransaction(_transactionArray[h]);
                    
                }               
            }
        }

        //updates lastCheckedTimeSlot
        lastCheckedTimeSlot = _currentTimeSlot;

    }
}