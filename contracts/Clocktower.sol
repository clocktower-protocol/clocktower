// SPDX-License-Identifier: UNLICENSED
//Copyright Hugo Marx 2022
//Written by Hugo Marx
pragma solidity ^0.8.9;

import "hardhat/console.sol";

abstract contract ERC20Permit{
  function transferFrom(address from, address to, uint value) public virtual returns (bool);
  function balanceOf(address tokenOwner) public virtual returns (uint);
  function approve(address spender, uint tokens) public virtual returns (bool);
  function permit(address owner, address spender, uint value, uint deadline, uint8 v, bytes32 r, bytes32 s) public virtual;
  function allowance(address owner, address spender) public virtual returns (uint);
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
        address token;
        uint40 timeTrigger;
        bool sent;
        bool cancelled;
        bool failed;
        //amount of ether or token sent in wei
        uint payload;
    }

    //acount struct
    struct Account {
        address accountAddress;
        //string description;
        bool exists;
        //indexs of timeTriggers and tokens stored per account. 
        //Timetrigger to lookup transactions. Token index to lookup balances
        uint40[] timeTriggers;
        address[] tokens;
    }

    //batch struct
    struct Batch {
        address payable receiver;
        uint40 unixTime;
        uint payload;
        address token;
        //Permit permit;
    }

    //batch variables
    struct BatchVariables {
        uint ethPayloads;
        uint uniqueTokenCount;
        uint uniqueTriggerCount;
        uint40[] accountTriggers;
        
    }

    //Permit struct
    struct Permit {
        address owner;
        address spender;
        uint value;
        uint deadline;
        uint8 v;
        bytes32 r;
        bytes32 s;
    }

    //Account Balance struct
    struct Balance {
        address token;
        uint availableBalance;
        uint scheduledBalance;
    }

    //Account map
    mapping(address => Account) private accountMap;
     //creates lookup table for mapping
    address[] private accountLookup;

    //Map of transactions based on hour to be sent
    mapping(uint40 => Transaction[]) private timeMap;
    //creates lookup table for transactions
    bytes32[] private transactionLookup;

    //per account address per token balance for scheduled transactions
    //mapping(address => mapping(address => uint)) scheduledBalances;

    //TODO: might be a more gas efficient way to do this
    //mapping for token totals
    mapping(address => mapping(address => uint)) tokenTotals;
    
    //&&
    //failed transaction array
    Transaction[] failedTransactions;

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
        require(msg.sender == admin, "Must have admin privileges");
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

    //ACCOUNT FUNCTIONS------------------------------------
