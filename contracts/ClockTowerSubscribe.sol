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

    //10000 = No fee, 10100 = 1%, 10001 = 0.01%
    uint fee = 10200;

    //0.01 eth in wei
    uint fixedFee = 10000000000000000;

    //maximum gas value before waiting (in gigawei)
    uint maxGasPrice = 50000000000;
    //maximum remits per transaction
    uint maxRemits = 5;
    //index if transaction pagination needed due to remit amount being larger than block
    PageStart pageStart;
   // uint pageCount;
    bool pageGo;

    enum SubType {
        WEEKLY,
        MONTHLY,
        QUARTERLY,
        YEARLY
    }

    enum Status {
        ACTIVE,
        CANCELLED,
        UNSUBSCRIBED
    }

    //acount struct
    struct Account {
        address accountAddress;
        //string description;
        bool exists;
        //timeTriggers is empty for subscriptions
        uint40[] timeTriggers;
        SubIndex[] subscriptions;
        SubIndex[] provSubs;
    }

    //Subscription struct
    struct Subscription {
        bytes32 id;
        uint amount;
        address provider;
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
        Status status;
    }

    struct PageStart {
        bytes32 id;
        uint subsriberIndex;
    }

    //same as subscription but adds the status for subscriber
    struct SubView {
        Subscription subscription;
        Status status;
       // SubLog[] subLog;
    }

    //struct of time return values
    struct Time {
        uint16 day;
        uint16 weekDay;
        uint16 quarterDay;
        uint16 yearDay;
    }

    //Events-------------------------------------
    event SubPaymentLog(
        bytes32 indexed id,
        address indexed subscriber,
        uint40 timestamp,
        bool success
    );

    event RemitLog(
        uint40 timestamp,
        uint40 checkedDay,
        address caller,
        bool isFinished
    );

    //-------------------------------------------

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
    //mapping(address => mapping(bytes32 => SubLog[])) paymentLog;

    //--------------------------------------------

    //approved contract addresses
    address[] approvedERC20;

    //circuit breaker
    bool stopped = false;

    //variable for last checked by hour
    uint40 lastCheckedDay = (unixToDays(uint40(block.timestamp)) - 1);

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
        
        uint index;

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

    //change max gas
    function changeMaxGasPrice(uint _maxGas) isAdmin external {
        maxGasPrice = _maxGas;
    }

      //change max gas
    function changeMaxRemits(uint _maxRemits) isAdmin external {
        maxRemits = _maxRemits;
    }

    //-------------------------------------------------------

     //TIME FUNCTIONS-----------------------------------
    function unixToTime(uint unix) public pure returns (Time memory time) {
       
        uint _days = unix/86400;
        uint16 day;
        uint16 yearDay;
       
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

        yearDay = uint16(dayCounter);

        //gets day of quarter
        time.quarterDay = getdayOfQuarter(yearDay, uintyear);
        time.weekDay = getDayOfWeek(unix);
        time.day = day;
        time.yearDay = yearDay;
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
    function getDayOfWeek(uint unixTime) internal pure returns (uint16 dayOfWeek) {
        uint _days = unixTime / 86400;
        uint dayOfWeekuint = (_days + 3) % 7 + 1;
        dayOfWeek = uint16(dayOfWeekuint);

    }

    //get day of quarter
    function getdayOfQuarter(uint yearDays, uint year) internal pure returns (uint16 quarterDay) {
       // (uint yearDays, uint _days) = unixToDays(unixTime);
        
        uint leapDay;
        if(isLeapYear(year)) {
            leapDay = 1;
        } else {
            leapDay = 0;
        }

        if(yearDays <= (90 + leapDay)) {
            quarterDay = uint16(yearDays);
        } else if((90 + leapDay) < yearDays && yearDays <= (181 + leapDay)) {
            quarterDay = uint16(yearDays - (90 + leapDay));
        } else if((181 + leapDay) < yearDays && yearDays <= (273 + leapDay)) {
            quarterDay = uint16(yearDays - (181 + leapDay));
        } else {
            quarterDay = uint16(yearDays - (273 + leapDay));
        }
    }

/*
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
*/
    //converts unixTime to days
    function unixToDays(uint40 unixTime) private pure returns(uint40 dayCount) {
        dayCount = unixTime/86400;
    }

    //VIEW FUNCTIONS -----------------------------------------------

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
    function getAccountSubscriptions(bool bySubscriber) external view returns (SubView[] memory) {
        
        SubIndex[] memory indexes;
        //gets account indexes
        if(bySubscriber) {
            indexes = accountMap[msg.sender].subscriptions;
        } else {
            indexes = accountMap[msg.sender].provSubs;
        }

        SubView[] memory subViews = new SubView[](indexes.length);

        //loops through account index and fetchs subscriptions, status and logs
        for(uint i; i < indexes.length; i++){
            subViews[i].subscription = getSubByIndex(indexes[i]);
            subViews[i].status = indexes[i].status;
        }
        
        return subViews;
    }

    //PRIVATE FUNCTIONS----------------------------------------------

    //sets Subscription
    function setSubscription(uint amount, address token, string memory description, SubType subType, uint16 dueDay) private view returns (Subscription memory subscription){

         //creates id hash
        bytes32 id = keccak256(abi.encodePacked(msg.sender, token, dueDay, description, block.timestamp));

        subscription = Subscription(id, amount, msg.sender, token, true, false, subType, dueDay, description);
    }
    
    //checks subscription exists
    function subExists(bytes32 id, uint16 dueDay, SubType subType, Status status) private view returns(bool) {
        
        //check subscription exists
        SubIndex memory index = SubIndex(id, dueDay, subType, status);

        Subscription memory memSubscription = getSubByIndex(index);

        if(memSubscription.exists) {
            return true;
        } else {
            return false;
        }
        
    }

    //deletes subscribers from Subscription
    function deleteSubFromSubscription(bytes32 id, address account) private {
        
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

    function addAccountSubscription(SubIndex memory subIndex, bool isProvider) private {
        //new account
        if(accountMap[msg.sender].exists == false) {
            accountMap[msg.sender].accountAddress = msg.sender;
            //adds to lookup table
            accountLookup.push() = msg.sender;
            accountMap[msg.sender].exists = true;
        } 
        if(isProvider){
            accountMap[msg.sender].provSubs.push() = subIndex;
        } else {
            accountMap[msg.sender].subscriptions.push() = subIndex;
        }
    }


    //EXTERNAL FUNCTIONS----------------------------------------
    //TODO: could try to lower gas: only pass parameters, use requires instead of existence check
    //allows subscriber to join a subscription
    function subscribe(Subscription calldata subscription) external payable {

        //cannot be sent from zero address
        userNotZero();

        //TODO: determine if you want a fee on subscribe and unsubscribe
         //require sent ETH to be higher than fixed token fee
        //require(fixedFee <= msg.value, "5");

        //check if there is enough allowance
        require(ERC20Permit(subscription.token).allowance(msg.sender, address(this)) >= subscription.amount, "13");
    
        //TODO: turn on after testing
        //cant subscribe to subscription you own
        //require(msg.sender != subscription.owner, "Cant be owner and subscriber");

        require(subExists(subscription.id, subscription.dueDay, subscription.subType, Status.ACTIVE), "7");

        //adds to subscriber map
        subscribersMap[subscription.id].push() = msg.sender;

        //adds it to account
        addAccountSubscription(SubIndex(subscription.id, subscription.dueDay, subscription.subType, Status.ACTIVE), false);

    }
    
    function unsubscribe(bytes32 id) external payable {

        //cannot be sent from zero address
        userNotZero();

        //TODO: determine if you want a fee on subscribe and unsubscribe
         //require sent ETH to be higher than fixed token fee
        //require(fixedFee <= msg.value, "5");
        
        //sets account subscription status as unsubscribed
        SubIndex[] memory indexes = new SubIndex[](accountMap[msg.sender].subscriptions.length);
        indexes = accountMap[msg.sender].subscriptions;
        for(uint j; j < accountMap[msg.sender].subscriptions.length; j++){
            if(indexes[j].id == id) {
                accountMap[msg.sender].subscriptions[j].status = Status.UNSUBSCRIBED;
            }
        }

        deleteSubFromSubscription(id, msg.sender);
    }
        
    function cancelSubscription(Subscription calldata subscription) external {
        userNotZero();

        //checks subscription exists
        require(subExists(subscription.id, subscription.dueDay, subscription.subType, Status.ACTIVE), "7");


        //gets list of subscribers and deletes subscriber list
        address[] memory subscribers = subscribersMap[subscription.id];

        for(uint i; i < subscribers.length; i++) {
            //sets account subscription status as cancelled
            SubIndex[] memory indexes = new SubIndex[](accountMap[subscribers[i]].subscriptions.length);
            indexes = accountMap[subscribers[i]].subscriptions;
            for(uint j; j < accountMap[subscribers[i]].subscriptions.length; j++){
                if(indexes[j].id == subscription.id) {
                    accountMap[subscribers[i]].subscriptions[j].status = Status.CANCELLED;
                }
            }
            //deletes subscriber list
            deleteSubFromSubscription(subscription.id, subscribers[i]);
        }

        //sets cancelled bool to true for subscription
        Subscription[] memory subscriptions = subscriptionMap[uint(subscription.subType)][subscription.dueDay];
        for(uint i; i < subscriptions.length; i++) {
            if(subscriptions[i].id == subscription.id) {
               subscriptionMap[uint(subscription.subType)][subscription.dueDay][i].cancelled = true;
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

        //description must be 32 bytes or less
        require(bytes(description).length <= 32, "String must be <= 32 bytes");

        //validates dueDay
         if(subtype == SubType.WEEKLY) {
            require(0 < dueDay && dueDay <= 7, "Must be between 1 and 7");
        }
        if(subtype == SubType.MONTHLY) {
            require(0 < dueDay && dueDay <= 28, "Mustust be between 1 and 28");
        }
        if(subtype == SubType.QUARTERLY){
             require(0 < dueDay && dueDay <= 90, "Must be between 1 and 90");
        }
        if(subtype == SubType.YEARLY) {
            require(0 < dueDay && dueDay <= 365, "Must be between 1 and 365");
        }

        //TODO: might want to set a token minimum

        //creates subscription
        Subscription memory subscription = setSubscription(amount,token, description, subtype, dueDay);

        subscriptionMap[uint(subtype)][dueDay].push() = subscription;
 
         //creates subscription index
        //SubIndex memory subindex = SubIndex(subscription.id, subscription.dueDay, subscription.subType);

        //adds it to account
        addAccountSubscription(SubIndex(subscription.id, subscription.dueDay, subscription.subType, Status.ACTIVE), true);
        //adds provider to map
        //providerMap[subscription.id] = msg.sender;

    }

    //TODO:
    //Might want to require unlimited allowance for subscriptions
    //TODO: probably need to require unlimited allowance for provider account so fees can be drawn
    //this is necessary due to the need for charging for fails

    //completes money transfer for subscribers
    function remit() external isAdmin {

        //if gas is above max gas don't call function
        require(tx.gasprice < maxGasPrice, "Gas price too high");

        //gets current time slot based on hour
        uint40 _currentTimeSlot = unixToDays(uint40(block.timestamp));

        console.log("in");

        require(_currentTimeSlot > lastCheckedDay, "14");

        //calls time function
        Time memory time = unixToTime(block.timestamp);

        uint remitCounter;

        //gets subscriptions from mappings
       
        //loops through types
        for(uint s = 0; s <= 3; s++) {

            uint16 timeTrigger;
            if(s == uint(SubType.WEEKLY)){
                timeTrigger = time.weekDay;
            } 
            if(s == uint(SubType.MONTHLY)) {
                timeTrigger = time.day;
            } 
            if(s == uint(SubType.QUARTERLY)) {
                timeTrigger = time.quarterDay;
            } 
            if(s == uint(SubType.YEARLY)) {
                timeTrigger = time.yearDay;
            }

            uint length = subscriptionMap[s][timeTrigger].length;
            
            //loops through subscriptions
            for(uint i; i < length; i++) {

                //checks if cancelled
                if(!subscriptionMap[s][timeTrigger][i].cancelled) {

                    bytes32 id = subscriptionMap[s][timeTrigger][i].id;
                    address token = subscriptionMap[s][timeTrigger][i].token;
                    uint amount = subscriptionMap[s][timeTrigger][i].amount;
                    address provider = subscriptionMap[s][timeTrigger][i].provider;

                    //calculates fee balance
                    //&&
                   uint subFee = (amount * fee / 10000) - amount;
                   uint totalFee;
                   //&&
                   //uint remitAmount = amount - subFee;
                   //uint feeRemit = (amount - ((amount * fee / 10000) - amount)) * length;

                    //loops through subscribers
                    for(uint j; j < subscribersMap[id].length; j++) {

                        //checks for max remit and returns false if limit hit
                        if(remitCounter == maxRemits) {
                            pageStart = PageStart(id, j);
                            pageGo = false;
                            //charges total fee to provider for batch
                            if(ERC20Permit(token).allowance(provider, address(this)) >= totalFee
                            && 
                            ERC20Permit(token).balanceOf(provider) < totalFee) {
                                require(ERC20Permit(token).transferFrom(provider, msg.sender, totalFee));
                            }   
                            console.log("out");
                            emit RemitLog(uint40(block.timestamp), lastCheckedDay, msg.sender, false);
                            return;
                        }


                        if(id == pageStart.id && j == pageStart.subsriberIndex) {
                            pageGo = true;
                        } 

                        //if remits are less than max remits
                        if(pageStart.id == 0 || pageGo == true) {
                            
                            //checks for failure (balance and unlimited allowance)
                            address subscriber = subscribersMap[id][j];

                            //check if there is enough allowance and balance
                            if(ERC20Permit(token).allowance(subscriber, address(this)) >= amount
                            && 
                            ERC20Permit(token).balanceOf(subscriber) < amount) {
                                remitCounter++;
                                //charges fee on fails 
                                totalFee += subFee;
                                //log as failed
                                emit SubPaymentLog(id, subscriber, uint40(block.timestamp), false);
                            } else {
                                remitCounter++;
                                //adds fee
                                totalFee += subFee;
                                //&&
                                //require(ERC20Permit(token).transferFrom(subscriber, msg.sender, subFee));

                                //log as succeeded
                                emit SubPaymentLog(id, subscriber, uint40(block.timestamp), true);

                                //remits to provider
                                //&&
                                //require(ERC20Permit(token).transferFrom(subscriber, subscriptionMap[s][timeTrigger][i].provider, remitAmount));
                               console.log(remitCounter);
                               require(ERC20Permit(token).transferFrom(subscriber, provider, amount));
                            }
                            //charges provider on last subscriber in list
                            if(j == (subscribersMap[id].length - 1)) {
                                if(ERC20Permit(token).allowance(provider, address(this)) >= totalFee
                                && 
                                ERC20Permit(token).balanceOf(provider) < totalFee) {
                                    require(ERC20Permit(token).transferFrom(provider, msg.sender, totalFee));
                                }   
                            }
                        }
                    }
                }
            }
        }
        
        //resets pagination variables
        delete pageStart;
        pageGo = false;
        //updates lastCheckedTimeSlot
        console.log("movetime");
         emit RemitLog(uint40(block.timestamp), lastCheckedDay, msg.sender, true);
        lastCheckedDay = _currentTimeSlot;
        console.log("out");
        return;
    }
}