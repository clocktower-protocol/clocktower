// SPDX-License-Identifier: BUSL-1.1
//Copyright Hugo Marx 2023
//Written by Hugo Marx
pragma solidity ^0.8.21;
import "hardhat/console.sol";

interface ERC20{
  function transferFrom(address from, address to, uint value) external returns (bool);
  function balanceOf(address tokenOwner) external returns (uint);
  function approve(address spender, uint tokens) external returns (bool);
  function transfer(address to, uint value) external returns (bool);
  function allowance(address owner, address spender) external returns (uint);
} 

contract ClockTowerSubscribe {

      /*
    //Require error codes
    0 = Subscriber cannot be provider
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
    16 = Must have admin privileges
    17 = Token balance insufficient
    18 = Must be provider of subscription
    19 = Subscriber not subscribed
    20 = Either token allowance or balance insufficient
    21 = Problem sending refund
    22 = Problem sending fees
    23 = Only provider can cancel subscription
    24 = Gas price too high
    25 = String must be <= 32 bytes
    26 = Must be between 1 and 7
    27 = Must be between 1 and 28
    28 = Must be between 1 and 90
    29 = Must be between 1 and 365
    30 = Amount below token minimum
    */

    //10000 = No fee, 10100 = 1%, 10001 = 0.01%
    //If caller fee is above 8.33% because then as second feefill would happen on annual subs
    uint public callerFee;

    //0.01 eth in wei
    uint public systemFee;

    //maximum remits per transaction
    uint public maxRemits;
    //index if transaction pagination needed due to remit amount being larger than block
    PageStart pageStart;

    mapping (address => ApprovedToken) public approvedERC20;

    // uint pageCount;
    bool pageGo;

    //variable for last checked by day
    uint40 public nextUncheckedDay;

    //admin address
    address payable admin;

    //external callers
    bool allowExternalCallers;

    //system fee turned on
    bool allowSystemFee;

    enum Frequency {
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

    /*
    enum SubEvent {
        PAID,
        FAILED,
        SUBSCRIBED, 
        UNSUBSCRIBED,
        FEEFILL, 
        REFUND
    }

    enum ProvEvent {
        CREATE,
        CANCEL,
        PAID,
        FAILED, 
        REFUND
    }
    */

    //!!
    enum SubscriptEvent {
        CREATE,
        CANCEL,
        PROVPAID,
        FAILED, 
        PROVREFUND,
        SUBPAID,
        SUBSCRIBED, 
        UNSUBSCRIBED,
        FEEFILL, 
        SUBREFUND
    }

    //acount struct
    struct Account {
        address accountAddress;
        bool exists;
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
        Frequency frequency;
        uint16 dueDay;
       // string description;
    }

    //struct of Subscription indexes
    struct SubIndex {
        bytes32 id;
        uint16 dueDay;
        Frequency frequency;
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
        uint totalSubscribers;
    }

    //Subscriber struct for views
    struct SubscriberView {
        address subscriber;
        uint feeBalance;
    }

    //struct of time return values
    struct Time {
        uint16 dayOfMonth;
        uint16 weekDay;
        uint16 quarterDay;
        uint16 yearDay;
        uint16 year;
        uint16 month;
    }

    //struct for fee estimates
    struct FeeEstimate {
        uint fee;
        address token;
    }

    //approved ERC20 struct
    struct ApprovedToken {
        address tokenAddress;
        uint minimum;
        bool exists;
    }

    struct Details {
        string url;
        string description;
    }

    struct ProviderDetails {
        string description;
        string company;
        string url;
        string domain;
        string email;
        string misc;
    }

    //Events-------------------------------------
    /*
    event SubscriberLog(
        bytes32 indexed id,
        address indexed subscriber,
        address provider,
        uint40 timestamp,
        uint amount,
        address token,
        SubEvent indexed subEvent
    );
    */

    event CallerLog(
        uint40 timestamp,
        uint40 checkedDay,
        address indexed caller,
        bool isFinished
    );

    /*
    event ProviderLog(
        bytes32 indexed id,
        address indexed provider,
        uint40 timestamp,
        uint amount,
        address token,
        ProvEvent indexed provEvent
    );
    */

    //!!
    event SubLog(
        bytes32 indexed id,
        address indexed provider,
        address indexed subscriber,
        uint40 timestamp,
        uint amount,
        address token,
        SubscriptEvent subScriptEvent
    );

    event DetailsLog(
        bytes32 indexed id,
        address indexed provider,
        uint40 indexed timestamp,
        string url,
        string description
    );

    event ProvDetailsLog(
        address indexed provider,
        uint40 indexed timestamp,
        string description,
        string company, 
        string url, 
        string domain,
        string email, 
        string misc
    );

   constructor() payable {
        
    //10000 = No fee, 10100 = 1%, 10001 = 0.01%
    callerFee = 10200;

    //0.01 eth in wei
    systemFee = 10000000000000000;

    //maximum remits per transaction
    maxRemits = 5;

    allowSystemFee = false;

    //variable for last checked by day
    nextUncheckedDay = (unixToDays(uint40(block.timestamp)) - 2);

    //admin addresses
    admin = payable(0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266);

    }
    //-------------------------------------------

    //--------------Account Mappings-------------

    //Account map
    mapping(address => Account) private accountMap;
     //creates lookup table for mapping
    address[] public accountLookup;

    //fee balance
    mapping(bytes32 => mapping(address => uint)) public feeBalance;

    //---------------------------------------------

    //--------------Subscription mappings------------ 

    //Subscription master map keyed on type
    mapping(uint => mapping(uint16 => Subscription[])) subscriptionMap;

    //map of subscribers
    mapping(bytes32 => address[]) subscribersMap;

    //--------------------------------------------

    //functions for receiving ether
    receive() external payable{
        //emit ReceiveETH(msg.sender, msg.value);
    }
    fallback() external payable{
        //emit UnknownFunction("Unknown function");
    }

    //ADMIN METHODS*************************************

    function adminRequire() private view {
        require(msg.sender == admin, "16");
    }
    
    
    //checks if user is admin
    modifier isAdmin() {
        adminRequire();
        _;
    }

    //Create skim method to get accumulated systemFees
    function collectFees() isAdmin external {

        if(address(this).balance > 5000) {
            admin.transfer(address(this).balance - 5000);
        }
    }   

    function changeAdmin(address payable newAddress) isAdmin external {
       // require((msg.sender == newAddress) && (newAddress != address(0)));
       require((newAddress != address(0)));

        admin = newAddress;
    }

    //allow external callers
    function setExternalCallers(bool status) isAdmin external {
        allowExternalCallers = status;
    }

    //allow system fee
    function systemFeeActivate(bool status) isAdmin external {
        allowSystemFee = status;
    }

    function addERC20Contract(address erc20Contract, uint minimum) isAdmin external {

        require(erc20Contract != address(0));
        require(!erc20IsApproved(erc20Contract), "1");

        approvedERC20[erc20Contract] = ApprovedToken(erc20Contract, minimum, true);
    }

    function removeERC20Contract(address erc20Contract) isAdmin external {
        require(erc20Contract != address(0));
        require(erc20IsApproved(erc20Contract), "2");

        delete approvedERC20[erc20Contract];
    }

    //change fee
    function changeCallerFee(uint _fee) isAdmin external {
        callerFee = _fee;
    }

    //change fixed fee
    function changeSystemFee(uint _fixed_fee) isAdmin external {
        systemFee = _fixed_fee;
    }

    //change max remits
    function changeMaxRemits(uint _maxRemits) isAdmin external {
        maxRemits = _maxRemits;
    }

    //-------------------------------------------------------

     //TIME FUNCTIONS-----------------------------------
    function unixToTime(uint unix) internal pure returns (Time memory time) {
       
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
        time.dayOfMonth = day;
        time.yearDay = yearDay;
        time.year = uint16(uintyear);
        time.month = uint16(month);
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

    //converts unixTime to days
    function unixToDays(uint40 unixTime) internal pure returns(uint40 dayCount) {
        dayCount = unixTime/86400;
    }

    //prorates weekday
    function prorate(uint unixTime, uint40 dueDay, uint fee, uint8 frequency) internal pure returns (uint)  {
        Time memory time = unixToTime(unixTime);
        uint currentDay;
        uint max;
        uint lastDayOfMonth;
        
        //sets maximum range day amount
        if(frequency == 0) {
            currentDay = time.weekDay;
            max = 7;
        //monthly
        } else if (frequency == 1){
            //calculates maximum days in current month
            lastDayOfMonth = getDaysInMonth(time.year, time.month);
            currentDay = time.dayOfMonth;
            max = lastDayOfMonth;
        //quarterly and yearly
        } else if (frequency == 2) {
            currentDay = getdayOfQuarter(time.yearDay, time.year);
            max = 90;
        //yearly
        } else if (frequency == 3) {
            currentDay = time.yearDay;
            max = 365;
        }

        //monthly
        if(frequency == 1) {
            uint dailyFee = (fee * 12 / 365);
            if(dueDay != currentDay && currentDay > dueDay){
                    //dates split months
                    fee = (dailyFee * (max - (currentDay - dueDay)));
            } else if (dueDay != currentDay && currentDay < dueDay) {
                    //both dates are in the same month
                    fee = (dailyFee * (dueDay - currentDay));
            }
        }
        //weekly quarterly and yearly
        else if(frequency == 0 || frequency == 2 || frequency == 3) {
            if(dueDay != currentDay && currentDay > dueDay){
                    fee = (fee / max) * (max - (currentDay - dueDay));
            } else if (dueDay != currentDay && currentDay < dueDay) {
                    fee = (fee / max) * (dueDay - currentDay);
            }
        }  
       
        return fee;
    }


    //VIEW FUNCTIONS ----------------------------------------

    //subscriptions by account
    function getAccountSubscriptions(bool bySubscriber, address account) external view returns (SubView[] memory) {

        SubIndex[] memory indexes;
        //gets account indexes
        if(bySubscriber) {
            //indexes = accountMap[msg.sender].subscriptions;
            indexes = accountMap[account].subscriptions;
        } else {
           // indexes = accountMap[msg.sender].provSubs;
           indexes = accountMap[account].provSubs;
        }

        SubView[] memory subViews = new SubView[](indexes.length);

        //loops through account index and fetchs subscriptions, status and logs
        for(uint i; i < indexes.length; i++){
            subViews[i].subscription = getSubByIndex(indexes[i].id, indexes[i].frequency, indexes[i].dueDay);
            subViews[i].status = indexes[i].status;  
            subViews[i].totalSubscribers = subscribersMap[subViews[i].subscription.id].length; 
        }
        
        return subViews;
    }

    
    //returns total amount of subscribers
    function getTotalSubscribers() external view returns (uint) {
        return accountLookup.length;
    }
    

    //get account
    function getAccount(address account) public view returns (Account memory) {
        return accountMap[account];
    }
    
    //gets subscribers by subscription id
    function getSubscribersById(bytes32 id) external view returns (SubscriberView[] memory) {

        address[] memory scriberArray = new address[](subscribersMap[id].length);

        scriberArray = subscribersMap[id];

        SubscriberView[] memory scriberViews = new SubscriberView[](subscribersMap[id].length);

        for(uint i; i < scriberArray.length; i++) {

            uint feeBalanceTemp = feeBalance[id][scriberArray[i]];
            SubscriberView memory scriberView = SubscriberView(scriberArray[i], feeBalanceTemp);
            scriberViews[i] = scriberView;
        }

        return scriberViews;
    }
    
    //fetches subscription from day maps by id
    function getSubByIndex(bytes32 id, Frequency frequency, uint16 dueDay) view public returns(Subscription memory subscription){

          Subscription[] memory subList = subscriptionMap[uint(frequency)][dueDay];

        //searchs for subscription in day map
            for(uint j; j < subList.length; j++) {
                if(subList[j].id == id) {
                        subscription = subList[j];
                }
            }
          return subscription;
    }
    
    //function that sends back array of fees per subscription
    function feeEstimate() external view returns(FeeEstimate[] memory) {
        
        //gets current time slot based on day
        uint40 _currentTimeSlot = unixToDays(uint40(block.timestamp));

        require(_currentTimeSlot > nextUncheckedDay, "14");

        //calls time function
        Time memory time = unixToTime(block.timestamp);

        uint remitCounter;
        uint subCounter;

        FeeEstimate[] memory feeArray = new FeeEstimate[](maxRemits);
    
        //gets subscriptions from mappings
       
        //loops through types
        for(uint s; s <= 3; s++) {

            uint16 timeTrigger;
            if(s == uint(Frequency.WEEKLY)){
                timeTrigger = time.weekDay;
            } 
            if(s == uint(Frequency.MONTHLY)) {
                timeTrigger = time.dayOfMonth;
            } 
            if(s == uint(Frequency.QUARTERLY)) {
                timeTrigger = time.quarterDay;
            } 
            if(s == uint(Frequency.YEARLY)) {
                timeTrigger = time.yearDay;
            }
            
            //loops through subscriptions
            for(uint i; i < subscriptionMap[s][timeTrigger].length; i++) {

                //checks if cancelled
                if(!subscriptionMap[s][timeTrigger][i].cancelled) {

                    bytes32 id = subscriptionMap[s][timeTrigger][i].id;
                    address token = subscriptionMap[s][timeTrigger][i].token;
                    uint amount = subscriptionMap[s][timeTrigger][i].amount;

                    FeeEstimate memory feeEst;
              
                    //calculates fee balance
                    uint subFee = (amount * callerFee / 10000) - amount;
                    uint totalFee;
                 
                    //loops through subscribers
                    for(uint j; j < subscribersMap[id].length; j++) {

                        //checks for max remit and returns false if limit hit
                        if(remitCounter == maxRemits) {
                       
                            return feeArray;
                        }

                        //if remits are less than max remits
                        if(pageStart.id == 0 || pageGo == true) {
                        
                            remitCounter++;
                                
                            //adds fee 
                            totalFee += subFee;
                          
                           
                            feeEst = FeeEstimate(totalFee, token);
                            feeArray[subCounter] = feeEst;
                            subCounter++;
                        }
                    }
                }
            }
        }

        //strips out unused array elements
        uint totalSubs;
        for(uint j; j < feeArray.length; j++) {
            if(feeArray[j].token == address(0)){
                totalSubs = j;
                break;
            }
        }
        FeeEstimate[] memory feeArray2 = new FeeEstimate[](totalSubs);

        for(uint k; k < totalSubs; k++) {
            feeArray2[k] = feeArray[k];
        }
        
        return feeArray2;
    }
    
    
   
    //PRIVATE FUNCTIONS----------------------------------------------
    function userNotZero() view private {
        require(msg.sender != address(0), "3");
    }

    function erc20IsApproved(address erc20Contract) private view returns(bool result) {
       return approvedERC20[erc20Contract].exists ? true:false;
    }

    //sets Subscription
    function setSubscription(uint amount, address token, Frequency frequency, uint16 dueDay) private view returns (Subscription memory subscription){

        //creates id hash
        bytes32 id = keccak256(abi.encodePacked(msg.sender, block.prevrandao, block.timestamp));

        subscription = Subscription(id, amount, msg.sender, token, true, false, frequency, dueDay);
    }
    
    //checks subscription exists
    function subExists(bytes32 id, uint16 dueDay, Frequency frequency, Status status) private view returns(bool) {
        
        //check subscription exists
        SubIndex memory index = SubIndex(id, dueDay, frequency, status);

        Subscription memory memSubscription = getSubByIndex(index.id, index.frequency, index.dueDay);

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

        uint length = subscribers.length;
        for(uint i; i < length; i++) {
            if(subscribers[i] == account) {
                index2 = i;
                delete subscribers[i];
                break; 
            }
        }

        subscribers[index2] = subscribers[subscribers.length - 1];
        subscribers.pop();
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
    
    //allows subscriber to join a subscription
    function subscribe(Subscription calldata subscription) external payable {

        //cannot be sent from zero address
        userNotZero();

        //check if there is enough allowance
        require(ERC20(subscription.token).allowance(msg.sender, address(this)) >= subscription.amount
                &&
                ERC20(subscription.token).balanceOf(msg.sender) >= subscription.amount, "20");
    
        //cant subscribe to subscription you own
        require(msg.sender != subscription.provider, "0");

        require(subExists(subscription.id, subscription.dueDay, subscription.frequency, Status.ACTIVE), "7");

        //adds to subscriber map
        subscribersMap[subscription.id].push() = msg.sender;

        //adds it to account
        addAccountSubscription(SubIndex(subscription.id, subscription.dueDay, subscription.frequency, Status.ACTIVE), false);
        
        uint fee = subscription.amount;
        uint multiple = 1;

        //prorates fee amount
        
        if(subscription.frequency == Frequency.MONTHLY || subscription.frequency == Frequency.WEEKLY){
            fee = prorate(block.timestamp, subscription.dueDay, fee, uint8(subscription.frequency));
        } 
        else if(subscription.frequency == Frequency.QUARTERLY) {
            fee = prorate(block.timestamp, subscription.dueDay, fee, uint8(subscription.frequency));
            fee /= 3;
            multiple = 2;
        }
        else if(subscription.frequency == Frequency.YEARLY) {
            fee = prorate(block.timestamp, subscription.dueDay, fee, uint8(subscription.frequency));
            fee /= 12;
            multiple = 11;
        } 
        
        //pays first subscription to fee balance
        feeBalance[subscription.id][msg.sender] += fee;

        //emit subscription to log
        //emit SubscriberLog(subscription.id, msg.sender, subscription.provider, uint40(block.timestamp), subscription.amount, subscription.token, SubEvent.SUBSCRIBED);
        //emit SubscriberLog(subscription.id, msg.sender, subscription.provider, uint40(block.timestamp), fee, subscription.token, SubEvent.FEEFILL);
        emit SubLog(subscription.id, subscription.provider, msg.sender, uint40(block.timestamp), subscription.amount, subscription.token, SubscriptEvent.SUBSCRIBED);
        emit SubLog(subscription.id, subscription.provider, msg.sender, uint40(block.timestamp), fee, subscription.token, SubscriptEvent.FEEFILL);

        //funds cost with fee balance
        require(ERC20(subscription.token).transferFrom(msg.sender, address(this), fee));
        if(subscription.frequency == Frequency.QUARTERLY || subscription.frequency == Frequency.YEARLY) {
            //funds the remainder to the provider
            require(ERC20(subscription.token).transferFrom(msg.sender, subscription.provider, fee * multiple));
        }
    }
    
    function unsubscribe(Subscription memory subscription) external payable {

        //cannot be sent from zero address
        userNotZero();

        //sets account subscription status as unsubscribed
        SubIndex[] memory indexes = new SubIndex[](accountMap[msg.sender].subscriptions.length);
        indexes = accountMap[msg.sender].subscriptions;
        
        uint length = accountMap[msg.sender].subscriptions.length;
        for(uint j; j < length; j++){
            if(indexes[j].id == subscription.id) {
                accountMap[msg.sender].subscriptions[j].status = Status.UNSUBSCRIBED;
            }
        }

        deleteSubFromSubscription(subscription.id, msg.sender);

        //emit unsubscribe to log
        //emit SubscriberLog(subscription.id, msg.sender, subscription.provider, uint40(block.timestamp), subscription.amount, subscription.token, SubEvent.UNSUBSCRIBED);
        emit SubLog(subscription.id, subscription.provider, msg.sender, uint40(block.timestamp), subscription.amount, subscription.token, SubscriptEvent.UNSUBSCRIBED);

        //refunds fees to provider
    
        uint balance = feeBalance[subscription.id][msg.sender];

        //zeros out fee balance
        delete feeBalance[subscription.id][msg.sender];

        //emit ProviderLog(subscription.id, subscription.provider, uint40(block.timestamp), balance, subscription.token, ProvEvent.REFUND);
        emit SubLog(subscription.id, subscription.provider, msg.sender, uint40(block.timestamp), balance, subscription.token, SubscriptEvent.PROVREFUND);

        //Refunds fee balance
        require(ERC20(subscription.token).transfer(subscription.provider, balance), "21");
        
    }

     //lets provider unsubscribe subscriber
    function unsubscribeByProvider(Subscription memory subscription, address subscriber) external {

        userNotZero();

        //checks mgs.sender is provider of sub
        SubIndex[] memory indexes = accountMap[msg.sender].provSubs;
        bool isProvider;
        for(uint i; i < indexes.length; i++) {
            if(indexes[i].id == subscription.id) {
                isProvider = true;
            }
        }
        require(isProvider, "18");
        
        //checks subscriber is subscribed if so marks them as unsubscribed
        address[] memory subscribers = subscribersMap[subscription.id];
        bool isSubscribed;
        for(uint i; i < subscribers.length; i++) {
            if(subscribers[i] == subscriber){
                isSubscribed = true;
                accountMap[subscriber].subscriptions[i].status = Status.UNSUBSCRIBED;
            }
        }
        require(isSubscribed, "19");

        deleteSubFromSubscription(subscription.id, subscriber);

        //emit unsubscribe to log
        //emit SubscriberLog(subscription.id, subscriber, subscription.provider, uint40(block.timestamp), subscription.amount, subscription.token, SubEvent.UNSUBSCRIBED);
        emit SubLog(subscription.id, subscription.provider, subscriber, uint40(block.timestamp), subscription.amount, subscription.token, SubscriptEvent.UNSUBSCRIBED);

        //refunds fees to subscriber
        uint balance = feeBalance[subscription.id][subscriber];

        //zeros out fee balance
        delete feeBalance[subscription.id][subscriber];

        //emit SubscriberLog(subscription.id, subscriber, subscription.provider, uint40(block.timestamp), balance, subscription.token, SubEvent.REFUND);
        emit SubLog(subscription.id, subscription.provider, subscriber, uint40(block.timestamp), balance, subscription.token, SubscriptEvent.SUBREFUND);

        //Refunds fee balance
        require(ERC20(subscription.token).transfer(subscriber, balance), "21");
        
    }
        
    //Allows provider to cancel subscription
    function cancelSubscription(Subscription calldata subscription) external {
        userNotZero();

        //checks subscription exists
        require(subExists(subscription.id, subscription.dueDay, subscription.frequency, Status.ACTIVE), "7");

        //require user be provider
        require(msg.sender == subscription.provider, "23");

        SubIndex[] memory provIndex = accountMap[msg.sender].provSubs;

        uint length = accountMap[msg.sender].provSubs.length;

        //marks provider index in provider account as cancelled
        for(uint j; j < length; j++) {
            if(provIndex[j].id == subscription.id) {
                accountMap[msg.sender].provSubs[j].status = Status.CANCELLED;
            }
        }

        //gets list of subscribers and deletes subscriber list
        address[] memory subscribers = subscribersMap[subscription.id];

        for(uint i; i < subscribers.length; i++) {

            //refunds feeBalances to subscribers
            
            uint feeBal = feeBalance[subscription.id][subscribers[i]];

            //emit SubscriberLog(subscription.id, subscribers[i], subscription.provider, uint40(block.timestamp), feeBal, subscription.token, SubEvent.REFUND); 
            emit SubLog(subscription.id, subscription.provider, subscribers[i], uint40(block.timestamp), feeBal, subscription.token, SubscriptEvent.SUBREFUND);  

            //zeros out fee balance
            delete feeBalance[subscription.id][subscribers[i]];

            //refunds fee balance
            require(ERC20(subscription.token).transfer(subscribers[i], feeBal), "21");
            
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
        Subscription[] memory subscriptions = subscriptionMap[uint(subscription.frequency)][subscription.dueDay];
        for(uint i; i < subscriptions.length; i++) {
            if(subscriptions[i].id == subscription.id) {
               subscriptionMap[uint(subscription.frequency)][subscription.dueDay][i].cancelled = true;
            }
        }

        //emit ProviderLog(subscription.id, msg.sender, uint40(block.timestamp), 0, subscription.token, ProvEvent.CANCEL);
        emit SubLog(subscription.id, msg.sender, address(0), uint40(block.timestamp), 0, subscription.token, SubscriptEvent.CANCEL);

    } 
    
    //allows provider user to create a subscription
    function createSubscription(uint amount, address token, Details calldata details, Frequency frequency, uint16 dueDay) external payable {
        
        //cannot be sent from zero address
        userNotZero();

        //cannot be ETH or zero address
        require(token != address(0), "8");

        //require sent ETH to be higher than fixed token fee
        if(allowSystemFee) {
            require(systemFee <= msg.value, "5");
        }
        //check if token is on approved list
        require(erc20IsApproved(token),"9");

        //description must be 32 bytes or less
        //require(bytes(description).length <= 32, "25");

        //validates dueDay
        if(frequency == Frequency.WEEKLY) {
            require(0 < dueDay && dueDay <= 7, "26");
        }
        if(frequency == Frequency.MONTHLY) {
            require(0 < dueDay && dueDay <= 28, "27");
        }
        if(frequency == Frequency.QUARTERLY){
             require(0 < dueDay && dueDay <= 90, "28");
        }
        if(frequency == Frequency.YEARLY) {
            require(0 < dueDay && dueDay <= 365, "29");
        }

        //sets a token minimum
        require(amount >= approvedERC20[token].minimum, "30");

        //creates subscription
        Subscription memory subscription = setSubscription(amount,token, frequency, dueDay);

        subscriptionMap[uint(frequency)][dueDay].push() = subscription;

        //adds it to account
        addAccountSubscription(SubIndex(subscription.id, subscription.dueDay, subscription.frequency, Status.ACTIVE), true);

        emit DetailsLog(subscription.id, msg.sender, uint40(block.timestamp), details.url, details.description);

        //emit ProviderLog(subscription.id, msg.sender, uint40(block.timestamp), 0, subscription.token, ProvEvent.CREATE);
        emit SubLog(subscription.id, msg.sender, address(0), uint40(block.timestamp), amount, subscription.token, SubscriptEvent.CREATE);
    }

    function editDetails(Details calldata details, bytes32 id) external {
        
        //checks if msg.sender is provider
        Account memory returnedAccount = getAccount(msg.sender);

       //addmod bool result;

        if(returnedAccount.exists) {
            //checks if subscription is part of account
            for(uint i; i < returnedAccount.provSubs.length; i++) {
                if(returnedAccount.provSubs[i].id == id) {
                    //result = true;
                    emit DetailsLog(id, msg.sender, uint40(block.timestamp), details.url, details.description);
                }
            }
        }
    }

    function editProvDetails(ProviderDetails memory details) external {
        emit ProvDetailsLog(msg.sender, uint40(block.timestamp), details.description, details.company, details.url, details.domain, details.email, details.misc);
    }

    //REQUIRES SUBSCRIBERS TO HAVE ALLOWANCES SET

    //completes money transfer for subscribers
    function remit() payable public {

        if(!allowExternalCallers) {
            adminRequire();
        }

        //require sent ETH to be higher than fixed token fee
        if(allowSystemFee) {
            require(systemFee <= msg.value, "5");
        }

        //gets current time slot based on day
        uint40 currentDay = unixToDays(uint40(block.timestamp));

        require(currentDay >= nextUncheckedDay, "14");

        bool isEmptyDay = true;

        Time memory time;

        //checks if day is current day or a past date 
        if(currentDay != nextUncheckedDay) {
           time = unixToTime(nextUncheckedDay * 86400);
        }  else {
            time = unixToTime(block.timestamp);
        }

        uint remitCounter;

        //gets subscriptions from mappings
       
        //loops through types
        for(uint f; f <= 3; f++) {

            uint16 timeTrigger;
            if(f == uint(Frequency.WEEKLY)){
                timeTrigger = time.weekDay;
            } 
            if(f == uint(Frequency.MONTHLY)) {
                timeTrigger = time.dayOfMonth;
            } 
            if(f == uint(Frequency.QUARTERLY)) {
                timeTrigger = time.quarterDay;
            } 
            if(f == uint(Frequency.YEARLY)) {
                timeTrigger = time.yearDay;
            }

            uint length = subscriptionMap[f][timeTrigger].length;
            
            //loops through subscriptions
            for(uint s; s < length; s++) {

                //Marks day as not empty
                isEmptyDay = false;

                //checks if cancelled
                if(!subscriptionMap[f][timeTrigger][s].cancelled) {

                    bytes32 id = subscriptionMap[f][timeTrigger][s].id;
                    address token = subscriptionMap[f][timeTrigger][s].token;
                    uint amount = subscriptionMap[f][timeTrigger][s].amount;
                    address provider = subscriptionMap[f][timeTrigger][s].provider;

                    //calculates fee balance
                    uint subFee = (amount * callerFee / 10000) - amount;
                    uint totalFee;

                    uint sublength = subscribersMap[id].length;
                    uint lastSub;
                    
                    //makes sure on an empty subscription lastSub doesn't underflow
                    if(sublength > 0) {
                        lastSub = sublength - 1;
                    }
                    
                    //loops through subscribers
                    for(uint u; u < sublength; u++) {

                        //checks for max remit and returns false if limit hit
                        if(remitCounter == maxRemits) {
                            pageStart = PageStart(id, u);
                            pageGo = false;
                            
                            //sends fees to caller
                            require(ERC20(token).transfer(msg.sender, totalFee), "22");
                            
                            emit CallerLog(uint40(block.timestamp), nextUncheckedDay, msg.sender, false);
                            return;
                        }

                        //if this is the subscription and subscriber the page starts on
                        if(id == pageStart.id && u == pageStart.subsriberIndex) {
                            pageGo = true;
                        } 

                        //if remits are less than max remits or beginning of next page
                        if(pageStart.id == 0 || pageGo == true) {
                            
                            //checks for failure (balance and unlimited allowance)
                            address subscriber = subscribersMap[id][u];

                            //check if there is enough allowance and balance
                            if(ERC20(token).allowance(subscriber, address(this)) >= amount
                            && 
                            ERC20(token).balanceOf(subscriber) > amount) {
                                //SUCCESS
                                remitCounter++;

                                //checks feeBalance. If positive it decreases balance. 
                                //If fee balance < fee amount it sends subscription amount to contract as fee payment.
                                if(feeBalance[id][subscriber] > subFee) {

                                    //accounts for fee
                                    totalFee += subFee;
                                    feeBalance[id][subscriber] -= subFee;
                               
                                    //log as succeeded
                                    //emit SubscriberLog(id, subscriber, provider, uint40(block.timestamp), amount, token, SubEvent.PAID);
                                    emit SubLog(id, provider, subscriber, uint40(block.timestamp), amount, token, SubscriptEvent.SUBPAID);
                                    //emit ProviderLog(id, provider, uint40(block.timestamp), 0, token, ProvEvent.PAID);
                                    emit SubLog(id, provider, subscriber, uint40(block.timestamp), 0, token, SubscriptEvent.PROVPAID);

                                    //remits from subscriber to provider
                                    require(ERC20(token).transferFrom(subscriber, provider, amount));
                                } else {

                                    //FEEFILL

                                    //Caller gets paid remainder of feeBalance
                                    totalFee += feeBalance[id][subscriber];
                                    delete feeBalance[id][subscriber];

                                    //log as feefill
                                    //emit SubscriberLog(id, subscriber, provider, uint40(block.timestamp), amount, token, SubEvent.FEEFILL);
                                    emit SubLog(id, provider, subscriber, uint40(block.timestamp), amount, token, SubscriptEvent.FEEFILL);

                                    //adjusts feefill based on frequency
                                    
                                    //variables for feefill
                                    uint feefill = amount;
                                    uint multiple = 1;

                                    if(f == 2) {
                                        feefill /= 3;
                                        multiple = 2;
                                    }
                                    else if(f == 3) {
                                        feefill /= 12;
                                        multiple = 11;
                                    }
                                   
                                    //remits to contract to refill fee balance
                                    feeBalance[id][subscriber] += feefill;
                                    require(ERC20(token).transferFrom(subscriber, address(this), feefill));

                                    if(f == 2 || f == 3) {
                                        //funds the remainder to the provider
                                        require(ERC20(token).transferFrom(subscriber, provider, feefill * multiple));
                                    }
                                }
                            } else {
                                //FAILURE
                                //Currently refunds remainder to Provider

                                remitCounter++;
                
                                //checks if theres is enough feebalance left to pay Caller
                                if(feeBalance[id][subscriber] > subFee) {
                                
                                    //adds fee on fails
                                    totalFee += subFee;

                                    uint feeRemainder = feeBalance[id][subscriber] - subFee;

                                    //decrease feeBalance by fee and then zeros out
                                    delete feeBalance[id][subscriber];

                                    //emit ProviderLog(id, provider, uint40(block.timestamp), feeRemainder, token, ProvEvent.REFUND);
                                    emit SubLog(id, provider, subscriber, uint40(block.timestamp), feeRemainder, token, SubscriptEvent.PROVREFUND);

                                    //pays remainder to provider
                                    require(ERC20(token).transfer(provider, feeRemainder));
                                }

                                //unsubscribes on failure
                                deleteSubFromSubscription(id, subscriber);

                                //log as failed
                                //emit SubscriberLog(id, subscriber, provider, uint40(block.timestamp), amount, token, SubEvent.FAILED);
                            
                                //emit unsubscribe to log
                                //emit SubscriberLog(id, subscriber, provider, uint40(block.timestamp), amount, token, SubEvent.UNSUBSCRIBED);
                                emit SubLog(id, provider, subscriber, uint40(block.timestamp), amount, token, SubscriptEvent.UNSUBSCRIBED);

                                //log as failed
                                //emit ProviderLog(id, provider, uint40(block.timestamp), 0, token, ProvEvent.FAILED);
                                emit SubLog(id, provider, subscriber, uint40(block.timestamp), 0, token, SubscriptEvent.FAILED);
                            
                            }
                            //sends fees to caller on last subscriber in list (unless there are no subscribers)
                            if(u == lastSub && sublength > 0) {

                               //sends fees to caller
                               require(ERC20(token).transfer(msg.sender, totalFee), "22");
                            }
                        }
                    }
                }
            }
        }
        
        //resets pagination variables
        delete pageStart;
        pageGo = false;

        //Makes caller log
        emit CallerLog(uint40(block.timestamp), nextUncheckedDay, msg.sender, true);

        //updates lastCheckedTimeSlot
        nextUncheckedDay += 1;
        
        //keeps going until it hits a day with transactions
        if(isEmptyDay){
            return remit();
        }

        return;
    }
}