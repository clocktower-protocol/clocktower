// SPDX-License-Identifier: UNLICENSED
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

    //global struct for Watchers
    struct Watcher {
        address watcherAddress;

    }

    //TODO: create senderaccount balance map


    //Initialize an array of transactions keyed to uint blocknumber.
    //This makes it very fast to look up transactions by time.
    //Map of arrays of transaction structs keyed to block number send time

    mapping(uint => Transaction[]) private timeBlocks;

    //blocks since merge
    uint32 blockMergeTime = 15537393;
    //seconds since merge
    uint40 unixMergeTime = 1663264750;

    //variable for last checked time block
    uint40 lastCheckedTimeSlot = (hoursSinceMerge(uint40(block.timestamp)) - 1);
    
    //Emits
    event TransactionAdd(address sender, address receiver, uint40 timeTrigger, uint payload);
    event Status(string output);
    event CheckStatus(string output2);
    event TransactionSent(bool sent);
    event HoursCalc(bool houseSent);

    //functions for receiving ether
    receive() external payable{}
    fallback() external payable{}

    function getBalance() internal view returns (uint){
        return address(this).balance;
    }
    //////////////////////
    
    //sets Transaction
    function setTransaction(address sender, address payable receiver, uint40 timeTrigger, uint16 arrayIndex, uint payload) pure  internal returns(Transaction memory _transaction){

            _transaction = Transaction(sender, receiver, timeTrigger, arrayIndex, false, payload);

            return _transaction;

    }

    //gets transaction array from block
    function getTransactionArray(uint40 timeTrigger) private view returns(Transaction[] storage transactionArray){

       return timeBlocks[timeTrigger];

    }

    
    //sets transaction array to transaction block map
    function setTransactionArray(Transaction[] storage transactionArray, uint40 timeTrigger) private {
        timeBlocks[timeTrigger] = transactionArray;

    }

    //converts time to hours after merge
    function hoursSinceMerge(uint40 unixTime) public  returns(uint40 hourCount){


        //TODO: need to do with safe math libraries. Leap years don't work. Could maybe fix?
        //uint40 unixTime = uint40(block.timestamp);
        //uint40 secondsSinceMerge = unixTime - unixMergeTime;

        //hourCount = secondsSinceMerge/3600;
        hourCount = (unixTime - unixMergeTime)/3600;


        emit HoursCalc(true);

        return hourCount;
    }


    //sends transaction
    function sendTransaction(Transaction memory transaction) private {

        //checks if contract has enough eth
        if(getBalance() > transaction.payload) {
                //TODO: add check if sender has enough in account


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
        }else {
            //TODO: add error throw
            emit TransactionSent(false);
        }
    }

    

    //adds to list of transactions 
    function addTransaction(address payable receiver, uint40 unixTime, uint payload) external {
        
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

        //puts appended array back in map

        setTransactionArray(_transactionArray, timeTrigger);      
    }
    

    //checks list of blocks between now and when it was last checked
    function checkTime() public {

        //gets current time slot based on hour
        uint40 _currentTimeSlot = hoursSinceMerge(uint40(block.timestamp));

        for(uint40 i = lastCheckedTimeSlot; i <= _currentTimeSlot; i++) {

            Transaction[] memory _transactionArray;

            emit CheckStatus("done");
            
            //gets transaction array per block
            _transactionArray = timeBlocks[i];

            
            //if block has transactions add them to transaction list
            if(_transactionArray.length > 0) {
                
                //iterates through transaction array
                for(uint16 h = 0; h <= (_transactionArray.length - 1); h++){

                    //sends transactions
                    sendTransaction(_transactionArray[h]);
                    
                }               
            }
        }

    }

    //gets block number based on timestamp
    function getBlockFromTime(uint _timestamp) internal {

    }
}