/*
    //returns an array of structs of token types with balances
    function getAccountBalances() external view returns(Balance[] memory){

        address[] memory tokens = new address[](accountMap[msg.sender].tokens.length);

        tokens = accountMap[msg.sender].tokens;

        Balance[] memory balances = new Balance[](tokens.length);

        for(uint i; i < accountMap[msg.sender].tokens.length; i++) {

            
            Balance memory balance; 

            balance.token = tokens[i];
            balance.availableBalance = availableBalances[msg.sender][tokens[i]];
            balance.scheduledBalance = scheduledBalances[msg.sender][tokens[i]];

            balances[i] = balance;
        }

        return balances;
    }

    function deposit(address token, Permit calldata permit) external payable {
         
        //if ERC20 
        if(token != address(0)){
        //check if token is on approved list
            require(erc20IsApproved(token)," Token not approved for this contract");
        }

        //adds or updates account
        Account storage account = accountMap[msg.sender];

        //new account
        if(accountMap[msg.sender].exists == false) {
            account.accountAddress = msg.sender;
            //adds to lookup table
            accountLookup.push() = account.accountAddress;
            account.exists = true;
            account.tokens.push() = token;
        } else {

            //gets lookup arrays from account struct
            address[] memory tokens = account.tokens;

            //if account hasn't done a transaction with this token yet it adds it to the list
            if(!isInAddressArray(token, tokens)) {
                account.tokens.push() = token;
            }
        }

        //adds account to account map
        accountMap[msg.sender] = account;

        //updates token balance (and ETH at 0x0)
        availableBalances[msg.sender][token] += permit.value;

        if(token != address(0)) {
            //uses permit to approve transfer
            ERC20Permit(token).permit(permit.owner, permit.spender, permit.value, permit.deadline, permit.v, permit.r, permit.s);
            //transfers token to contract (done at end to avoid re-entrancy attack)
            require(ERC20Permit(token).transferFrom(msg.sender, address(this), permit.value), "Problem transferring token");
        }
    } 

    function withdraw(address token, uint amount) external payable {

        require(availableBalances[msg.sender][token] >= amount, "Not enough available balance to withdraw");

        availableBalances[msg.sender][token] -= amount;

         //checks different things for ether and for erc20 
        if(token == address(0)){
            //checks contract has enough ETH
            require(getBalance() > amount);
            //checks transaction goes through
            require(payable(msg.sender).send(amount));
        } else {
            //checks account has enough balance to send
            require(ERC20Permit(token).balanceOf(address(this)) >= amount);

            //checks transaction goes through
            //transfers Token
            require(ERC20Permit(token).approve(address(this), amount) && ERC20Permit(token).transferFrom(address(this), msg.sender, amount));
        }
    }
*/
    //-----------------------------------------------------

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

    function getFee() external view returns (uint) {
        return fee;
    }

    function getBalance() private view returns (uint) {
        return address(this).balance;
    }

    /*
    function getTokenBalance(address account, address token) private view returns (uint) {
        return scheduledBalances[account][token];
    }
    */
    //////////////////////

    //gets time TESTING FUNCTION
    function getTime() external view returns (uint) {
        return block.timestamp;
    }

    //checks if value is in array
    function isInTimeArray(uint40 value, uint40[] memory array) private pure returns (bool) {
    
        for(uint i; i < array.length; i++){
            if(array[i] == value) {
                    return true;
            }
        }
        return false; 
    }

    //checks if value is in array
    function isInAddressArray(address value, address[] memory array) private pure returns (bool result) {
        result = false;
        for(uint i; i < array.length; i++){
            if(array[i] == value) {
                    return true;
            }
        }
        return false;
    }

     //converts time to hours after merge
    function hoursSinceMerge(uint40 unixTime) private pure returns(uint40 hourCount){

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
    function setTransaction(address sender, address payable receiver, address token, uint40 timeTrigger, uint payload) private view returns(Transaction memory _transaction){
        
            //creates id hash
            bytes32 id = keccak256(abi.encodePacked(sender, timeTrigger, block.timestamp));
            
            _transaction = Transaction(id, sender, receiver, token,timeTrigger, false, false, false, payload);

            return _transaction;
    }

    //------------------------------------------------------------
    function addAccountTransaction(uint40 timeTrigger, address token) private {
        
        //adds or updates account
        Account storage account = accountMap[msg.sender];

        //new account
        if(accountMap[msg.sender].exists == false) {
            account.accountAddress = msg.sender;
            //adds to lookup table
            accountLookup.push() = account.accountAddress;
            account.exists = true;
            account.timeTriggers.push() = timeTrigger;
            account.tokens.push() = token;
        } else {

            //gets lookup arrays from account struct
            uint40[] memory accountTriggers = account.timeTriggers;
            address[] memory tokens = account.tokens;

            //if doesn't already exist adds time trigger to account list
            if(!isInTimeArray(timeTrigger, accountTriggers)) {
                account.timeTriggers.push() = timeTrigger;
            }

            //if account hasn't done a transaction with this token yet it adds it to the list
            if(!isInAddressArray(token, tokens)) {
                account.tokens.push() = token;
            }
        }

        //adds account to account map
        accountMap[msg.sender] = account;
    }

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

        //decreases balance
        //updates token balance (and ETH at 0x0)
        //scheduledBalances[msg.sender][transaction.token] -= transaction.payload;
        
        //checks different things for ether and for erc20 
        if(transaction.token == address(0)){
            //checks contract has enough ETH
            require(getBalance() > transaction.payload);
            //checks transaction goes through
            require(payable(transaction.sender).send(transaction.payload));
        } 
        /*
        else {
            //checks account has enough balance to send
            require(ERC20Permit(transaction.token).balanceOf(address(this)) >= transaction.payload);
            //checks transaction goes through
            //transfers Token
            require(ERC20Permit(transaction.token).approve(address(this), transaction.payload) && ERC20Permit(transaction.token).transferFrom(address(this), transaction.receiver, transaction.payload));
        }
        */

        //timeMap[timeTrigger] = timeStorageT;

    }

    //sends transaction
    function sendTransaction(Transaction memory transaction) stopInEmergency private {

        //TODO: could change from send bool to transaction confirm hash

        bool hasFailed = false;

        //TODO: eventually get rid of balance
        //checks contract has enough ETH and sender has enough balance
        //require(getTokenBalance(transaction.sender, transaction.token) >= transaction.payload);

        //makes sure contract has enough ETH or tokens to pay for transaction
        if(transaction.token == address(0)) {
            require(getBalance() > transaction.payload);
        } else {

            //makes sure sender has enough tokens allocated
            //require(ERC20Permit(transaction.token).balanceOf(address(this)) >= transaction.payload);
            
            //&&
            //if account doesn't have enough allowance or balance mark as failed
            if(ERC20Permit(transaction.token).allowance(transaction.sender, address(this)) < transaction.payload || ERC20Permit(transaction.token).balanceOf(transaction.sender) < transaction.payload) {
                hasFailed = true;
            }
        }

        Transaction[] memory timeTransactions = timeMap[transaction.timeTrigger];
        Transaction[] storage timeStorageT = timeMap[transaction.timeTrigger];

        //loops through time transactions to stamp sent one
        for(uint i = 0; i < timeTransactions.length; i++) {
            if(timeTransactions[i].id == transaction.id){
                transaction = timeTransactions[i];
                if(hasFailed) {
                    transaction.failed = true;
                } else {
                    transaction.sent = true;
                }
                timeStorageT[i] = transaction;
                break;
            }
        }

        //puts back in map
        timeMap[transaction.timeTrigger] = timeStorageT;

        //decreases balances
        //scheduledBalances[transaction.sender][transaction.token] -= transaction.payload;
       
        //sends at the end to avoid re-entry attack
        if(transaction.token == address(0)){
            //transfers ETH (Note: this doesn't need to be composible so send() is more secure than call() to avoid re-entry)
            //(bool success, ) = transaction.receiver.call{value:transaction.payload}("");
            bool success = transaction.receiver.send(transaction.payload);
            require(success, "Transfer failed.");
            emit TransactionSent(true);
        } else {
            
            //&&
            if(!hasFailed) {
                //transfers Token
                require(ERC20Permit(transaction.token).transferFrom(transaction.sender, transaction.receiver, transaction.payload));
            }
        }
       
    }

    //adds to list of transactions 
    function addTransaction(address payable receiver, uint40 unixTime, uint payload, address token, Permit calldata permit) stopInEmergency payable external {

        //require transactions to be in the future and to be on the hour
        require(unixTime > block.timestamp, "Time data must be in the future");

        require(unixTime % 3600 == 0, "Time must be on the hour");
        
        if(token == address(0)) {
            //require sent ETH to be higher than payload * fee
            require(payload * fee / 100 <= msg.value, "Not enough ETH sent with transaction");
        } else {
            //check if token is on approved list
            require(erc20IsApproved(token)," Token not approved for this contract");

            //requires payload to be the same as permit value
            require(payload <= permit.value, "Payload must be the same as value permitted");
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

        //creates or updates account
        addAccountTransaction(timeTrigger, token); 

        //updates token balance (and ETH at 0x0)
        //scheduledBalances[msg.sender][token] += payload;

        if(token != address(0)) {
            //uses permit to approve transfer
            ERC20Permit(token).permit(permit.owner, permit.spender, permit.value, permit.deadline, permit.v, permit.r, permit.s);

            //&&  
            //transfers token to contract (done at end to avoid re-entrancy attack)
           // require(ERC20Permit(token).transferFrom(msg.sender, address(this), payload), "Problem transferring token");
        }
    }

    //REQUIRE maximum 100 transactions (based on gas limit per block)
    //REQUIRE approval for token totals to be done in advance of calling this function
    function addBatchTransactions(Batch[] memory batch) stopInEmergency payable external {

        //Batch needs more than one transaction (single batch transaction uses more gas than addTransaction)
        require(((batch.length > 1) && (batch.length < 100)), "Batch must have more than one transaction and less than 100");

        //have to put top level function variables in a struct to avoid variable per function limit
        BatchVariables memory variables;


        //variables.ethPayloads;

        Account storage account = accountMap[msg.sender];
        variables.accountTriggers = account.timeTriggers;

        //creates arrays for a list of tokens in batch sized to overall approved contract addresses
        address[] memory batchTokenList = new address[](approvedERC20.length);

        //array for unique time triggers in batch (max array size based on existing unique time triggers plus max batch size)
        uint40[] memory batchTriggerList = new uint40[](account.timeTriggers.length + 100);

       // variables.uniqueTokenCount;
       // variables.uniqueTriggerCount;
       uint i;

        //validates data in each transaction and creates lists of unique tokens and timeTriggers
        for(i = 0; i < batch.length; i++) {

            //require transactions to be in the future and to be on the hour
            require(batch[i].unixTime > block.timestamp, "Time data must be in the future");

            require(batch[i].unixTime % 3600 == 0, "Time must be on the hour");

            
            //if time trigger is unique we put it in the list
            uint40 timeTrigger2 = hoursSinceMerge(batch[i].unixTime);

            //batchTriggerList
            if(!isInTimeArray(timeTrigger2, batchTriggerList)) {
                batchTriggerList[variables.uniqueTriggerCount] = timeTrigger2;
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
               
                if(!isInAddressArray(batch[i].token, batchTokenList)) {
                    batchTokenList[variables.uniqueTokenCount] = batch[i].token;
                    variables.uniqueTokenCount += 1;
                } 
            }

            //updates token balance (and ETH balance at 0x0)
            tokenTotals[msg.sender][batch[i].token] += batch[i].payload;
        }

        
        //makes sure enough ETH was sent in payloads
        //require sent ETH to be higher than payload * fee
        
        require(variables.ethPayloads * fee / 100 <= msg.value, "Not enough ETH sent with transaction");

        //iterates through batch time triggers 
        for(i = 0; i < batchTriggerList.length; i++) {

            //stops when it hits empty part of array
            if(batchTriggerList[i] == 0) {
                break;
            }

            //updates time triggers in map

            //Looks up array for timeTrigger. If no array exists it populates it. If it already does it appends it.
            Transaction[] storage transactionStorageArray = timeMap[batchTriggerList[i]];

            //creates transaction array
            for(uint16 j = 0; j < batch.length; j++) {

                uint40 time = hoursSinceMerge(batch[j].unixTime);


                if(time == batchTriggerList[i]) {
                    //creates internal transaction struct
                    Transaction memory transaction = setTransaction(msg.sender, batch[j].receiver, batch[j].token, time , batch[j].payload);

                    transactionStorageArray.push() = transaction;
                
                    //adds transaction to lookup
                    transactionLookup.push() = transaction.id;
                }
            }

            timeMap[batchTriggerList[i]] = transactionStorageArray;

                
            if(!isInTimeArray(batchTriggerList[i], variables.accountTriggers)) {
                account.timeTriggers.push() = batchTriggerList[i];
            }
        }
        
        //updates account
        address[] memory accountTokens = account.tokens;
        
        //checks if token already exists or not and adds to account
        for(i = 0; i < batchTokenList.length; i++) {

            //checks that user has set allowance to contract high enough for each token
            if(batchTokenList[i] != address(0)) {
                //checks that allowances were set correctly
                require(ERC20Permit(batchTokenList[i]).allowance(msg.sender, address(this)) >= tokenTotals[msg.sender][batchTokenList[i]] && ERC20Permit(batchTokenList[i]).balanceOf(msg.sender) >= tokenTotals[msg.sender][batchTokenList[i]]);
            }
    
            if(!isInAddressArray(batchTokenList[i], accountTokens)) {
                account.tokens.push() = batchTokenList[i];
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
     
        /*
        //gets tokens for contract (does at end to avoid re-entry)
        for(uint k = 0; k < batch.length; k++) {

            //updates token balance (and ETH balance at 0x0)
            scheduledBalances[msg.sender][batch[k].token] += batch[k].payload;


            if(batch[k].token != address(0)) {

                //&&
                //uses permit to approve transfers
                //ERC20Permit(batch[k].token).permit(batch[k].permit.owner, batch[k].permit.spender, batch[k].permit.value, batch[k].permit.deadline, batch[k].permit.v, batch[k].permit.r, batch[k].permit.s);

                //transfers token to contract
               // require(ERC20Permit(batch[k].token).transferFrom(msg.sender, address(this), batch[k].payload), "Problem transferring token");
            }
        }
        */




    }


    //checks list of blocks between now and when it was last checked (ONLY CAN BE CALLED BY ADMIN CURRENTLY)
    function sendTime() external isAdmin {

        //gets current time slot based on hour
        uint40 _currentTimeSlot = hoursSinceMerge(uint40(block.timestamp));

        require(_currentTimeSlot > lastCheckedTimeSlot, "Time already checked for this time slot");

        for(uint40 i = lastCheckedTimeSlot; i <= _currentTimeSlot; i++) {

            //gets transaction array per time trigger
            Transaction[] memory _transactionArray = timeMap[i];
            
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

    //view function that checks if any transactions are in line to be sent
    function checkTime() external view isAdmin returns (bool) {
         //gets current time slot based on hour
        uint40 _currentTimeSlot = hoursSinceMerge(uint40(block.timestamp));

        require(_currentTimeSlot > lastCheckedTimeSlot, "Time already checked for this time slot");

        for(uint40 i = lastCheckedTimeSlot; i <= _currentTimeSlot; i++) {

            //gets transaction array per time trigger
            Transaction[] memory _transactionArray = timeMap[i];

            //if block has transactions add them to transaction list
            if(_transactionArray.length > 0) {
                return true;
            }
        }
        return false;
    }
}