// SPDX-License-Identifier: BUSL-1.1
//Copyright Hugo Marx 2024
pragma solidity ^0.8.27;
import "hardhat/console.sol";

interface ERC20{
  function transferFrom(address from, address to, uint value) external returns (bool);
  function balanceOf(address tokenOwner) external returns (uint);
  function approve(address spender, uint tokens) external returns (bool);
  function transfer(address to, uint value) external returns (bool);
  function allowance(address owner, address spender) external returns (uint);
} 

/// @title Clocktower Subscription Protocol
/// @author Hugo Marx
contract ClockTowerSubscribe {

    /** 
    @dev 
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

    /// @notice Percentage of subscription given to user who calls remit as a fee
    /// @dev 10000 = No fee, 10100 = 1%, 10001 = 0.01%
    /// @dev If caller fee is above 8.33% because then a second feefill would happen on annual subs
    uint public callerFee;

    /// @notice Fee paid to protocol in ethereum
    /// @dev in wei
    uint public systemFee;

    uint public maxRemits;

    /// @dev Index if transaction pagination needed due to remit amount being larger than block
    PageStart pageStart;

    mapping (address => ApprovedToken) public approvedERC20;

    //TODO: need to document
    bool pageGo;

    /// @dev Variable for last checked by day
    uint40 public nextUncheckedDay;

    address payable admin;

    bool allowExternalCallers;

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
        bool exists;
        SubIndex[] subscriptions;
        SubIndex[] provSubs;
    }

    struct Subscription {
        bytes32 id;
        uint amount;
        address provider;
        address token;
        bool exists;
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
        uint subscriberIndex;
    }

    ///@dev same as subscription but adds the status for subscriber
    struct SubView {
        Subscription subscription;
        Status status;
        uint totalSubscribers;
    }

    ///@dev Subscriber struct for views
    struct SubscriberView {
        address subscriber;
        uint feeBalance;
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
        uint fee;
        address token;
    }

    //approved ERC20 struct
    struct ApprovedToken {
        address tokenAddress;
        uint minimum;
        uint8 decimals;
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

    struct Remit {
        bytes32 id;
        address token;
        address provider;
        uint8 decimals;
    }

    //Events-------------------------------------
    event CallerLog(
        uint40 timestamp,
        uint40 checkedDay,
        address indexed caller,
        bool isFinished
    );

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

   /// @notice Contract constructor 
   /// @param callerFee_ The percentage of the subscription the Caller is paid each period
   /// @dev 10000 = No fee, 10100 = 1%, 10001 = 0.01%
   /// @dev If caller fee is above 8.33% because then a second feefill would happen on annual subs
   /// @param systemFee_ The amount of chain token in wei the system is paid
   /// @param maxRemits_ The maximum remits per transaction
   /// @param allowSystemFee_ Is the system fee turned on?
   /// @param admin_ The admin address

   constructor(uint callerFee_, uint systemFee_, uint maxRemits_, bool allowSystemFee_, address admin_) payable {
        
    callerFee = callerFee_;

    systemFee = systemFee_;

    maxRemits = maxRemits_;

    allowSystemFee = allowSystemFee_;

    ///@dev variable for last checked by day
    nextUncheckedDay = (unixToDays(uint40(block.timestamp)) - 2);

    admin = payable(admin_);

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
        
    }
    fallback() external payable{
        
    }

    //ADMIN METHODS*************************************

    function adminRequire() private view {
        require(msg.sender == admin, "16");
    }
    
    
    /// @notice Checks if user is admin
    modifier isAdmin() {
        adminRequire();
        _;
    }

    /// @notice Method to get accumulated systemFees
    function collectFees() isAdmin external {

        if(address(this).balance > 5000) {
            admin.transfer(address(this).balance - 5000);
        }
    }   

    /// @notice Changes admin address
    /// @param newAddress New admin address
    function changeAdmin(address payable newAddress) isAdmin external {
       require((newAddress != address(0)));

        admin = newAddress;
    }

    /// @notice Allows external callers
    /// @param status true or false
    function setExternalCallers(bool status) isAdmin external {
        allowExternalCallers = status;
    }

    /// @notice Allow system fee
    /// @param status true of false
    function systemFeeActivate(bool status) isAdmin external {
        allowSystemFee = status;
    }

    /// @notice Add allowed ERC20 token
    /// @param erc20Contract ERC20 Contract address
    /// @param minimum Token minimum in wei
    /// @param decimals Number of token decimals
    function addERC20Contract(address erc20Contract, uint minimum, uint8 decimals) isAdmin external {

        require(erc20Contract != address(0));
        require(!erc20IsApproved(erc20Contract), "1");

        approvedERC20[erc20Contract] = ApprovedToken(erc20Contract, minimum, decimals, true);
    }

    /// @notice Remove ERC20Contract from allowed list
    /// @param erc20Contract Address of ERC20 token contract
    function removeERC20Contract(address erc20Contract) isAdmin external {
        require(erc20Contract != address(0));
        require(erc20IsApproved(erc20Contract), "2");

        delete approvedERC20[erc20Contract];
    }

    /// @notice Changes Caller fee
    /// @param _fee New Caller fee
    /// @dev 10000 = No fee, 10100 = 1%, 10001 = 0.01%
    /// @dev If caller fee is above 8.33% because then a second feefill would happen on annual subs
    function changeCallerFee(uint _fee) isAdmin external {
        callerFee = _fee;
    }

    /// @notice Change system fee
    /// @param _fixed_fee New System Fee in wei
    function changeSystemFee(uint _fixed_fee) isAdmin external {
        systemFee = _fixed_fee;
    }

    /// @notice Change max remits
    /// @param _maxRemits New number of max remits per transaction
    function changeMaxRemits(uint _maxRemits) isAdmin external {
        maxRemits = _maxRemits;
    }

    //-------------------------------------------------------

     //TIME FUNCTIONS-----------------------------------
    /// @notice Converts unix time number to Time struct
    /// @param unix Unix Epoch Time number
    /// @return time Time struct
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

    /// @notice Checks if year is a leap year
    /// @param year Year number
    /// @return  leapYear Boolean value. True if leap year false if not
    function isLeapYear(uint year) internal pure returns (bool leapYear) {
        leapYear = ((year % 4 == 0) && (year % 100 != 0)) || (year % 400 == 0);
    }

    /// @notice Returns number of days in month 
    /// @param year Number of year
    /// @param month Number of month. 1 - 12
    /// @dev Month range is 1 - 12
    /// @return daysInMonth Number of days in the month
    function getDaysInMonth(uint year, uint month) internal pure returns (uint daysInMonth) {
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
    function getDayOfWeek(uint unixTime) internal pure returns (uint16 dayOfWeek) {
        uint _days = unixTime / 86400;
        uint dayOfWeekuint = (_days + 3) % 7 + 1;
        dayOfWeek = uint16(dayOfWeekuint);

    }

    /// @notice Gets day of quarter
    /// @param yearDays Day of year
    /// @param year Number of year
    /// @return quarterDay Returns day in quarter
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

    /// @notice Get subscriptions by account address and type (provider or subscriber)
    /// @param bySubscriber If true then get subscriptions user is subscribed to. If false get subs user created
    /// @param account Account address 
    /// @return Returns array of subscriptions in the Subview struct form
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

    /// @return Returns total amount of subscribers
    //returns total amount of subscribers
    function getTotalSubscribers() external view returns (uint) {
        return accountLookup.length;
    }
    

    /// @notice Gets account struct by address
    /// @param account Account address
    /// @return Returns Account struct for supplied address
    function getAccount(address account) public view returns (Account memory) {
        return accountMap[account];
    }
    
    /// @notice Gets subscribers by subscription id
    /// @param id Subscription id in bytes
    /// @return Returns array of subscribers in SubscriberView struct form
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
    
    /// @notice Gets subscription struct by id, frequency and due day
    /// @param id Subscription id in bytes
    /// @param frequency Frequency number of cycle
    /// @dev 0 = Weekly, 1 = Monthly, 2 = Quarterly, 3 = Yearly
    /// @param dueDay The day in the cycle the subscription is due
    /// @dev The dueDay will be within differing ranges based on frequency. 
    /// @return subscription Subscription struct
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
    
    /// @notice Function that sends back array of FeeEstimate structs per subscription
    /// @return Array of FeeEstimate structs
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
    
    /// @notice Function that subscribes subscriber to subscription
    /// @param subscription Subscription struct
    /// @dev Requires ERC20 allowance to be set before function is called
    function subscribe(Subscription calldata subscription) external payable {

        //cannot be sent from zero address
        userNotZero();

        require(subExists(subscription.id, subscription.dueDay, subscription.frequency, Status.ACTIVE), "7");

        uint convertedAmount = convertAmount(subscription.amount, approvedERC20[subscription.token].decimals);

        //check if there is enough allowance
        require(ERC20(subscription.token).allowance(msg.sender, address(this)) >= convertedAmount
                &&
                ERC20(subscription.token).balanceOf(msg.sender) >= convertedAmount, "20");
    
        //cant subscribe to subscription you own
        require(msg.sender != subscription.provider, "0");

        //require(subExists(subscription.id, subscription.dueDay, subscription.frequency, Status.ACTIVE), "7");

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
        emit SubLog(subscription.id, subscription.provider, msg.sender, uint40(block.timestamp), subscription.amount, subscription.token, SubscriptEvent.SUBSCRIBED);
        emit SubLog(subscription.id, subscription.provider, msg.sender, uint40(block.timestamp), fee, subscription.token, SubscriptEvent.FEEFILL);

        //funds cost with fee balance
        require(ERC20(subscription.token).transferFrom(msg.sender, address(this), convertAmount(fee, approvedERC20[subscription.token].decimals)));
        if(subscription.frequency == Frequency.QUARTERLY || subscription.frequency == Frequency.YEARLY) {
            //funds the remainder to the provider
            require(ERC20(subscription.token).transferFrom(msg.sender, subscription.provider, convertAmount((fee * multiple), approvedERC20[subscription.token].decimals)));
        }
    }
    
    /// @notice Unsubscribes account from subscription
    /// @param subscription Subscription struct 
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
        emit SubLog(subscription.id, subscription.provider, msg.sender, uint40(block.timestamp), subscription.amount, subscription.token, SubscriptEvent.UNSUBSCRIBED);

        //refunds fees to provider
        uint balance = feeBalance[subscription.id][msg.sender];

        //zeros out fee balance
        delete feeBalance[subscription.id][msg.sender];

        //emit ProviderLog(subscription.id, subscription.provider, uint40(block.timestamp), balance, subscription.token, ProvEvent.REFUND);
        emit SubLog(subscription.id, subscription.provider, msg.sender, uint40(block.timestamp), balance, subscription.token, SubscriptEvent.PROVREFUND);

        //Refunds fee balance
        require(ERC20(subscription.token).transfer(subscription.provider, convertAmount(balance, approvedERC20[subscription.token].decimals)), "21");
        
    }

     /// @notice Allows provider to unsubscribe a subscriber by address
     /// @param subscription Subscription struct
     /// @param subscriber Subsriber address
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
        require(ERC20(subscription.token).transfer(subscriber, convertAmount(balance, approvedERC20[subscription.token].decimals)), "21");
        
    }
        
    /// @notice Function that provider uses to cancel subscription
    /// @dev Will cancel all subscriptions 
    /// @param subscription Subscription struct
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
            require(ERC20(subscription.token).transfer(subscribers[i], convertAmount(feeBal, approvedERC20[subscription.token].decimals)), "21");
            
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

        emit SubLog(subscription.id, msg.sender, address(0), uint40(block.timestamp), amount, subscription.token, SubscriptEvent.CREATE);
    }

    /// @notice Change subcription details in event logs
    /// @param details Details struct
    /// @param id Subscription id in bytes
    function editDetails(Details calldata details, bytes32 id) external {
        
        //checks if msg.sender is provider
        Account memory returnedAccount = getAccount(msg.sender);

        if(returnedAccount.exists) {
            //checks if subscription is part of account
            for(uint i; i < returnedAccount.provSubs.length; i++) {
                if(returnedAccount.provSubs[i].id == id) {
                    emit DetailsLog(id, msg.sender, uint40(block.timestamp), details.url, details.description);
                }
            }
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

                    /*
                    bytes32 id = subscriptionMap[f][timeTrigger][s].id;
                    address token = subscriptionMap[f][timeTrigger][s].token;
                    //uint amount = subscriptionMap[f][timeTrigger][s].amount;
                    address provider = subscriptionMap[f][timeTrigger][s].provider;
                    */
                    //uint8 decimals = approvedERC20[subscriptionMap[f][timeTrigger][s].token].decimals;
                    //struct created to avoid 'stack too deep' error with too many variables
                    Remit memory remitSub = Remit(subscriptionMap[f][timeTrigger][s].id, 
                        subscriptionMap[f][timeTrigger][s].token, 
                        subscriptionMap[f][timeTrigger][s].provider,
                        approvedERC20[subscriptionMap[f][timeTrigger][s].token].decimals
                    );

                    uint amount = convertAmount(subscriptionMap[f][timeTrigger][s].amount, remitSub.decimals);
                
                    //calculates fee balance
                    uint subFee = (amount * callerFee / 10000) - amount;
                    uint totalFee;

                    uint sublength = subscribersMap[remitSub.id].length;
                    uint lastSub;
                    
                    //makes sure on an empty subscription lastSub doesn't underflow
                    if(sublength > 0) {
                        lastSub = sublength - 1;
                    }
                    
                    //loops through subscribers
                    for(uint u; u < sublength; u++) {

                        //checks for max remit and returns false if limit hit
                        if(remitCounter == maxRemits) {
                            pageStart = PageStart(remitSub.id, u);
                            pageGo = false;
                            
                            //sends fees to caller
                            require(ERC20(remitSub.token).transfer(msg.sender, convertAmount(totalFee, remitSub.decimals)), "22");
                            
                            emit CallerLog(uint40(block.timestamp), nextUncheckedDay, msg.sender, false);
                            return;
                        }

                        //if this is the subscription and subscriber the page starts on
                        if(remitSub.id == pageStart.id && u == pageStart.subscriberIndex) {
                            pageGo = true;
                        } 

                        //if remits are less than max remits or beginning of next page
                        if(pageStart.id == 0 || pageGo == true) {
                            
                            //checks for failure (balance and unlimited allowance)
                            address subscriber = subscribersMap[remitSub.id][u];

                            //check if there is enough allowance and balance
                            if(ERC20(remitSub.token).allowance(subscriber, address(this)) >= amount
                            && 
                            ERC20(remitSub.token).balanceOf(subscriber) > amount) {
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

                                    //remits from subscriber to provider
                                    require(ERC20(remitSub.token).transferFrom(subscriber, remitSub.provider, amount));
                                } else {

                                    //FEEFILL

                                    //Caller gets paid remainder of feeBalance
                                    totalFee += feeBalance[remitSub.id][subscriber];
                                    delete feeBalance[remitSub.id][subscriber];

                                    //log as feefill
                                    //emit SubscriberLog(id, subscriber, provider, uint40(block.timestamp), amount, token, SubEvent.FEEFILL);
                                    emit SubLog(remitSub.id, remitSub.provider, subscriber, uint40(block.timestamp), amount, remitSub.token, SubscriptEvent.FEEFILL);

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
                                    feeBalance[remitSub.id][subscriber] += feefill;
                                    require(ERC20(remitSub.token).transferFrom(subscriber, address(this), convertAmount(feefill, remitSub.decimals)));

                                    if(f == 2 || f == 3) {
                                        //funds the remainder to the provider
                                        require(ERC20(remitSub.token).transferFrom(subscriber, remitSub.provider, convertAmount((feefill * multiple), remitSub.decimals)));
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

                                    uint feeRemainder = feeBalance[remitSub.id][subscriber] - subFee;

                                    //decrease feeBalance by fee and then zeros out
                                    delete feeBalance[remitSub.id][subscriber];

                                    //emit ProviderLog(id, provider, uint40(block.timestamp), feeRemainder, token, ProvEvent.REFUND);
                                    emit SubLog(remitSub.id, remitSub.provider, subscriber, uint40(block.timestamp), feeRemainder, remitSub.token, SubscriptEvent.PROVREFUND);

                                    //pays remainder to provider
                                    require(ERC20(remitSub.token).transfer(remitSub.provider, convertAmount(feeRemainder, remitSub.decimals)));
                                }

                                //unsubscribes on failure
                                deleteSubFromSubscription(remitSub.id, subscriber);

                                //emit unsubscribe to log
                                emit SubLog(remitSub.id, remitSub.provider, subscriber, uint40(block.timestamp), amount, remitSub.token, SubscriptEvent.UNSUBSCRIBED);

                                //log as failed
                                emit SubLog(remitSub.id, remitSub.provider, subscriber, uint40(block.timestamp), 0, remitSub.token, SubscriptEvent.FAILED);
                            
                            }
                            //sends fees to caller on last subscriber in list (unless there are no subscribers)
                            if(u == lastSub && sublength > 0) {

                               //sends fees to caller
                               require(ERC20(remitSub.token).transfer(msg.sender, convertAmount(totalFee, remitSub.decimals)), "22");
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