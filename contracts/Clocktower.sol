// SPDX-License-Identifier: UNLICENSED
//Written by Hugo Marx
pragma solidity ^0.8.9;

import "hardhat/console.sol";

abstract contract ERC20{
  function transferFrom(address from, address to, uint value) public virtual returns (bool);
  function balanceOf(address tokenOwner) public virtual returns (uint);
  function approve(address spender, uint tokens) public virtual returns (bool);
} 

contract Clocktower {

    constructor() payable {
    }

    //DATA-------------------------------------------------------
    //global struct for future transactions
    struct Transaction {
        bytes32 id;
        address sender;
        address payable receiver;
        //&&
        address token;
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
        uint40[] timeTriggers;
        address[] tokens;
    }

    //batch struct
    struct Batch {
        address payable receiver;
        uint40 unixTime;
        uint payload;
        address token;
    }

    //batch variables
    struct BatchVariables {
        uint ethPayloads;
        uint40[] accountTriggers;
        //creates arrays for a list of tokens in batch sized to overall approved contract addresses
        address[] batchTokenList;
        //array for unique time triggers in batch (max array size based on existing unique time triggers plus max batch size)
        uint40[] batchTriggerList;
        uint40 unixTime;
        uint uniqueTokenCount;
        uint uniqueTriggerCount;
    }

    //Account map
    mapping(address => Account) private accountMap;
     //creates lookup table for mapping
    address[] private accountLookup;

    //Map of transactions based on hour to be sent
    mapping(uint40 => Transaction[]) private timeMap;
    //creates lookup table for transactions
    bytes32[] private transactionLookup;

    //per account address per token balance
    mapping(address => mapping(address => uint)) tokenBalances;

    //admin addresses
    address admin = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;

    //approved contract addresses
    address[] approvedERC20;

    //circuit breaker
    bool stopped = false;

    //seconds since merge
    uint40 constant unixMergeTime = 1663264800;

    //TODO: set fee
    //100 = 100%
    uint fee = 100;

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

    
    //allows admin to add to approved contract addresses
    function addERC20Contract(address erc20Contract) isAdmin external {
        require(erc20Contract != address(0));
        require(!erc20IsApproved(erc20Contract), "ERC20 token already added");
        
        approvedERC20.push() = erc20Contract;
    }

    //allows admin to remove an erc20 contract from the approved list
    function removeERC20Contract(address erc20Contract) isAdmin external {
        require(erc20Contract != address(0));
        require(erc20IsApproved(erc20Contract), "ERC20 token not added yet");

        address[] memory memoryArray = approvedERC20;
        
        uint index = 0;

        //finds index of address
        for(uint i; i < memoryArray.length; i++) {
            if(memoryArray[i] == erc20Contract) {
                index = i;
                break;
            }
        }

        //removes from array and reorders
        for(uint i = index; i < approvedERC20.length-1; i++){
            approvedERC20[i] = approvedERC20[i+1];      
        }
        approvedERC20.pop();
    }

    //change fee
    function changeFee(uint _fee) isAdmin external {
        fee = _fee;
    }
    
    //returns array containing all transactions
    function allTransactions() isAdmin external view returns (Transaction[] memory){

        Transaction[] memory totalTransactions = new Transaction[](transactionLookup.length);

        uint count = 0;

        //for each account
        for(uint i = 0; i < accountLookup.length; i++) {

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
                if(subsetTransactions[j].sender == account){
                    totalTransactions[count] = subsetTransactions[j];
                    count++;
                }
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
   
    function erc20IsApproved(address erc20Contract) private view returns(bool result) {
        address[] memory approved = approvedERC20;

        result = false;

        for(uint i; i < approved.length; i++) {
            if(erc20Contract == approved[i]) {
                result = true;
            }
        }
    }

    function getBalance() internal view returns (uint){
        return address(this).balance;
    }

    function getTokenBalance(address account, address token) internal view returns (uint) {
        return tokenBalances[account][token];
    }
    //////////////////////

    //gets time TESTING FUNCTION
    function getTime() external view returns (uint) {
        return block.timestamp;
    }

     //converts time to hours after merge
    function hoursSinceMerge(uint40 unixTime) public pure returns(uint40 hourCount){

        hourCount = (unixTime - unixMergeTime)/3600;

        return hourCount;
    }

    //converts hours since merge to unix epoch utc time
    function unixFromHours(uint40 timeTrigger) private pure returns(uint40 unixTime) {
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
                //&& filters by account
                if(subsetTransactions[j].sender == msg.sender){
                    totalTransactions[count] = subsetTransactions[j];
                    count++;
                }
            }
        }

        
         //iterates through array and changes dates to unixEpochTime
        for(uint i = 0; i < totalTransactions.length; i++) {
                totalTransactions[i].timeTrigger = unixFromHours(totalTransactions[i].timeTrigger);
        }
    
        //return transactions;
        return totalTransactions;
    }
    
    //sets Transaction
    function setTransaction(address sender, address payable receiver, address token, uint40 timeTrigger, uint payload) internal view returns(Transaction memory _transaction){
        
            //creates id hash
            bytes32 id = keccak256(abi.encodePacked(sender, timeTrigger, block.timestamp));
            
            _transaction = Transaction(id, sender, receiver, token,timeTrigger, false, false, payload);

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
            
            if(timeTransactions[i].id == id){
                transaction = timeTransactions[i];
                transaction.cancelled = true;
                timeStorageT[i] = transaction;
                break;
            }
        }

        timeMap[timeTrigger] = timeStorageT;
        
        //checks different things for ether and for erc20 
        if(transaction.token == address(0)){
            //checks contract has enough ETH
            require(getBalance() > transaction.payload);
            //checks transaction goes through
            require(payable(transaction.sender).send(transaction.payload));
        } else {
            require(ERC20(transaction.token).balanceOf(address(this)) >= transaction.payload);
        }

        //timeMap[timeTrigger] = timeStorageT;

    }

    //sends transaction
    function sendTransaction(Transaction memory transaction) stopInEmergency private {

        //TODO: could change from send bool to transaction confirm hash

        //checks contract has enough ETH and sender has enough balance
        require(getTokenBalance(transaction.sender, transaction.token) >= transaction.payload);

        //makes sure contract has enough ETH or tokens to pay for transaction
        if(transaction.token == address(0)) {
            require(getBalance() > transaction.payload);
        } else {
            require(ERC20(transaction.token).balanceOf(address(this)) >= transaction.payload);
        }

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
        if(transaction.token == address(0)){
            //transfers ETH (Note: this doesn't need to be composible so send() is more secure than call() to avoid re-entry)
            //(bool success, ) = transaction.receiver.call{value:transaction.payload}("");
            bool success = transaction.receiver.send(transaction.payload);
            require(success, "Transfer failed.");
            emit TransactionSent(true);
        } else {
            //transfers Token
            require(ERC20(transaction.token).approve(address(this), transaction.payload) && ERC20(transaction.token).transferFrom(address(this), transaction.receiver, transaction.payload));
        }
       
    }

    //adds to list of transactions 
    function addTransaction(address payable receiver, uint40 unixTime, uint payload, address token) payable external {

        //require transactions to be in the future and to be on the hour
        require(unixTime > block.timestamp, "Time data must be in the future");

        require(unixTime % 3600 == 0, "Time must be on the hour");
        
        if(token == address(0)) {
            //require sent ETH to be higher than payload * fee
            require(payload * fee / 100 <= msg.value, "Not enough ETH sent with transaction");
        } else {
            //check if token is on approved list
            require(erc20IsApproved(token)," Token not approved for this contract");

            //transfers token to contract
           // require(ERC20(token).transferFrom(msg.sender, address(this), payload), "Problem transferring token");
        }
        
        //calculates hours since merge from passed unixTime
        uint40 timeTrigger = hoursSinceMerge(unixTime);

        //Looks up array for timeTrigger. If no array exists it populates it. If it already does it appends it.
        Transaction[] storage timeStorageArray = timeMap[timeTrigger]; 

         //creates transaction
        Transaction memory transaction = setTransaction(msg.sender, receiver, token, timeTrigger, payload);

        timeStorageArray.push() = transaction;

       // console.log(transaction.timeTrigger);

        emit TransactionAdd(msg.sender, receiver, timeTrigger, payload);
        emit Status("Pushed");

        //adds transaction to lookup
        transactionLookup.push() = transaction.id;

        //puts appended arrays back in maps
        timeMap[timeTrigger] = timeStorageArray;    
        
        //adds or updates account
        Account storage account = accountMap[msg.sender];
        
        //updates timeTrigger Array and token array
        bool triggerExists = false;
        bool tokenExists = false;

        uint40[] memory accountTriggers = account.timeTriggers;
        address[] memory tokens = account.tokens;

        //does the account already have transactions during this time period?
        for(uint i; i < accountTriggers.length; i++){
            if(accountTriggers[i] == timeTrigger) {
                triggerExists = true;
                break;
            }
        }

        //if doesn't already exist adds time trigger to account list
        if(triggerExists == false) {
             account.timeTriggers.push() = timeTrigger;
        }

        //has this account done a transaction with this token before?
        for(uint i; i < tokens.length; i++){
            if(tokens[i] == token) {
                tokenExists = true;
                break;
            }
        }

        //if account hasn't done a transaction with this token yet it adds it to the list
        if(tokenExists == false) {
            account.tokens.push() = token;
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

        //updates token balance (and ETH at 0x0)
        tokenBalances[msg.sender][token] += payload;

        if(token != address(0)) {
            //transfers token to contract (done at end to avoid re-entrancy attack)
            require(ERC20(token).transferFrom(msg.sender, address(this), payload), "Problem transferring token");
        }
    }

    //REQUIRE maximum 100 transactions (based on gas limit per block)
    function addBatchTransactions(Batch[] memory batch) payable external {

        //Batch needs more than one transaction (single batch transaction uses more gas than addTransaction)
        require(((batch.length > 1) && (batch.length < 100)), "Batch must have more than one transaction and less than 100");

        //have to put top level function variables in a struct to avoid variable per function limit
        BatchVariables memory variables;

        variables.ethPayloads  = 0;

        Account storage account = accountMap[msg.sender];
        variables.accountTriggers = account.timeTriggers;

        //creates arrays for a list of tokens in batch sized to overall approved contract addresses
        variables.batchTokenList = new address[](approvedERC20.length);
        //array for unique time triggers in batch (max array size based on existing unique time triggers plus max batch size)
        variables.batchTriggerList = new uint40[](account.timeTriggers.length + 100);

        variables.unixTime = 0;

        variables.uniqueTokenCount = 0;
        variables.uniqueTriggerCount = 0;

        //validates data in each transaction and creates lists of unique tokens and timeTriggers
        for(uint i = 0; i < batch.length; i++) {

            //require transactions to be in the future and to be on the hour
            require(batch[i].unixTime > block.timestamp, "Time data must be in the future");

            require(batch[i].unixTime % 3600 == 0, "Time must be on the hour");

            //if time trigger is unique we put it in the list
            bool inList2 = false;
            uint40 timeTrigger2 = hoursSinceMerge(batch[i].unixTime);
            //checks if already is in the list if not adds it
            for(uint j = 0; j < variables.batchTriggerList.length; j++){ 
                if(timeTrigger2 == variables.batchTriggerList[j]) {
                    inList2 = true;
                    break;
                } 
            }

            if(!inList2) {
                variables.batchTriggerList[variables.uniqueTriggerCount] = timeTrigger2;
                variables.uniqueTriggerCount += 1;
            } 
            
            //ethereum transaction
            if(batch[i].token == address(0)) {
                 //sums up all ETH payloads
                variables.ethPayloads += batch[i].payload;
            } else {

            //Token transaction 
                //check if token is on approved list
                require(erc20IsApproved(batch[i].token)," Token not approved for this contract");
               
                //if token is unique puts it in list
                bool inList = false;
            
                //checks if already is in the list if not adds it
                for(uint j = 0; j < variables.batchTokenList.length; j++){ 
                    if(batch[i].token == variables.batchTokenList[j]) {
                        inList = true;
                        break;
                    } 
                }

                if(!inList) {
                    variables.batchTokenList[variables.uniqueTokenCount] = batch[i].token;
                    variables.uniqueTokenCount += 1;
                } 
                
                //transfers token to contract
                //require(ERC20(batch[i].token).transferFrom(msg.sender, address(this), batch[i].payload), "Problem transferring token");
            }
        }

        //makes sure enough ETH was sent in payloads
        //require sent ETH to be higher than payload * fee
        
        require(variables.ethPayloads * fee / 100 <= msg.value, "Not enough ETH sent with transaction");

        //since unixTime should be the same for all transactions. You only calulate the time trigger once. 
        for(uint i; i < variables.batchTriggerList.length; i++) {

            //stops when it hits empty part of array
            if(variables.batchTriggerList[i] == 0) {
                break;
            } else {

                //updates time triggers in map

                //Looks up array for timeTrigger. If no array exists it populates it. If it already does it appends it.
                Transaction[] storage transactionStorageArray = timeMap[variables.batchTriggerList[i]];

                //creates transaction array
                for(uint16 j = 0; j < batch.length; j++) {

                    uint40 time = hoursSinceMerge(batch[j].unixTime);

                    if(time == variables.batchTriggerList[i]) {
                        //creates internal transaction struct
                        Transaction memory transaction = setTransaction(msg.sender, batch[j].receiver, batch[j].token, time , batch[j].payload);

                        transactionStorageArray.push() = transaction;
                        //adds transaction to lookup
                        transactionLookup.push() = transaction.id;
                    }
                }

                timeMap[variables.batchTriggerList[i]] = transactionStorageArray; 

                
                //updates timeTriggers in account
                bool triggerExists = false;

                //adds unique new timeTriggers to account list
                for(uint j = 0; j < variables.accountTriggers.length; j++){
                    if(variables.accountTriggers[j] == variables.batchTriggerList[i]) {
                        triggerExists = true;
                        break;
                    }
                 }

                if(!triggerExists) {
                    account.timeTriggers.push() = variables.batchTriggerList[i];
                }
                
            }
        }

        //updates account
        address[] memory accountTokens = account.tokens;
        
        //checks if token already exists or not and adds to account
        for(uint i; i < variables.batchTokenList.length; i++) {
            bool tokenExists = false;
            for(uint j; j < accountTokens.length; j++) {
                if(accountTokens[j] == variables.batchTokenList[i]) {
                    tokenExists = true;
                    break;
                } 
            }
            if(!tokenExists) {
                account.tokens.push() = variables.batchTokenList[i];
            }
       }
        
        if(accountMap[msg.sender].exists == false) {
            account.accountAddress = msg.sender;
             //adds to lookup table
            accountLookup.push() = account.accountAddress;
            account.exists = true;
        }

        //adds account to account map
        accountMap[msg.sender] = account;
     
        //gets tokens for contract (does at end to avoid re-entry)
        for(uint k = 0; k < batch.length; k++) {

            //updates token balance (and ETH balance at 0x0)
            tokenBalances[msg.sender][batch[k].token] += batch[k].payload;

            if(batch[k].token != address(0)) {

                //transfers token to contract
                require(ERC20(batch[k].token).transferFrom(msg.sender, address(this), batch[k].payload), "Problem transferring token");
            }
        }
    }


    //checks list of blocks between now and when it was last checked (ONLY CAN BE CALLED BY ADMIN CURRENTLY)
    function checkTime() external isAdmin {

        //gets current time slot based on hour
        uint40 _currentTimeSlot = hoursSinceMerge(uint40(block.timestamp));

        require(_currentTimeSlot > lastCheckedTimeSlot, "Time already checked for this time slot");


        for(uint40 i = lastCheckedTimeSlot; i <= _currentTimeSlot; i++) {

            //gets transaction array per time trigger
            Transaction[] memory _transactionArray = timeMap[i];

            emit CheckStatus("done");
            
            //if block has transactions add them to transaction list
            if(_transactionArray.length > 0) {
                //iterates through transaction array
                for(uint h = 0; h < (_transactionArray.length); h++){
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