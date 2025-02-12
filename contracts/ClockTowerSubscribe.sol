// SPDX-License-Identifier: BUSL-1.1
// Copyright Clocktower LLC 2025
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/access/Ownable2Step.sol";

/// @title Clocktower Subscription Protocol
/// @author Hugo Marx
contract ClockTowerSubscribe is Ownable2Step {
    using SafeERC20 for IERC20;
    using EnumerableSet for EnumerableSet.AddressSet;
    using EnumerableSet for EnumerableSet.Bytes32Set;
    /** 
    @dev 
    //Require error codes
    0 = Subscriber cannot be provider
    1 = ERC20 token already added
    2 = No zero address call
    3 = Subscription doesn't exist
    4 = Token address cannot be zero
    5 = Token not approved
    6 = Time already checked
    7 = Must have admin privileges
    8 = Must be provider of subscription
    9 = Subscriber not subscribed
    10 = Either token allowance or balance insufficient
    11 = Problem sending refund
    12 = Problem sending fees
    13 = Only provider can cancel subscription
    14 = Must be between 1 and 7
    15 = Must be between 1 and 28
    16 = Must be between 1 and 90
    17 = Must be between 1 and 365
    18 = Amount below token minimum
    19 = Reentrancy attempt
    20 = Token paused
    */

    
    /// @notice Percentage of subscription given to user who calls remit as a fee
    /// @dev 10000 = No fee, 10100 = 1%, 10001 = 0.01%
    /// @dev If caller fee is above 8.33% because then a second feefill would happen on annual subs
    uint256 public callerFee;

    /// @notice Percentage of caller fee paid to system
    /// @dev 10000 = No fee, 10100 = 1%, 10001 = 0.01%
    uint256 public systemFee;

    uint256 public maxRemits;

    uint256 public cancelLimit;

    /// @dev Index if transaction pagination needed due to remit amount being larger than block
    PageStart pageStart;

    bool pageGo;

    /// @dev Boolean for reentrancy lock
    bool transient locked;

    /// @dev Variable for last checked by day
    uint40 public nextUncheckedDay;

    //address that receives the systemFee
    address sysFeeReceiver;

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

    /// @dev subscriptions array are subscriptions the user has subscribed to
    /// @dev provSubs array are subscriptions the user has created
    struct Account {
        address accountAddress;
        SubIndex[] subscriptions;
        SubIndex[] provSubs;
    }

    struct Subscription {
        bytes32 id;
        uint256 amount;
        address provider;
        address token;
        bool cancelled;
        Frequency frequency;
        uint16 dueDay;
    }

    struct SubIndex {
        bytes32 id;
        uint16 dueDay;
        Frequency frequency;
        Status status;
    }

    /// @dev Struct for pagination
    struct PageStart {
        bytes32 id;
        uint256 subscriberIndex;
        uint256 subscriptionIndex;
        uint256 frequency;
        bool initialized;
    }

    ///@dev same as subscription but adds the status for subscriber
    struct SubView {
        Subscription subscription;
        Status status;
        uint256 totalSubscribers;
    }

    ///@dev Subscriber struct for views
    struct SubscriberView {
        address subscriber;
        uint256 feeBalance;
    }

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
        uint256 fee;
        address token;
    }

    //approved ERC20 struct
    struct ApprovedToken {
        address tokenAddress;
        uint8 decimals;
        bool paused;
        uint256 minimum;
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

    struct Remit {
        bytes32 id;
        address token;
        address provider;
        uint8 decimals;
        uint256 f;
    }

    //Events-------------------------------------
    event CallerLog(
        uint40 indexed timestamp,
        uint40 indexed checkedDay,
        address indexed caller,
        bool isFinished
    );

    event SubLog(
        bytes32 indexed id,
        address indexed provider,
        address indexed subscriber,
        uint40 timestamp,
        uint256 amount,
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
        string indexed description,
        string company, 
        string url, 
        string domain,
        string email, 
        string misc
    );

    event Coordinates(
        bytes32 indexed id,
        uint256 subscriberIndex,
        uint256 subscriptionIndex,
        uint256 frequency,
        uint40 indexed nextUncheckedDay
    );

   /// @notice Contract constructor 
   /// @param callerFee_ The percentage of the subscription the Caller is paid each period
   /// @dev 10000 = No fee, 10100 = 1%, 10001 = 0.01%
   /// @dev If caller fee is above 8.33% because then a second feefill would happen on annual subs
   /// @param systemFee_ The percentage of the caller fee paid to the system
   /// @dev 10000 = No fee, 10100 = 1%, 10001 = 0.01%
   /// @param maxRemits_ The maximum remits per transaction
   /// @param allowSystemFee_ Is the system fee turned on?
   /// @param admin_ The admin address

   constructor(uint256 callerFee_, uint256 systemFee_, uint256 maxRemits_, uint256 cancelLimit_, bool allowSystemFee_, address admin_) Ownable(admin_)  {

    //checks that admin address is not zero
    require(admin_ != address(0));

    //checks that caller and system fees are within bounds
    require(callerFee_ >= 10000 && callerFee_ <= 10833);
    require(systemFee_ >= 10000 && systemFee_ <= 19999);
        
    callerFee = callerFee_;

    systemFee = systemFee_;

    cancelLimit = cancelLimit_;

    maxRemits = maxRemits_;

    allowSystemFee = allowSystemFee_;

    ///@dev variable for last checked by day
    nextUncheckedDay = (unixToDays(uint40(block.timestamp)) - 2);

    //admin = admin_;

    sysFeeReceiver = admin_;

    }
    //-------------------------------------------

    //--------------Account Mappings-------------

    mapping(address => EnumerableSet.Bytes32Set) subscribedTo;
    mapping(address => EnumerableSet.Bytes32Set) createdSubs;
    //status by user address keyed by sub id
    mapping(address => mapping(bytes32 => Status)) subStatusMap;
    mapping(address => mapping(bytes32 => Status)) provStatusMap;

    //account lookup table using enumerable set
    EnumerableSet.AddressSet accountLookup;


    //fee balance
    mapping(bytes32 => mapping(address => uint256)) public feeBalance;


    //---------------------------------------------

    //--------------Subscription mappings------------ 

    //Subscription master map keyed on frequency -> dueDay
    mapping(uint256 => mapping(uint16 => EnumerableSet.Bytes32Set)) subscriptionMap;

    //map of subscribers by subscription id
    mapping(bytes32 => EnumerableSet.AddressSet) subscribersMap2;

    //mapping of subscriptions by id
    mapping(bytes32 => Subscription) public idSubMap;

    //mapping of unsubscribed addresses per subscription
    mapping(bytes32 => EnumerableSet.AddressSet) unsubscribedMap;


    //--------------------------------------------

    //mapping for nonces
    mapping(address => uint256) nonces;

    //----------------Token mapping-----------------------

    //mappping of approved Tokens
    mapping (address => ApprovedToken) public approvedERC20;


    //ADMIN METHODS*************************************
    
    /// @notice Reentrancy Lock 
    modifier nonReentrant() {
        require(!locked, "19");
        locked = true;
        _;
        locked = false;
    }
    
    /// @notice Changes sysFeeReceiver address
    /// @param newSysFeeAddress New sysFeeReceiver address
    function changeSysFeeReceiver(address newSysFeeAddress) onlyOwner external {
       require((newSysFeeAddress != address(0)));

       //checks that address is different
       require(newSysFeeAddress != sysFeeReceiver);
         
        sysFeeReceiver = newSysFeeAddress;
    }

    /// @notice Allow system fee
    /// @param status true of false
    function systemFeeActivate(bool status) onlyOwner external {
        allowSystemFee = status;
    }

    /// @notice Add allowed ERC20 token
    /// @param erc20Contract ERC20 Contract address
    /// @param minimum Token minimum in wei
    /// @param decimals Number of token decimals
    function addERC20Contract(address erc20Contract, uint256 minimum, uint8 decimals) onlyOwner external {

        require(erc20Contract != address(0));
        require(!erc20IsApproved(erc20Contract), "1");

        approvedERC20[erc20Contract] = ApprovedToken(erc20Contract, decimals, false, minimum);
    }


    /// @notice Changes Caller fee
    /// @param _fee New Caller fee
    /// @dev 10000 = No fee, 10100 = 1%, 10001 = 0.01%
    /// @dev If caller fee is above 8.33% because then a second feefill would happen on annual subs
    function changeCallerFee(uint256 _fee) onlyOwner external {
        callerFee = _fee;
    }

    /// @notice Change system fee
    /// @dev 10000 = No fee, 10100 = 1%, 10001 = 0.01%
    /// @param _sys_fee New System fee
    function changeSystemFee(uint256 _sys_fee) onlyOwner external {
        systemFee = _sys_fee;
    }

    /// @notice Change max remits
    /// @param _maxRemits New number of max remits per transaction
    function changeMaxRemits(uint256 _maxRemits) onlyOwner external {
        maxRemits = _maxRemits;
    }

    
    /// @notice Set pageStart coordinates
    /// @param _pageStart Contains of coordinates of where next remit should start
    function setPageStart(PageStart calldata _pageStart) onlyOwner external {
        pageStart = _pageStart;
    }

    /// @notice Set next unchecked day
    /// @param _nextUncheckedDay next day to be remitted
    function setNextUncheckedDay(uint40 _nextUncheckedDay) onlyOwner external {
        nextUncheckedDay = _nextUncheckedDay;
    }

    /// @notice pause subscriptions that contain a certain token
    /// @param _tokenAddress address of token to be paused
    /// @param pause true = pause, false = unpause
    function pauseToken(address _tokenAddress, bool pause) onlyOwner external {

        //check that token is already approved
        require(approvedERC20[_tokenAddress].tokenAddress != address(0));

        //if unpausing 
        if(!pause) {
            require(approvedERC20[_tokenAddress].paused);

            approvedERC20[_tokenAddress].paused = false;
        } else {

            approvedERC20[_tokenAddress].paused = true;
        }

    }
    
    //-------------------------------------------------------

     //TIME FUNCTIONS-----------------------------------
    /// @notice Converts unix time number to Time struct
    /// @param unix Unix Epoch Time number
    /// @return time Time struct
    function unixToTime(uint256 unix) internal pure returns (Time memory time) {
       
        uint256 _days = unix/86400;
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

        uint256 uintyear = uint(_year);
        uint256 month = uint(_month);
        uint256 uintday = uint(_day);

        day = uint16(uintday);        

        uint256 dayCounter;

        //loops through months to get current day of year
        for(uint256 monthCounter = 1; monthCounter <= month; monthCounter++) {
            if(monthCounter == month) {
                dayCounter += day;
            } else {
                dayCounter += getDaysInMonth(uintyear, monthCounter);
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

    /// @notice Checks if year is a leap year
    /// @param year Year number
    /// @return  leapYear Boolean value. True if leap year false if not
    function isLeapYear(uint256 year) internal pure returns (bool leapYear) {
        leapYear = ((year % 4 == 0) && (year % 100 != 0)) || (year % 400 == 0);
    }

    /// @notice Returns number of days in month 
    /// @param year Number of year
    /// @param month Number of month. 1 - 12
    /// @dev Month range is 1 - 12
    /// @return daysInMonth Number of days in the month
    function getDaysInMonth(uint256 year, uint256 month) internal pure returns (uint256 daysInMonth) {
        if (month == 1 || month == 3 || month == 5 || month == 7 || month == 8 || month == 10 || month == 12) {
            daysInMonth = 31;
        } else if (month != 2) {
            daysInMonth = 30;
        } else {
            daysInMonth = isLeapYear(year) ? 29 : 28;
        }
    }

    /// @notice Gets numberical day of week from Unixtime number
    /// @param unixTime Unix Epoch Time number
    /// @return dayOfWeek Returns Day of Week 
    /// @dev 1 = Monday, 7 = Sunday
    function getDayOfWeek(uint256 unixTime) internal pure returns (uint16 dayOfWeek) {
        uint256 _days = unixTime / 86400;
        uint256 dayOfWeekuint = (_days + 3) % 7 + 1;
        dayOfWeek = uint16(dayOfWeekuint);

    }

    /// @notice Gets day of quarter
    /// @param yearDays Day of year
    /// @param year Number of year
    /// @return quarterDay Returns day in quarter
    function getdayOfQuarter(uint256 yearDays, uint256 year) internal pure returns (uint16 quarterDay) {
        
        uint256 leapDay;
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

    /// @notice Converts unix time to number of days past Jan 1st 1970
    /// @param unixTime Number in Unix Epoch Time
    /// @return dayCount Number of days since Jan. 1st 1970
    function unixToDays(uint40 unixTime) internal pure returns(uint40 dayCount) {
        dayCount = unixTime/86400;
    }

    /// @notice Prorates amount based on days remaining in subscription cycle
    /// @param unixTime Current time in Unix Epoch Time
    /// @param dueDay The day in the cycle the subscription is due
    /// @dev The dueDay will be within differing ranges based on frequency. 
    /// @param fee Amount to be prorated
    /// @param frequency Frequency number of cycle
    /// @dev 0 = Weekly, 1 = Monthly, 2 = Quarterly, 3 = Yearly
    /// @return Prorated amount
    function prorate(uint256 unixTime, uint40 dueDay, uint256 fee, uint8 frequency) internal pure returns (uint256)  {
        Time memory time = unixToTime(unixTime);
        uint256 currentDay;
        uint256 max;
        uint256 lastDayOfMonth;
        
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
            uint256 dailyFee = (fee * 12 / 365);
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

    /// @notice Get subscriptions by account address and type (provider or subscriber)
    /// @param bySubscriber If true then get subscriptions user is subscribed to. If false get subs user created
    /// @param account Account address 
    /// @return Returns array of subscriptions in the Subview struct form
    function getAccountSubscriptions(bool bySubscriber, address account) external view returns (SubView[] memory) {

        bytes32[] memory ids;
        if(bySubscriber) {
            ids = subscribedTo[account].values();
        } else {
           // indexes = accountMap[msg.sender].provSubs;
           ids = createdSubs[account].values();
        }

        SubView[] memory subViews = new SubView[](ids.length);

        for(uint256 i; i < ids.length; i++){

            if(bySubscriber) {
                subViews[i].status = subStatusMap[account][ids[i]];
            } else {
                 subViews[i].status = provStatusMap[account][ids[i]];
            }
            
            subViews[i].subscription = idSubMap[ids[i]];
            subViews[i].totalSubscribers = subscribersMap2[subViews[i].subscription.id].length(); 
            
        }
           
        return subViews;
    }

    /// @return Returns total amount of subscribers
    //returns total amount of subscribers
    function getTotalSubscribers() external view returns (uint256) {
       return accountLookup.length();
    }
    

    /// @notice Gets account struct by address
    /// @param account Account address
    /// @return Returns Account struct for supplied address
    function getAccount(address account) public view returns (Account memory) {
        
        uint256 subsLength = subscribedTo[account].length();
        uint256 provLength = createdSubs[account].length();

        //gets array of subs subscribed to by address
        SubIndex[] memory subsArray = new SubIndex[](subsLength);

        for(uint256 i; i < subsLength; i++) {
            bytes32 id = subscribedTo[account].at(i);

            //gets subscription details
            Subscription memory tempSub = idSubMap[id];

            //creates SubIndex
            subsArray[i] = SubIndex(id, tempSub.dueDay, tempSub.frequency, subStatusMap[account][id]);
        }

        //gets array of subs created by address
        SubIndex[] memory provArray = new SubIndex[](subsLength);

        for(uint256 i; i < provLength; i++) {
            bytes32 id = createdSubs[account].at(i);

            //gets subscription details
            Subscription memory tempSub = idSubMap[id];

            //creates SubIndex
            provArray[i] = SubIndex(id, tempSub.dueDay, tempSub.frequency, provStatusMap[account][id]);
        }

        //creates account struct
        Account memory accountStruct = Account(account, subsArray, provArray);

        return accountStruct;
    }
    
    /// @notice Gets subscribers by subscription id
    /// @param id Subscription id in bytes
    /// @return Returns array of subscribers in SubscriberView struct form
    function getSubscribersById(bytes32 id) external view returns (SubscriberView[] memory) {

        uint256 length = subscribersMap2[id].length();
       
        SubscriberView[] memory scriberViews = new SubscriberView[](length);

        for(uint256 i; i < length; i++) {

            uint256 feeBalanceTemp = feeBalance[id][subscribersMap2[id].at(i)];
            SubscriberView memory scriberView = SubscriberView(subscribersMap2[id].at(i), feeBalanceTemp);
            scriberViews[i] = scriberView;
        }

        return scriberViews;
    }
    
    /// @notice Function that sends back array of FeeEstimate structs per subscription
    /// @return Array of FeeEstimate structs
    function feeEstimate() external view returns(FeeEstimate[] memory) {
        
        //gets current time slot based on day
        uint40 _currentTimeSlot = unixToDays(uint40(block.timestamp));

        require(_currentTimeSlot > nextUncheckedDay, "6");

        //calls time function
        Time memory time = unixToTime(block.timestamp);

        uint256 remitCounter;
        uint256 subCounter;

        FeeEstimate[] memory feeArray = new FeeEstimate[](maxRemits);
    
        //gets subscriptions from mappings
       
        //loops through types
        for(uint256 s; s <= 3; s++) {

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
            for(uint256 i; i < subscriptionMap[s][timeTrigger].length(); i++) {

                //gets subscription
                Subscription memory subscription = idSubMap[subscriptionMap[s][timeTrigger].at(i)];

                //checks if cancelled
                if(!subscription.cancelled) {

                    address token = subscription.token;
                    uint256 amount = subscription.amount;

                    FeeEstimate memory feeEst;
              
                    //calculates fee balance
                    uint256 subFee = (amount * callerFee / 10000) - amount;
                    uint256 totalFee;
                 
                    //loops through subscribers
                    for(uint256 j; j < subscribersMap2[subscription.id].length(); j++) {

                        //checks for max remit and returns false if limit hit
                        if(remitCounter == maxRemits) {
                       
                            return feeArray;
                        }

                        //if remits are less than max remits
                        if(!pageStart.initialized || pageGo == true) {
                        
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
        uint256 totalSubs;
        for(uint256 j; j < feeArray.length; j++) {
            if(feeArray[j].token == address(0)){
                totalSubs = j;
                break;
            }
        }
        FeeEstimate[] memory feeArray2 = new FeeEstimate[](totalSubs);

        for(uint256 k; k < totalSubs; k++) {
            feeArray2[k] = feeArray[k];
        }
        
        return feeArray2;
    }

    
   
    //PRIVATE FUNCTIONS----------------------------------------------
    function convertAmount(uint256 amount, uint8 tokenDecimals) private pure returns (uint256) {
        uint8 standardDecimals = 18;

       
        if(tokenDecimals > standardDecimals){
            return amount * (10 ** (tokenDecimals - standardDecimals));
        } else if(tokenDecimals < standardDecimals){
            return amount / (10 ** (standardDecimals - tokenDecimals));
        } else {
            return amount;
        }

    }

    function erc20IsApproved(address erc20Contract) private view returns(bool result) {
       return approvedERC20[erc20Contract].tokenAddress != address(0);
    }

    //sets Subscription
    function setSubscription(uint256 amount, address token, Frequency frequency, uint16 dueDay) private returns (Subscription memory subscription){

        // Get the current nonce for the sender
        uint256 nonce = nonces[msg.sender];

        // Increment the nonce
        nonces[msg.sender]++;

        //creates id hash
        bytes32 id = keccak256(abi.encodePacked(msg.sender, nonce, block.timestamp));

        subscription = Subscription(id, amount, msg.sender, token, false, frequency, dueDay);
    }
    
    //checks subscription exists
    function subExists(bytes32 id) private view returns(bool) {
        
        if(idSubMap[id].provider == address(0)){
            return false;
        } else {
            return true;
        }
        
    }

    //deletes subscribers from Subscription
    function deleteSubFromSubscription(bytes32 id, address account) private {
        
        //adds unsubscribed address to set
        if(!unsubscribedMap[id].contains(account)) {
            unsubscribedMap[id].add(account);
        }
    }

    function addAccountSubscription(SubIndex memory subIndex, bool isProvider) private {
    
        //new account
        if(!accountLookup.contains(msg.sender)){
            accountLookup.add(msg.sender);
        }
        
        if(isProvider){

            createdSubs[msg.sender].add(subIndex.id);
            
            provStatusMap[msg.sender][subIndex.id] = Status.ACTIVE;

        } else {
        
            subscribedTo[msg.sender].add(subIndex.id);
            
            subStatusMap[msg.sender][subIndex.id] = Status.ACTIVE;
        }
        
    }

    //EXTERNAL FUNCTIONS----------------------------------------
    
    /// @notice Function that subscribes subscriber to subscription
    /// @param subscription Subscription struct
    /// @dev Requires ERC20 allowance to be set before function is called
    function subscribe(Subscription calldata subscription) external {

        require(subExists(subscription.id), "3");

        //checks that token is not paused
        require(!approvedERC20[subscription.token].paused, '20');

        uint256 convertedAmount = convertAmount(subscription.amount, approvedERC20[subscription.token].decimals);

        //check if there is enough allowance
        require(IERC20(subscription.token).allowance(msg.sender, address(this)) >= convertedAmount
                &&
                IERC20(subscription.token).balanceOf(msg.sender) >= convertedAmount, "10");
    
        //cant subscribe to subscription you own
        require(msg.sender != subscription.provider, "0");

        //Adds to subscriber set
        if(!subscribersMap2[subscription.id].contains(msg.sender)) {
            subscribersMap2[subscription.id].add(msg.sender);
        }

        //Removes from unsubscribed set
        if(unsubscribedMap[subscription.id].contains(msg.sender)) {
            unsubscribedMap[subscription.id].remove(msg.sender);
        }

        //adds it to account
        addAccountSubscription(SubIndex(subscription.id, subscription.dueDay, subscription.frequency, Status.ACTIVE), false);
        
        uint256 fee = subscription.amount;
        uint256 multiple = 1;

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
        emit SubLog(subscription.id, subscription.provider, msg.sender, uint40(block.timestamp), subscription.amount, subscription.token, SubscriptEvent.SUBSCRIBED);
        emit SubLog(subscription.id, subscription.provider, msg.sender, uint40(block.timestamp), fee, subscription.token, SubscriptEvent.FEEFILL);

        //funds cost with fee balance
        IERC20(subscription.token).safeTransferFrom(msg.sender, address(this), convertAmount(fee, approvedERC20[subscription.token].decimals));
        if(subscription.frequency == Frequency.QUARTERLY || subscription.frequency == Frequency.YEARLY) {
            //funds the remainder to the provider
            IERC20(subscription.token).safeTransferFrom(msg.sender, subscription.provider, convertAmount((fee * multiple), approvedERC20[subscription.token].decimals));
        }
    }
    
    /// @notice Unsubscribes account from subscription
    /// @param subscription Subscription struct 
    function unsubscribe(Subscription memory subscription) external {

        require(subExists(subscription.id), "3");
 
        subStatusMap[msg.sender][subscription.id] = Status.UNSUBSCRIBED;

        deleteSubFromSubscription(subscription.id, msg.sender);

        //emit unsubscribe to log
        emit SubLog(subscription.id, subscription.provider, msg.sender, uint40(block.timestamp), subscription.amount, subscription.token, SubscriptEvent.UNSUBSCRIBED);

        //refunds fees to provider
        uint256 balance = feeBalance[subscription.id][msg.sender];

        //zeros out fee balance
        delete feeBalance[subscription.id][msg.sender];

        emit SubLog(subscription.id, subscription.provider, msg.sender, uint40(block.timestamp), balance, subscription.token, SubscriptEvent.PROVREFUND);

        //Refunds fee balance
        IERC20(subscription.token).safeTransfer(subscription.provider, convertAmount(balance, approvedERC20[subscription.token].decimals));
        
    }

     /// @notice Allows provider to unsubscribe a subscriber by address
     /// @param subscription Subscription struct
     /// @param subscriber Subscriber address
    function unsubscribeByProvider(Subscription memory subscription, address subscriber) public {

        /*
        bool isProvider2;
        //checks msg.sender is provider of sub
        if(createdSubs[msg.sender].contains(subscription.id)){
            isProvider2 = true;
        }
        require(isProvider2, "8");
        */
        require(createdSubs[msg.sender].contains(subscription.id), "8");

        bool isSubscribed;
        
        if(subscribersMap2[subscription.id].contains(subscriber)) {
            isSubscribed = true;
            subStatusMap[subscriber][subscription.id] = Status.UNSUBSCRIBED;
        } 
        require(isSubscribed, "9");

        deleteSubFromSubscription(subscription.id, subscriber);

        //emit unsubscribe to log
        emit SubLog(subscription.id, subscription.provider, subscriber, uint40(block.timestamp), subscription.amount, subscription.token, SubscriptEvent.UNSUBSCRIBED);

        //refunds fees to subscriber
        uint256 balance = feeBalance[subscription.id][subscriber];

        //zeros out fee balance
        delete feeBalance[subscription.id][subscriber];

        emit SubLog(subscription.id, subscription.provider, subscriber, uint40(block.timestamp), balance, subscription.token, SubscriptEvent.SUBREFUND);

        //Refunds fee balance
        IERC20(subscription.token).safeTransfer(subscriber, convertAmount(balance, approvedERC20[subscription.token].decimals));
        
    }

    /// @notice Function that allows provider to unsubscribe users in batches. Should only be used when cancelling large subscriptions
    /// @dev Will cancel subscriptions up to cancel limit
    /// @param subscription Subscription struct
    function batchUnsubscribeByProvider(Subscription memory subscription) external {

        //checks provider has created this subscription
        require(createdSubs[msg.sender].contains(subscription.id), "8");

        //gets total subscribed subscribers
        uint256 remainingSubs = (subscribersMap2[subscription.id].length() - unsubscribedMap[subscription.id].length());

        //can't have zero subscribers
        require(remainingSubs > 0);

        uint256 loops;

        if(remainingSubs < cancelLimit){
            loops = remainingSubs;
        } else {
            loops = cancelLimit;
        }

        //loops through remaining subs or max amount
        for(uint256 i; i < loops; i++) {

            //gets address
            address subAddress = subscribersMap2[subscription.id].at(i);

            //unsubscribes
            unsubscribeByProvider(subscription, subAddress);
        }
    }
        
    /// @notice Function that provider uses to cancel subscription
    /// @dev Will cancel all subscriptions 
    /// @param subscription Subscription struct
    function cancelSubscription(Subscription calldata subscription) external {

        //checks subscription exists
        require(subExists(subscription.id), "3");

        //require user be provider
        require(msg.sender == subscription.provider, "13");

        require(!subscription.cancelled);

        //marks provider as cancelled
        provStatusMap[msg.sender][subscription.id] = Status.CANCELLED; 

        //gets list of subscribers and deletes subscriber list
        EnumerableSet.AddressSet storage subscribers2 = subscribersMap2[subscription.id];

        for(uint256 i; i < subscribersMap2[subscription.id].length(); i++) {

            address subscriberAddress = subscribers2.at(i);

            //refunds feeBalances to subscribers
            uint256 feeBal = feeBalance[subscription.id][subscriberAddress];

            emit SubLog(subscription.id, subscription.provider, subscriberAddress, uint40(block.timestamp), feeBal, subscription.token, SubscriptEvent.SUBREFUND);  

            //zeros out fee balance
            delete feeBalance[subscription.id][subscriberAddress];

            //refunds fee balance
            IERC20(subscription.token).safeTransfer(subscriberAddress, convertAmount(feeBal, approvedERC20[subscription.token].decimals));
            
            //sets status as cancelled
            subStatusMap[subscriberAddress][subscription.id] = Status.CANCELLED;

            //deletes subscriber list
            deleteSubFromSubscription(subscription.id, subscriberAddress);
        }

        idSubMap[subscription.id].cancelled = true;

        emit SubLog(subscription.id, msg.sender, address(0), uint40(block.timestamp), 0, subscription.token, SubscriptEvent.CANCEL);

    } 
    
    /// @notice Function that creates a subscription
    /// @param amount Amount of ERC20 tokens paid each cycle
    /// @dev In wei
    /// @dev Token amount must be above token minimum for ERC20 token
    /// @param token ERC20 token address
    /// @dev Token address must be whitelisted by admin
    /// @param details Details struct for event logs
    /// @dev Details are posted in event logs not storage
    /// @param frequency Frequency number of cycle
    /// @dev 0 = Weekly, 1 = Monthly, 2 = Quarterly, 3 = Yearly
    /// @param dueDay The day in the cycle the subscription is due
    /// @dev The dueDay will be within differing ranges based on frequency. 
    function createSubscription(uint256 amount, address token, Details calldata details, Frequency frequency, uint16 dueDay) external {

        //cannot be ETH or zero address
        require(token != address(0), "4");

        //check if token is on approved list
        require(erc20IsApproved(token),"5");

        //checks that token is not paused
        require(!approvedERC20[token].paused, '20');

        //validates dueDay
        if(frequency == Frequency.WEEKLY) {
            require(0 < dueDay && dueDay <= 7, "14");
        }
        if(frequency == Frequency.MONTHLY) {
            require(0 < dueDay && dueDay <= 28, "15");
        }
        if(frequency == Frequency.QUARTERLY){
             require(0 < dueDay && dueDay <= 90, "16");
        }
        if(frequency == Frequency.YEARLY) {
            require(0 < dueDay && dueDay <= 365, "17");
        }

        //sets a token minimum
        require(amount >= approvedERC20[token].minimum, "18");

        //creates subscription
        Subscription memory subscription = setSubscription(amount,token, frequency, dueDay);

        subscriptionMap[uint256(frequency)][dueDay].add(subscription.id);

        //adds it to account
        addAccountSubscription(SubIndex(subscription.id, subscription.dueDay, subscription.frequency, Status.ACTIVE), true);

        //adds subscription to id mapping
        idSubMap[subscription.id] = subscription;

        emit DetailsLog(subscription.id, msg.sender, uint40(block.timestamp), details.url, details.description);

        emit SubLog(subscription.id, msg.sender, address(0), uint40(block.timestamp), amount, subscription.token, SubscriptEvent.CREATE);
    }

    /// @notice Change subscription details in event logs
    /// @param details Details struct
    /// @param id Subscription id in bytes
    function editDetails(Details calldata details, bytes32 id) external {
        
        //checks if msg.sender is provider
        if(createdSubs[msg.sender].contains(id)) {
                emit DetailsLog(id, msg.sender, uint40(block.timestamp), details.url, details.description);
        }
        
    }

    /// @notice Changes Provider details in event logs
    /// @param details ProviderDetails struct
    function editProvDetails(ProviderDetails memory details) external {
        emit ProvDetailsLog(msg.sender, uint40(block.timestamp), details.description, details.company, details.url, details.domain, details.email, details.misc);
    }

    /// @notice Transfers tokens from subscribers to provider
    /// @dev Transfers the oldest outstanding transactions that are past their due date
    /// @dev If system fee is set then the chain token must also be added to the transaction
    /// @dev Each call will transmit either the total amount of current transactions due or the maxRemits whichever is smaller
    /// @dev The function will paginate so multiple calls can be made per day to clear the queue
    function remit() public nonReentrant{

        //gets current time slot based on day
        uint40 currentDay = unixToDays(uint40(block.timestamp));

        require(currentDay >= nextUncheckedDay, "6");

        bool isEmptyDay = true;

        Time memory time;

        //checks if day is current day or a past date 
        if(currentDay != nextUncheckedDay) {
           time = unixToTime(nextUncheckedDay * 86400);
        }  else {
            time = unixToTime(block.timestamp);
        }

        uint256 remitCounter;

        //gets subscriptions from mappings
       
        //loops through types
        for(uint256 f; f <= 3; f++) {

            //checks which frequency to start if paginated
           if(!pageStart.initialized || (pageStart.frequency <= f && pageStart.initialized)) {
            
                
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

                uint256 length = subscriptionMap[f][timeTrigger].length();
                
                
                //loops through subscriptions
                for(uint256 s; s < length; s++) {

                    //checks which subscription to start if paginated
                    if(!pageStart.initialized || (pageStart.subscriptionIndex <= s && pageStart.initialized)) {

                        //gets subscription
                        Subscription memory subscription = idSubMap[subscriptionMap[f][timeTrigger].at(s)];

                        //Marks day as not empty
                        isEmptyDay = false;

                        //checks if cancelled or token paused
                        if(!subscription.cancelled && !approvedERC20[subscription.token].paused) {

                             //struct created to avoid 'stack too deep' error with too many variables
                            Remit memory remitSub = Remit(subscription.id, 
                                subscription.token, 
                                subscription.provider,
                                approvedERC20[subscription.token].decimals,
                                f   
                            );
                            
                            uint256 amount = convertAmount(subscription.amount, remitSub.decimals);
                        
                            //calculates fee balance
                            uint256 subFee = (amount * callerFee / 10000) - amount;
                            uint256 totalFee;

                            uint256 sublength = subscribersMap2[remitSub.id].length();
                            uint256 lastSub;
                            
                            //makes sure on an empty subscription lastSub doesn't underflow
                            if(sublength > 0) {
                                lastSub = sublength - 1;
                            }
                            
                            //loops through subscribers
                            for(uint256 u; u < sublength; u++) {

                                //checks for max remit and returns false if limit hit
                                if(remitCounter == maxRemits) {
                                
                                    pageStart = PageStart(remitSub.id, u, s, f, true);
                                    pageGo = false;

                                    //if system fee is activated divides caller fee and remits portion to system
                                    if(allowSystemFee) {
                                        uint256 sysAmount = (totalFee * systemFee / 10000) - totalFee;
                                        totalFee -= sysAmount;
                                        //sends system fee to system
                                        IERC20(remitSub.token).safeTransfer(sysFeeReceiver, convertAmount(sysAmount, remitSub.decimals));
                                    } 
                                    
                                    //sends fees to caller
                                    IERC20(remitSub.token).safeTransfer(msg.sender, convertAmount(totalFee, remitSub.decimals));
                                    
                                    emit CallerLog(uint40(block.timestamp), nextUncheckedDay, msg.sender, false);
                                    return;
                                }

                                //if this is the subscription and subscriber the page starts on
                                if(remitSub.id == pageStart.id && u == pageStart.subscriberIndex) {
                                    pageGo = true;
                                } 

                                //if remits are less than max remits or beginning of next page
                                if(!pageStart.initialized || pageGo == true) {
                                    
                                    //checks for failure (balance and unlimited allowance)
                                    address subscriber = subscribersMap2[remitSub.id].at(u);

                                    //skips unsubscribed
                                    if(unsubscribedMap[remitSub.id].contains(subscriber)) {
                                        continue;
                                    }

                                    //check if there is enough allowance and balance
                                    if(IERC20(remitSub.token).allowance(subscriber, address(this)) >= amount
                                    && 
                                    IERC20(remitSub.token).balanceOf(subscriber) >= amount) {
                                        //SUCCESS
                                        remitCounter++;

                                        //checks feeBalance. If positive it decreases balance. 
                                        //If fee balance < fee amount it sends subscription amount to contract as fee payment.
                                        if(feeBalance[remitSub.id][subscriber] > subFee) {

                                            //accounts for fee
                                            totalFee += subFee;
                                            feeBalance[remitSub.id][subscriber] -= subFee;
                                    
                                            //log as succeeded
                                            emit SubLog(remitSub.id, remitSub.provider, subscriber, uint40(block.timestamp), amount, remitSub.token, SubscriptEvent.SUBPAID);
                                            emit SubLog(remitSub.id, remitSub.provider, subscriber, uint40(block.timestamp), 0, remitSub.token, SubscriptEvent.PROVPAID);
                                            emit Coordinates(remitSub.id, u, s, remitSub.f, nextUncheckedDay);

                                            //remits from subscriber to provider
                                            IERC20(remitSub.token).safeTransferFrom(subscriber, remitSub.provider, amount);
                                        } else {

                                            //FEEFILL

                                            //Caller gets paid remainder of feeBalance
                                            totalFee += feeBalance[remitSub.id][subscriber];
                                            delete feeBalance[remitSub.id][subscriber];

                                            //log as feefill
                                            emit SubLog(remitSub.id, remitSub.provider, subscriber, uint40(block.timestamp), amount, remitSub.token, SubscriptEvent.FEEFILL);

                                            //adjusts feefill based on frequency
                                            
                                            //variables for feefill
                                            uint256 feefill = amount;
                                            uint256 multiple = 1;

                                            if(f == 2) {
                                                feefill /= 3;
                                                multiple = 2;
                                            }
                                            else if(f == 3) {
                                                feefill /= 12;
                                                multiple = 11;
                                            }
                                        
                                            //remits to contract to refill fee balance
                                            feeBalance[remitSub.id][subscriber] += feefill;
                                            IERC20(remitSub.token).safeTransferFrom(subscriber, address(this), convertAmount(feefill, remitSub.decimals));

                                            if(f == 2 || f == 3) {
                                                //funds the remainder to the provider
                                                IERC20(remitSub.token).safeTransferFrom(subscriber, remitSub.provider, convertAmount((feefill * multiple), remitSub.decimals));
                                            }
                                        }
                                    } else {
                                        //FAILURE
                                        //Currently refunds remainder to Provider

                                        remitCounter++;
                        
                                        //checks if theres is enough feebalance left to pay Caller
                                        if(feeBalance[remitSub.id][subscriber] > subFee) {
                                        
                                            //adds fee on fails
                                            totalFee += subFee;

                                            uint256 feeRemainder = feeBalance[remitSub.id][subscriber] - subFee;

                                            //decrease feeBalance by fee and then zeros out
                                            delete feeBalance[remitSub.id][subscriber];

                                            emit SubLog(remitSub.id, remitSub.provider, subscriber, uint40(block.timestamp), feeRemainder, remitSub.token, SubscriptEvent.PROVREFUND);

                                            //pays remainder to provider
                                            IERC20(remitSub.token).safeTransfer(remitSub.provider, convertAmount(feeRemainder, remitSub.decimals));
                                        }

                                        //unsubscribes on failure
                                        deleteSubFromSubscription(remitSub.id, subscriber);

                                        //emit unsubscribe to log
                                        emit SubLog(remitSub.id, remitSub.provider, subscriber, uint40(block.timestamp), amount, remitSub.token, SubscriptEvent.UNSUBSCRIBED);

                                        //log as failed
                                        emit SubLog(remitSub.id, remitSub.provider, subscriber, uint40(block.timestamp), 0, remitSub.token, SubscriptEvent.FAILED);
                                        emit Coordinates(remitSub.id, u, s, remitSub.f, nextUncheckedDay);
                                    
                                    }
                                    //sends fees to caller on last subscriber in list (unless there are no subscribers)
                                    if(u == lastSub && sublength > 0) {

                                        //if system fee is activated divides caller fee and remits portion to system
                                        if(allowSystemFee) {
                                            uint256 sysAmount = (totalFee * systemFee / 10000) - totalFee;
                                            totalFee -= sysAmount;
                                            //sends system fee to system
                                            IERC20(remitSub.token).safeTransfer(sysFeeReceiver, convertAmount(sysAmount, remitSub.decimals));
                                        } 
                                        //sends fees to caller
                                        IERC20(remitSub.token).safeTransfer(msg.sender, convertAmount(totalFee, remitSub.decimals));
                                        
                                    }
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

        //Makes caller log
        emit CallerLog(uint40(block.timestamp), nextUncheckedDay, msg.sender, true);

        //updates lastCheckedTimeSlot
        nextUncheckedDay += 1;
        
        //keeps going until it hits a day with transactions
        if(isEmptyDay){
            locked = false;
            return remit();
        }

        return;
    }
}