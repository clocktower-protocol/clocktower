// SPDX-License-Identifier: UNLICENSED
//Copyright Hugo Marx 2023
//Written by Hugo Marx
pragma solidity ^0.8.9;
import "hardhat/console.sol";

interface ERC20Permit{
function transferFrom(address from, address to, uint value) external returns (bool);
  function balanceOf(address tokenOwner) external returns (uint);
  function approve(address spender, uint tokens) external returns (bool);
  function permit(address owner, address spender, uint value, uint deadline, uint8 v, bytes32 r, bytes32 s) external;
  function allowance(address owner, address spender) external returns (uint);
} 

contract ClockTowerSubscribe {

    constructor() payable {
    }

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

    //admin addresses
    address admin = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;

    //100 = 100%
    uint fee = 100;
    //0.01 eth in wei
    uint fixedFee = 10000000000000000;

    enum SubType {
        WEEKLY,
        MONTHLY,
        YEARLY
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
        address token;
        bool exists;
        bool cancelled;
        SubType subType;
        uint16 dueDay;
        string description;
        //address[] subscribers;
    }


    //struct of Subscription indexes
    struct SubIndex {
        bytes32 id;
        uint16 dueDay;
        SubType subType;
    }

    //struct of subscription payments
    struct SubLog {
        bytes32 subId;
        uint40 timestamp; 
        bool success;
    }

    //--------------Account Mappings-------------

    //Account map
    mapping(address => Account) private accountMap;
     //creates lookup table for mapping
    address[] private accountLookup;

    //---------------------------------------------

    //--------------Subscription mappings------------ 

    //Subscription master map keyed on type
    mapping(uint => mapping(uint16 => Subscription[])) subscriptionMap;

    //map of subscribers
    mapping(bytes32 => address[]) subscribersMap;

    //&&
    //log of subscription payments
    mapping(address => SubLog) paymentLog;

    //--------------------------------------------

    //approved contract addresses
    address[] approvedERC20;

    //circuit breaker
    bool stopped = false;

    //variable for last checked by hour
    uint40 lastCheckedHour = (unixToHours(uint40(block.timestamp)) - 1);

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

    //-------------------------------------------------------

     //TIME FUNCTIONS-----------------------------------
    function unixToDays(uint unix) public pure returns (uint16 yearDays, uint16 quarterDay, uint16 day) {
       
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
            if(monthCounter == month) {
                dayCounter += day;
            } else {
                dayCounter += getDaysInMonth(uintyear, month);
            }
        }

        yearDays = uint16(dayCounter);

        uint quarterDayuint;
        //gets day of quarter
        quarterDayuint = getdayOfQuarter(yearDays, uintyear);
        quarterDay = uint16(quarterDayuint);
    }

    function isLeapYear(uint year) internal pure returns (bool leapYear) {
        leapYear = ((year % 4 == 0) && (year % 100 != 0)) || (year % 400 == 0);
    }

    function getDaysInMonth(uint year, uint month) internal pure returns (uint daysInMonth) {
        if (month == 1 || month == 3 || month == 5 || month == 7 || month == 8 || month == 10 || month == 12) {
            daysInMonth = 31;
        } else if (month != 2) {
            daysInMonth = 30;
        } else {
            daysInMonth = isLeapYear(year) ? 29 : 28;
        }
    }

    // 1 = Monday, 7 = Sunday
    function getDayOfWeek(uint unixTime) internal pure returns (uint dayOfWeek) {
        uint _days = unixTime / 86400;
        dayOfWeek = (_days + 3) % 7 + 1;
    }

    //get day of quarter
    function getdayOfQuarter(uint yearDays, uint year) internal pure returns (uint quarterDay) {
       // (uint yearDays, uint _days) = unixToDays(unixTime);
        
        uint leapDay;
        if(isLeapYear(year)) {
            leapDay = 1;
        } else {
            leapDay = 0;
        }

        if(yearDays <= (90 + leapDay)) {
            quarterDay = yearDays;
        } else if((90 + leapDay) < yearDays && yearDays <= (181 + leapDay)) {
            quarterDay = yearDays - (90 + leapDay);
        } else if((181 + leapDay) < yearDays && yearDays <= (273 + leapDay)) {
            quarterDay = yearDays - (181 + leapDay);
        } else {
            quarterDay = yearDays - (273 + leapDay);
        }
    }


      //converts unixTime to hours
    function unixToHours(uint40 unixTime) private pure returns(uint40 hourCount){
        hourCount = unixTime/3600;
        return hourCount;
    }

    //converts hours since merge to unix epoch utc time
    function hourstoUnix(uint40 timeTrigger) private pure returns(uint40 unixTime) {
        unixTime = timeTrigger*3600;
        return unixTime;
    }

    //UTILITY FUNCTIONS -----------------------------------------------

    function userNotZero() view private {
        require(msg.sender != address(0), "3");
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

      //fetches subscription from day maps by id
    function getSubByIndex(SubIndex memory index) view private returns(Subscription memory subscription){

          Subscription[] memory subList = subscriptionMap[uint(index.subType)][index.dueDay];

            //searchs for subscription in day map
            for(uint j; j < subList.length; j++) {
                if(subList[j].id == index.id) {
                        subscription = subList[j];
                }
            }
          return subscription;
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

    //sets Subscription
    function setSubscription(uint amount, address token, string memory description, SubType subType, uint16 dueDay) private view returns (Subscription memory subscription){

         //creates id hash
        bytes32 id = keccak256(abi.encodePacked(msg.sender, token, dueDay, description, block.timestamp));

        subscription = Subscription(id, amount, msg.sender, token, true, false, subType, dueDay, description);
    }
    
    //checks subscription exists
    function subExists(bytes32 id, uint16 dueDay, SubType subType) private view returns(bool) {
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

    //Subscription functions----------------------------------------
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
        }

        Subscription[] memory subscriptions = subscriptionMap[uint(subscription.subType)][subscription.dueDay];
        for(uint i; i < subscribers.length; i++) {
            if(subscriptions[i].id == subscription.id) {
               // monthMap[subscription.dueDay][i].cancelled = true;
               subscriptionMap[uint(subscription.subType)][subscription.dueDay];
            }
        }
    }
    
    
    
    //allows provider user to create a subscription
    function createSubscription(uint amount, address token, string calldata description, SubType subtype, uint16 dueDay) external payable {
        
        //cannot be sent from zero address
        userNotZero();

        //cannot be ETH or zero address
        require(token != address(0), "8");

         //require sent ETH to be higher than fixed token fee
        require(fixedFee <= msg.value, "5");

        //check if token is on approved list
        require(erc20IsApproved(token),"9");

        //amount must be greater than zero
        require(amount > 0, "10");

        //creates subscription
        Subscription memory subscription = setSubscription(amount,token, description, subtype, dueDay);

        if(subtype == SubType.WEEKLY) {
            require(0 < dueDay && dueDay <= 7, "Weekly due date must be between 1 and 7");
        }
        if(subtype == SubType.MONTHLY) {
            require(0 < dueDay && dueDay <= 28, "Monthly due date must be between 1 and 28");
        }
        if(subtype == SubType.YEARLY) {
            require(0 < dueDay && dueDay <= 365, "Yearly due date must be between 1 and 365");
        }
        subscriptionMap[uint(subtype)][dueDay].push() = subscription;
 
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

    //TODO:
    //Might want to require unlimited allowance for subscriptions

    //completes money transfer for subscribers
    function chargeSubs() external isAdmin {

        //calls library function
        //(uint16 yearDays, uint16 _days) = (block.timestamp).unixToDays();
        (uint16 yearDays, uint16 _days, uint16 quarterDay) = unixToDays(1680325200);

        uint weekdayuint = getDayOfWeek(block.timestamp);
        uint16 weekday = uint16(weekdayuint);

        console.log(yearDays);
        console.log(quarterDay);
        console.log(_days);
        
        //gets subscriptions from mappings

        //loops through types
        for(uint s = 0; s <= 2; s++) {

            uint16 timeTrigger;
            if(s == uint(SubType.WEEKLY)){
                timeTrigger = weekday;
            }
            if(s == uint(SubType.MONTHLY)) {
                timeTrigger = _days;
            }
            if(s == uint(SubType.YEARLY)) {
                timeTrigger = yearDays;
            }

             //loops through monthly subscriptions
            for(uint i; i < subscriptionMap[s][timeTrigger].length; i++) {
                //checks if cancelled
                if(!subscriptionMap[s][timeTrigger][i].cancelled) {

                    bytes32 id = subscriptionMap[s][timeTrigger][i].id;
                    address token = subscriptionMap[s][timeTrigger][i].token;
                    uint amount = subscriptionMap[s][timeTrigger][i].amount;
                    //loops through subscribers
                    for(uint j; j < subscribersMap[id].length; j++) {
                        
                        //checks for failure (balance and unlimited allowance)
                        address subscriber = subscribersMap[id][j];

                        //check if there is enough allowance and balance
                        if(ERC20Permit(subscriptionMap[s][timeTrigger][i].token).allowance(subscriber, address(this)) >= amount
                        && 
                        ERC20Permit(token).balanceOf(subscribersMap[id][j]) < amount) {
                            //log as failed
                            paymentLog[subscriber] = SubLog(id, uint40(block.timestamp), false);
                        } else {

                            //log as succeeded
                            paymentLog[subscriber] = SubLog(id, uint40(block.timestamp), true);
                            //completes transaction
                            require(ERC20Permit(token).transferFrom(subscriber, subscriptionMap[s][timeTrigger][i].owner, amount));
                        }
                        
                    }
                }
            }
        }
    }

    //--------------------------------------------------------------
 

}