// SPDX-License-Identifier: UNLICENSED
//Copyright Hugo Marx 2023
//Written by Hugo Marx
pragma solidity ^0.8.9;

import "hardhat/console.sol";
//import "./Timelibrary.sol";
import "./ClockTowerLibrary.sol";

interface ERC20Permit{
  function transferFrom(address from, address to, uint value) external returns (bool);
  function balanceOf(address tokenOwner) external returns (uint);
  function approve(address spender, uint tokens) external returns (bool);
  function permit(address owner, address spender, uint value, uint deadline, uint8 v, bytes32 r, bytes32 s) external;
  function allowance(address owner, address spender) external returns (uint);
} 


/*
abstract contract ERC20Permit{
  function transferFrom(address from, address to, uint value) public virtual returns (bool);
  function balanceOf(address tokenOwner) public virtual returns (uint);
  function approve(address spender, uint tokens) public virtual returns (bool);
  function permit(address owner, address spender, uint value, uint deadline, uint8 v, bytes32 r, bytes32 s) public virtual;
  function allowance(address owner, address spender) public virtual returns (uint);
} 
*/

contract Clocktower {

    constructor() payable {
    }

    //using BokkyPooBahsDateTimeLibrary for uint;
    using ClockTowerLibrary for uint;
    //using ClockTowerLibrary for address;

    /*
    //Require error codes
    0 = Must have admin privileges
    1 = ERC20 token already added
    2 = ERC20 token not added yet
    3 = No zero address call
    4 = Time must be in the future
    5 = Not enough ETH sent
    6 = Time must be on the hour
    7 = Subscription doesn't exist
    8 = Token address cannot be zero
    9 = Token not approved
    10 = Amount must be greater than zero
    11 = Not enough ETH in contract
    12 = Transfer failed
    13 = Requires token allowance to be increased
    14 = Time already checked
    15 = Token allowance must be unlimited for subscriptions

    */

    //DATA-------------------------------------------------------

    //admin addresses
    address admin = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;

    //100 = 100%
    uint fee = 100;
    //0.01 eth in wei
    uint fixedFee = 10000000000000000;

    //offset for time calc
    //int constant OFFSET19700101 = 2440588;

    //global enums
    enum Status {
        PENDING,
        SENT,
        FAILED,
        CANCELLED
    }

    enum SubType {
        ONETIME,
        MONTHLY,
        YEARLY
    }


    //global struct for future transactions
    struct Transaction {
        bytes32 id;
        address sender;
        address payable receiver;
        address token;
        uint40 timeTrigger;
        Status status;
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
        SubIndex[] subscriptions;
    }

     //Subscription struct
    struct Subscription {
        bytes32 id;
        uint amount;
        address owner;
        bool exists;
        bool cancelled;
        address token;
        SubType subType;
        uint40 dueDay;
        string description;
        //address[] subscribers;
    }


     //struct of Subscription indexes
    struct SubIndex {
        bytes32 id;
        uint40 dueDay;
        SubType subType;
    }

    //&&
    //struct of subscription payments
    struct SubLog {
        bytes32 subId;
        uint40 timestamp; 
        bool success;
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

    //Account map
    mapping(address => Account) private accountMap;
     //creates lookup table for mapping
    address[] private accountLookup;

    //Map of transactions based on hour to be sent
    mapping(uint40 => Transaction[]) private timeMap;
    
    //creates lookup table for transactions
    bytes32[] private transactionLookup;

    //Subscription maps monthly, quarterly, yearly
    //day of month 
    mapping(uint40 => Subscription[]) monthMap;
    //day of year
    mapping(uint40 => Subscription[]) yearMap;
    
    //Subscription master map
    mapping(uint => mapping(uint40 => Subscription[])) subscriptionMap;

    //map of subscribers
    mapping(bytes32 => address[]) subscribersMap;

    //&&
    //log of subscription payments
    mapping(address => SubLog) paymentLog;

    //per account address per token balance for scheduled transactions
    mapping(address => mapping(address => uint)) tokenClaims;

    //TODO: might be a more gas efficient way to do this
    //mapping for batch token totals
    mapping(address => uint) batchTokenTotals;

    //approved contract addresses
    address[] approvedERC20;

    //circuit breaker
    bool stopped = false;

    //variable for last checked by hour
    uint40 lastCheckedHour = (unixToHours(uint40(block.timestamp)) - 1);
    

    //---------------------------------------------------------------------------------
    
    //Emits
    //event CheckStatus(string output2);
    //event TransactionSent(bool sent);
    //event UnknownFunction(string output3);
    //event ReceiveETH(address user, uint amount);
    ///event AccountCreated(string output4);

    //functions for receiving ether
    receive() external payable{
        //emit ReceiveETH(msg.sender, msg.value);
    }
    fallback() external payable{
        //emit UnknownFunction("Unknown function");
    }

    //ADMIN METHODS*************************************

    function adminRequire() private view {
        require(msg.sender == admin, "0");
    }
    
    //checks if user is admin
    modifier isAdmin() {
        adminRequire();
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
        require(!erc20IsApproved(erc20Contract), "1");
        
        approvedERC20.push() = erc20Contract;
    }

    //allows admin to remove an erc20 contract from the approved list
    function removeERC20Contract(address erc20Contract) isAdmin external {
        require(erc20Contract != address(0));
        require(erc20IsApproved(erc20Contract), "2");

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

    //change fixed fee
    function changeFixedFee(uint _fixed_fee) isAdmin external {
        fixedFee = _fixed_fee;
    }
    
    //TODO: do these functions offchain

    /*
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
                totalTransactions[i].timeTrigger = hourstoUnix(totalTransactions[i].timeTrigger);
        }
    
        //return transactions;
        return totalTransactions;
    }
    
    */
    
    //**************************************************

    //UTILITY FUNCTIONS-----------------------------------
    function unixToDays(uint unix) public pure returns (uint16 yearDays, uint16 day) {
       
        uint _days = unix/86400;
       
        int __days = int(_days);

        int L = __days + 68569 + 2440588;
        int N = 4 * L / 146097;
        L = L - (146097 * N + 3) / 4;
        int _year = 4000 * (L + 1) / 1461001;
        L = L - 1461 * _year / 4 + 31;
        int _month = 80 * L / 2447;
        int _day = L - 2447 * _month / 80;
        L = _month / 11;
        _month = _month + 2 - 12 * L;
        _year = 100 * (N - 49) + _year + L;

        uint uintyear = uint(_year);
        uint month = uint(_month);
        uint uintday = uint(_day);

        day = uint16(uintday);        

        uint dayCounter;

        //loops through months to get current day of year
        for(uint monthCounter = 1; monthCounter <= month; monthCounter++) {
            dayCounter += _getDaysInMonth(uintyear, month);
        }

        yearDays = uint16(dayCounter);
    }

    function _isLeapYear(uint year) internal pure returns (bool leapYear) {
        leapYear = ((year % 4 == 0) && (year % 100 != 0)) || (year % 400 == 0);
    }

     function _getDaysInMonth(uint year, uint month) internal pure returns (uint daysInMonth) {
        if (month == 1 || month == 3 || month == 5 || month == 7 || month == 8 || month == 10 || month == 12) {
            daysInMonth = 31;
        } else if (month != 2) {
            daysInMonth = 30;
        } else {
            daysInMonth = _isLeapYear(year) ? 29 : 28;
        }
    }

    function userNotZero() view private {
        require(msg.sender != address(0), "3");
    }

    function futureOnHour(uint40 unixTime) view private {
         //require transactions to be in the future and to be on the hour
        require(unixTime > block.timestamp, "4");

        require(unixTime % 3600 == 0, "6");
    }

    
    function removeAccountTriggerItem(uint40 timeTrigger) private {

            //goes into account map and cleans up timeTriggers
            if(accountMap[msg.sender].timeTriggers.length == 1){
                delete accountMap[msg.sender].timeTriggers;
            } else {

                //deletes timeTrigger index in account
                uint40[] storage accountTimeTriggers = accountMap[msg.sender].timeTriggers;

                uint index2;

                for(uint i; i < accountTimeTriggers.length; i++) {
                    if(accountTimeTriggers[i] == timeTrigger) {
                        index2 = i;
                        delete accountTimeTriggers[i];
                        break;
                    }
                }

                accountTimeTriggers[index2] = accountTimeTriggers[accountTimeTriggers.length - 1];
                accountTimeTriggers.pop();

            }
    }
     
    
    //removes transction from the state. DOES NOT reorder lists. 
    function removeTransaction(bytes32 id, uint40 timeTrigger) private {

        //if only one transaction in array deletes entire array
        if(timeMap[timeTrigger].length == 1){
            delete timeMap[timeTrigger];

            removeAccountTriggerItem(timeTrigger);
            return;
        }

        Transaction[] storage transactions = timeMap[timeTrigger];
        //Transaction[] memory totalTransactions = transactionLookup;

        uint index;
        uint ownedCount;
        

        //zeros out data in transaction and counts how many transactions are connected to account
        for(uint i; i < transactions.length; i++) {

            if(transactions[i].sender == msg.sender){
                ownedCount++;
            }
            if(transactions[i].id == id) {
                index = i;
                delete transactions[i];
            }
            
        }

        //copies last element into gap and pops last element
        transactions[index] = transactions[transactions.length - 1];
        transactions.pop();

        if(ownedCount == 1) {
            //cleans up account timeTrigger index
            removeAccountTriggerItem(timeTrigger);
        }

        uint index2;

        //removes id from lookup
        for(uint i; i < transactionLookup.length; i++){
            if(transactionLookup[i] == id) {
                index2 = i;
                break;
            }
        }

        //copies last element into gap and pops last element
        transactionLookup[index2] = transactionLookup[transactionLookup.length - 1];
        transactionLookup.pop();
    }

   
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

    /*

    function getBalance() private view returns (uint) {
        return address(this).balance;
    }
    */

    
    /*
    function getTokenBalance(address account, address token) private view returns (uint) {
        return tokenClaims[account][token];
    }
    */
    
    //////////////////////

    //gets time TESTING FUNCTION
    /*
    function getTime() external view returns (uint) {
        return block.timestamp;
    }
    */

   
    //gets claims per token
    function getTotalClaims(address token) external view returns (uint) {
        return tokenClaims[msg.sender][token];
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
    


    //fetches subscription from day maps by id
    function getSubByIndex(SubIndex memory index) view private returns(Subscription memory subscription){
        
          if(index.subType == SubType.MONTHLY){
            
            Subscription[] memory subList = monthMap[index.dueDay];

                //searchs for subscription in day map
                for(uint j; j < subList.length; j++) {
                    if(subList[j].id == index.id) {
                        subscription = subList[j];
                    }
                }
          }
           if(index.subType == SubType.YEARLY){
            Subscription[] memory subList = yearMap[index.dueDay];

                //searchs for subscription in day map
                for(uint j; j < subList.length; j++) {
                    if(subList[j].id == index.id) {
                        subscription = subList[j];
                    }
                }
          }

          return subscription;
    }
 
    //&&
    //converts unixTime to hours
    function unixToHours(uint40 unixTime) private pure returns(uint40 hourCount){
        hourCount = unixTime/3600;
        return hourCount;
    }

    //&&
    //converts hours since merge to unix epoch utc time
    function hourstoUnix(uint40 timeTrigger) private pure returns(uint40 unixTime) {
        unixTime = timeTrigger*3600;
        return unixTime;
    }

    //subscriptions by account
    function getAccountSubscriptions() external view returns (Subscription[] memory) {
        
        //gets account index
        SubIndex[] memory index = accountMap[msg.sender].subscriptions;

        Subscription[] memory subscriptions = new Subscription[](index.length);

        //loops through account index and fetchs subscriptions
        for(uint i; i < index.length; i++){
            subscriptions[i] = getSubByIndex(index[i]);
        }
        
        return subscriptions;
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
                totalTransactions[i].timeTrigger = hourstoUnix(totalTransactions[i].timeTrigger);
        }
    
        //return transactions;
        return totalTransactions;
    }
    
    //sets Transaction
    function setTransaction(address sender, address payable receiver, address token, uint40 timeTrigger, uint payload) private view returns(Transaction memory _transaction){
        
            //creates id hash
            bytes32 id = keccak256(abi.encodePacked(sender, timeTrigger, block.timestamp));
            
            _transaction = Transaction(id, sender, receiver, token,timeTrigger, Status.PENDING, payload);

            return _transaction;
    }

    
    
    //sets Subscription
    function setSubscription(uint amount, address token, string memory description, SubType subType, uint40 dueDay) private view returns (Subscription memory subscription){

         //creates id hash
        bytes32 id = keccak256(abi.encodePacked(msg.sender, token, dueDay, description, block.timestamp));

        subscription = Subscription(id, amount, msg.sender, true, false, token, subType, dueDay, description);
    }
    
    //checks subscription exists
    function subExists(bytes32 id, uint40 dueDay, SubType subType) private view returns(bool) {
        //check subscription exists
        SubIndex memory index = SubIndex(id, dueDay, subType);

        Subscription memory memSubscription = getSubByIndex(index);

        if(memSubscription.exists) {
            return true;
        } else {
            return false;
        }
    }

    
    //deletes subscription index from account
    function deleteSubFromAccount(bytes32 id, address account) private {
        
        //deletes index in account
        address[] storage subscribers = subscribersMap[id];

        uint index2;

        for(uint i; i < subscribers.length; i++) {
            if(subscribers[i] == account) {
                index2 = i;
                delete subscribers[i];
                break; 
            }

            subscribers[index2] = subscribers[subscribers.length - 1];
            subscribers.pop();
        }
    }
    
    
    /*
     function _daysToDate(uint _days) external pure returns (uint month, uint day) {
        int __days = int(_days);

        int L = __days + 68569 + OFFSET19700101;
        int N = 4 * L / 146097;
        L = L - (146097 * N + 3) / 4;
        //int _year = 4000 * (L + 1) / 1461001;
        //L = L - 1461 * _year / 4 + 31;
        int _month = 80 * L / 2447;
        int _day = L - 2447 * _month / 80;
        L = _month / 11;
        _month = _month + 2 - 12 * L;
       // _year = 100 * (N - 49) + _year + L;

       // year = uint(_year);
        month = uint(_month);
        day = uint(_day);
    }
    */
    

    //------------------------------------------------------------
    //TODO: could try to lower gas: only pass parameters, use requires instead of existence check
    //allows subscriber to join a subscription
    function subscribe(Subscription calldata subscription) external payable {

        //cannot be sent from zero address
        userNotZero();

         //require sent ETH to be higher than fixed token fee
        require(fixedFee <= msg.value, "5");

        //check if there is enough allowance
        require(ERC20Permit(subscription.token).allowance(msg.sender, address(this)) >= subscription.amount, "13");
    
        //TODO: turn on after testing
        //cant subscribe to subscription you own
        //require(msg.sender != subscription.owner, "Cant be owner and subscriber");

        //require(memSubscription.exists, "Subscription doesn't exist");
        require(subExists(subscription.id, subscription.dueDay, subscription.subType), "7");

        //adds to subscriber map
        subscribersMap[subscription.id].push() = msg.sender;

        //adds it to account
        addAccountSubscription(SubIndex(subscription.id, subscription.dueDay, subscription.subType));

    }
    
    function unsubscribe(bytes32 id) external payable {

        //cannot be sent from zero address
        userNotZero();

         //require sent ETH to be higher than fixed token fee
        require(fixedFee <= msg.value, "5");

        deleteSubFromAccount(id, msg.sender);

        //deleteSubFromAccount(id, msg.sender);
    }
        

    //TODO: test 
    function cancelSubscription(Subscription calldata subscription) external {
        userNotZero();

        require(subExists(subscription.id, subscription.dueDay, subscription.subType), "7");

        //gets list of subscribers and deletes all entries in their accounts
        address[] memory subscribers = subscribersMap[subscription.id];

        for(uint i; i < subscribers.length; i++) {
            //gets location of subscription index in array
            deleteSubFromAccount(subscription.id, subscribers[i]);
            //subscribers[i].deleteSubFromAccount(subscribersMap[subscription.id]);
        }

        
        //sets cancelled bool to true
        if(subscription.subType == SubType.MONTHLY) {
            Subscription[] memory subscriptions = monthMap[subscription.dueDay];

            for(uint i; i < subscribers.length; i++) {
                if(subscriptions[i].id == subscription.id) {
                    monthMap[subscription.dueDay][i].cancelled = true;
                }
            }

        }

        if(subscription.subType == SubType.YEARLY) {
             Subscription[] memory subscriptions = yearMap[subscription.dueDay];

            for(uint i; i < subscribers.length; i++) {
                if(subscriptions[i].id == subscription.id) {
                    yearMap[subscription.dueDay][i].cancelled = true;
                }
            }
        }
        
    }
    
    
    
    //allows provider user to create a subscription
    function createSubscription(uint amount, address token, string calldata description, SubType subtype, uint16 dueDay) external payable {
        
         //cannot be sent from zero address
        //require(msg.sender != address(0), "No zero address call");
        userNotZero();

        //cannot be ETH or zero address
        require(token != address(0), "8");

         //require sent ETH to be higher than fixed token fee
        require(fixedFee <= msg.value, "5");

        //check if token is on approved list
        require(erc20IsApproved(token),"9");

        //amount must be greater than zero
        require(amount > 0, "10");

        //Subscription memory subscriptionTest = test.setSubscription(amount, token, description, subtype, dueDay);
        //creates subscription
        Subscription memory subscription = setSubscription(amount,token, description, subtype, dueDay);

         //month subscription
        if(subtype == SubType.MONTHLY) {
            //recurring day must be between 1 and 28
            require(0 < dueDay && dueDay <= 28, "Monthly due date must be between 1 and 28");

            //creates subscription
            monthMap[dueDay].push() = subscription;
        }

        if(subtype == SubType.YEARLY) {
            //recurring annual day must be between 1 and 365
            require(0 < dueDay && dueDay <= 365, "Yearly due date must be between 1 and 365");

            yearMap[dueDay].push() = subscription;
        }

         //creates subscription index
        //SubIndex memory subindex = SubIndex(subscription.id, subscription.dueDay, subscription.subType);

        //adds it to account
        addAccountSubscription(SubIndex(subscription.id, subscription.dueDay, subscription.subType));

    }

    function addAccountSubscription(SubIndex memory subIndex) private {
          //new account
        if(accountMap[msg.sender].exists == false) {
            accountMap[msg.sender].accountAddress = msg.sender;
            //adds to lookup table
            accountLookup.push() = msg.sender;
            accountMap[msg.sender].exists = true;
        } 
        accountMap[msg.sender].subscriptions.push() = subIndex;
    }


    function addAccountTransaction(uint40 timeTrigger) private {

        //new account
        if(accountMap[msg.sender].exists == false) {
            accountMap[msg.sender].accountAddress = msg.sender;
            //adds to lookup table
            accountLookup.push() = msg.sender;
            accountMap[msg.sender].exists = true;
            accountMap[msg.sender].timeTriggers.push() = timeTrigger;
        } else {

            //gets lookup arrays from account struct
            uint40[] memory accountTriggers = accountMap[msg.sender].timeTriggers;
            
            //if doesn't already exist adds time trigger to account list
            if(!isInTimeArray(timeTrigger, accountTriggers)) {
                accountMap[msg.sender].timeTriggers.push() = timeTrigger;
            }
            
        }
    }

    function cancelTransaction(bytes32 id, uint40 unixTrigger, address token) payable external {

         //cannot be sent from zero address
        //require(msg.sender != address(0), "No zero address call");
        userNotZero();

        //converts time trigger to hour
        uint40 timeTrigger = unixToHours(unixTrigger);

        //refunds ethereum
            Transaction[] memory timeTransactions = timeMap[timeTrigger];
            Transaction memory transaction;

            //loops through time transactions to find cancelled one
            for(uint i = 0; i < timeTransactions.length; i++) {
                
                if(timeTransactions[i].id == id){
                    transaction = timeTransactions[i];
                    break;
                }
            }

             //removes transaction
            removeTransaction(transaction.id, transaction.timeTrigger);

            if(token != address(0)){
                //removes from claim balance
                tokenClaims[msg.sender][token] -= transaction.payload;
            } else {

                //removes from claim balance
                tokenClaims[msg.sender][token] -= transaction.payload;
            
                //checks contract has enough eth
                require(address(this).balance > transaction.payload);

                //checks transaction goes through
                require(payable(transaction.sender).send(transaction.payload));
            }
    }
    
    
   //REQUIRES unlimited allowance per token
   //adds to list of transactions 
    function addTransaction(address payable receiver, uint40 unixTime, uint payload, address token) stopInEmergency payable external {

         //cannot be sent from zero address
       // require(msg.sender != address(0), "No zero address call");
       userNotZero();
        
        //require transactions to be in the future and to be on the hour
        //require(unixTime > block.timestamp, "Time must be in the future");

        //require(unixTime % 3600 == 0, "Time must be on the hour");
        futureOnHour(unixTime);
        
        if(token == address(0)) {
            //require sent ETH to be higher than payload * fee
            require(payload * fee / 100 <= msg.value, "5");
        } else {

             //require sent ETH to be higher than fixed token fee
            require(fixedFee <= msg.value, "5");

            //check if token is on approved list
            require(erc20IsApproved(token),"9");

            //check if there is enough allowance
            require(ERC20Permit(token).allowance(msg.sender, address(this)) >= tokenClaims[msg.sender][token] + payload, "13");
        }
        
        //calculates hours since merge from passed unixTime
        uint40 timeTrigger = unixToHours(unixTime);

         //creates transaction
        Transaction memory transaction = setTransaction(msg.sender, receiver, token, timeTrigger, payload);

        timeMap[timeTrigger].push() = transaction;

        //adds transaction to lookup
        transactionLookup.push() = transaction.id;

        //creates or updates account
        addAccountTransaction(timeTrigger); 

        //updates token balance
        tokenClaims[msg.sender][token] += payload;

    }

/*
    //adds to list of transactions 
    function addPermitTransaction(address payable receiver, uint40 unixTime, uint payload, address token, Permit calldata permit) stopInEmergency payable external {

         //cannot be sent from zero address
       // require(msg.sender != address(0), "No zero address call");
       userNotZero();
        
        //require transactions to be in the future and to be on the hour
        //require(unixTime > block.timestamp, "Time must be in the future");

        //require(unixTime % 3600 == 0, "Time must be on the hour");
        futureOnHour(unixTime);
        
        if(token == address(0)) {
            //require sent ETH to be higher than payload * fee
            require(payload * fee / 100 <= msg.value, "5");
        } else {
             //require sent ETH to be higher than fixed token fee
            require(fixedFee <= msg.value, "5");

            //check if token is on approved list
            require(erc20IsApproved(token),"9");

            //requires payload to be the same as permit value
            require(payload <= permit.value, "Payload must be <= value permitted");
        }
        
        //calculates hours since merge from passed unixTime
        uint40 timeTrigger = unixToHours(unixTime); 

         //creates transaction
        Transaction memory transaction = setTransaction(msg.sender, receiver, token, timeTrigger, payload);

        timeMap[timeTrigger].push() = transaction;

        //adds transaction to lookup
        transactionLookup.push() = transaction.id;  

        //creates or updates account
        addAccountTransaction(timeTrigger); 

        //updates token balance (and ETH at 0x0)
        tokenClaims[msg.sender][token] += payload;

        if(token != address(0)) {
            //uses permit to approve transfer
            ERC20Permit(token).permit(permit.owner, permit.spender, permit.value, permit.deadline, permit.v, permit.r, permit.s);
        }
    }
    */

    //REQUIRE maximum 100 transactions (based on gas limit per block)
    //REQUIRE approval for token totals to be done in advance of calling this function
    function addBatchTransactions(Batch[] memory batch) stopInEmergency payable external {

         //cannot be sent from zero address
        //require(msg.sender != address(0), "No zero address call");
        userNotZero();

        //Batch needs more than one transaction (single batch transaction uses more gas than addTransaction)
        require(((batch.length > 1) && (batch.length < 100)), "Batch must > one transaction < 100");

        //have to put top level function variables in a struct to avoid variable per function limit
        BatchVariables memory variables;

         //require sent ETH to be higher than fixed token fee
        require(fixedFee * batch.length <= msg.value, "5");

        //creates arrays for a list of tokens in batch sized to overall approved contract addresses
        address[] memory batchTokenList = new address[](approvedERC20.length);

        //array for unique time triggers in batch (max array size based on existing unique time triggers plus max batch size)
        uint40[] memory batchTriggerList = new uint40[](accountMap[msg.sender].timeTriggers.length + 100);

        uint i;

        //validates data in each transaction and creates lists of unique tokens and timeTriggers
        for(i = 0; i < batch.length; i++) {

            //require transactions to be in the future and to be on the hour
            //require(batch[i].unixTime > block.timestamp, "Time must be in the future");

            //require(batch[i].unixTime % 3600 == 0, "Time must be on the hour");
            futureOnHour(batch[i].unixTime);

            
            //if time trigger is unique we put it in the list
            uint40 timeTrigger2 = unixToHours(batch[i].unixTime);

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
                require(erc20IsApproved(batch[i].token),"9");

                 //check if there is enough allowance
                require(ERC20Permit(batch[i].token).allowance(msg.sender, address(this)) >= tokenClaims[msg.sender][batch[i].token] + batch[i].payload, "13");
        
               
                if(!isInAddressArray(batch[i].token, batchTokenList)) {
                    batchTokenList[variables.uniqueTokenCount] = batch[i].token;
                    variables.uniqueTokenCount += 1;
                } 
            
            }

            //updates token balance (and ETH balance at 0x0)
            batchTokenTotals[batch[i].token] += batch[i].payload;

            //updates claim balance
            tokenClaims[msg.sender][batch[i].token] += batch[i].payload;
        }

        
        //makes sure enough ETH was sent in payloads
        //require sent ETH to be higher than payload * fee
        
        require(variables.ethPayloads * fee / 100 <= msg.value, "5");

        //iterates through batch time triggers 
        for(i = 0; i < batchTriggerList.length; i++) {

            //stops when it hits empty part of array
            if(batchTriggerList[i] == 0) {
                break;
            }

            //creates transaction array
            for(uint16 j = 0; j < batch.length; j++) {

                uint40 time = unixToHours(batch[j].unixTime);


                if(time == batchTriggerList[i]) {
                    //creates internal transaction struct
                    Transaction memory transaction = setTransaction(msg.sender, batch[j].receiver, batch[j].token, time , batch[j].payload);

                    timeMap[batchTriggerList[i]].push() = transaction;
                
                    //adds transaction to lookup
                    transactionLookup.push() = transaction.id;
                }
            }
        }
        
        //checks if token already exists or not and adds to account
        for(i = 0; i < batchTokenList.length; i++) {

            //checks that user has set allowance to contract high enough for each token
            if(batchTokenList[i] != address(0)) {
                //checks that allowances were set correctly
                require(ERC20Permit(batchTokenList[i]).allowance(msg.sender, address(this)) >= batchTokenTotals[batchTokenList[i]] && ERC20Permit(batchTokenList[i]).balanceOf(msg.sender) >= batchTokenTotals[batchTokenList[i]]);
            }
    
            //resets tokenTotal
            batchTokenTotals[batchTokenList[i]] = 0;

        }
        
        if(accountMap[msg.sender].exists == false) {
            //account.accountAddress = msg.sender;
            accountMap[msg.sender].accountAddress = msg.sender;
             //adds to lookup table
            accountLookup.push() = msg.sender;
            accountMap[msg.sender].exists = true;
        }
    }

     //TODO: could add emit of transaction confirm hash
    function sendTransactions(Transaction[] memory transactions) stopInEmergency private {

        uint ethTotal;
        uint index;
        Transaction[] memory sortedTransactions = new Transaction[](transactions.length);

        //makes sure contract has enough ETH or tokens to pay for transaction strips out failed transactions
        for(uint i; i < transactions.length; i++) {
            
            if(transactions[i].token == address(0)) {
                ethTotal += transactions[i].payload;
                sortedTransactions[index] = transactions[i];
                index++;
                } else {
                //if account doesn't have enough allowance consider transaction to have failed and delete it
                if(ERC20Permit(transactions[i].token).allowance(transactions[i].sender, address(this)) < transactions[i].payload || ERC20Permit(transactions[i].token).balanceOf(transactions[i].sender) < transactions[i].payload) {
                    timeMap[transactions[i].timeTrigger][i].status = Status.FAILED;
                } else {
                    sortedTransactions[index] = transactions[i];
                    index++;
                    timeMap[transactions[i].timeTrigger][i].status = Status.SENT;
                }
            }
        }

        //reverts entire procedure if theres not enough eth
        require(address(this).balance > ethTotal, "11");

        for(uint j; j < sortedTransactions.length; j++) {
            //decreases claimsBalance
            tokenClaims[sortedTransactions[j].sender][sortedTransactions[j].token] -= sortedTransactions[j].payload;
            
            if(sortedTransactions[j].token == address(0)){
                //transfers ETH (Note: this doesn't need to be composible so send() is more secure than call() to avoid re-entry)
                bool success = sortedTransactions[j].receiver.send(sortedTransactions[j].payload);
                require(success, "12");
            } else {
                //transfers Token
                require(ERC20Permit(sortedTransactions[j].token).transferFrom(sortedTransactions[j].sender, sortedTransactions[j].receiver, sortedTransactions[j].payload));
            }
        }        
    }

    //checks list of blocks between now and when it was last checked (ONLY CAN BE CALLED BY ADMIN CURRENTLY)
    function sendTime() external isAdmin {

        //gets current time slot based on hour
        uint40 _currentTimeSlot = unixToHours(uint40(block.timestamp));

        require(_currentTimeSlot > lastCheckedHour, "14");

        for(uint40 i = lastCheckedHour; i <= _currentTimeSlot; i++) {

            //gets transaction array per time trigger
            if(timeMap[i].length > 0) {
               
               sendTransactions(timeMap[i]);       
            }          
        }

        //updates lastCheckedTimeSlot
        lastCheckedHour = _currentTimeSlot;
    }

    //view function that checks if any transactions are in line to be sent
    function checkTime() external view isAdmin returns (bool) {
         //gets current time slot based on hour
        uint40 _currentTimeSlot = unixToHours(uint40(block.timestamp));

        require(_currentTimeSlot > lastCheckedHour, "14");

        for(uint40 i = lastCheckedHour; i <= _currentTimeSlot; i++) {

            //if block has transactions add them to transaction list
            if(timeMap[i].length > 0) {
                return true;
            }
        }
        return false;
    }

    
    //TODO:
    //Might want to require unlimited allowance for subscriptions

    //completes money transfer for subscribers
    function chargeSubs() external isAdmin {

        //calls library function
        //(uint16 yearDays, uint16 _days) = (block.timestamp).unixToDays();
        (uint16 yearDays, uint16 _days) = unixToDays(block.timestamp);
        
        //gets subscriptions from mappings
        //Subscription[] memory monthlySubs = monthMap[_days];
        //Subscription[] memory yearlySubs = yearMap[yearDays];
        
        //loops through monthly subscriptions
        for(uint i; i < monthMap[_days].length; i++) {

            if(!monthMap[_days][i].cancelled) {

                bytes32 id = monthMap[_days][i].id;
                address token = monthMap[_days][i].token;
                uint amount = monthMap[_days][i].amount;
                //loops through subscribers
                for(uint j; j < subscribersMap[id].length; j++) {
                    
                    //checks for failure (balance and unlimited allowance)
                    address subscriber = subscribersMap[id][j];

                    //check if there is enough allowance and balance
                    if(ERC20Permit(monthMap[_days][i].token).allowance(subscriber, address(this)) >= amount
                    && 
                    ERC20Permit(token).balanceOf(subscribersMap[id][j]) < amount) {
                        //log as failed
                        paymentLog[subscriber] = SubLog(id, uint40(block.timestamp), false);
                    } else {

                         //log as succeeded
                        paymentLog[subscriber] = SubLog(id, uint40(block.timestamp), true);
                        //completes transaction
                        require(ERC20Permit(token).transferFrom(subscriber, monthMap[_days][i].owner, amount));
                    }
                    
                }
            }
        }

        //loops through yearly subscriptions
        for(uint i; i < yearMap[yearDays].length; i++) {

            if(!yearMap[_days][i].cancelled) {

                bytes32 id = yearMap[_days][i].id;
                address token = yearMap[_days][i].token;
                uint amount = yearMap[_days][i].amount;
                //loops through subscribers
                for(uint j; j < subscribersMap[id].length; j++) {
                    
                    //checks for failure (balance and unlimited allowance)
                    address subscriber = subscribersMap[id][j];

                    //check if there is enough allowance and balance
                    if(ERC20Permit(yearMap[_days][i].token).allowance(subscriber, address(this)) >= amount
                    && 
                    ERC20Permit(token).balanceOf(subscribersMap[id][j]) < amount) {
                        //log as failed
                        paymentLog[subscriber] = SubLog(id, uint40(block.timestamp), false);
                    } else {

                         //log as succeeded
                        paymentLog[subscriber] = SubLog(id, uint40(block.timestamp), true);
                        //completes transaction
                        require(ERC20Permit(token).transferFrom(subscriber, yearMap[_days][i].owner, amount));
                    }
                    
                }
            }
        }
    }
}