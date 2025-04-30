// SPDX-License-Identifier: BUSL-1.1
// Copyright Clocktower LLC 2025
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/access/extensions/AccessControlDefaultAdminRules.sol";
import "./ClockTowerTimeLibrary.sol";
import "hardhat/console.sol";

/// @title Clocktower Subscription Protocol
/// @author Hugo Marx
contract ClockTowerSubscribe is AccessControlDefaultAdminRules {
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
    9 = Subscriber not subscribed or aleady unsubscribed
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
    21 = Above Cancel Subscriber Limit
    22 = No Subscribers
    23 = Subscription is cancelled
    24 = Cant subscribe while paginating
    25 = Already subscribed
    */

    bytes32 public constant JANITOR_ROLE = keccak256("JANITOR_ROLE");
    
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
    event UList(
        uint40 indexed timestamp,
        bytes32 indexed id, 
        address indexed subscriber
    );

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

   constructor(uint256 callerFee_, uint256 systemFee_, uint256 maxRemits_, uint256 cancelLimit_, bool allowSystemFee_, address admin_, address janitor_) 
   AccessControlDefaultAdminRules(
    1 days,
    admin_
   ) 
   {

    //checks that admin address is not zero
    require(admin_ != address(0));

    //checks that caller and system fees are within bounds
    require(callerFee_ >= 10000 && callerFee_ <= 10833);
    require(systemFee_ >= 10000 && systemFee_ <= 19999);

    //sets janitor role
    _grantRole(JANITOR_ROLE, janitor_);
        
    callerFee = callerFee_;

    systemFee = systemFee_;

    cancelLimit = cancelLimit_;

    maxRemits = maxRemits_;

    allowSystemFee = allowSystemFee_;

    ///@dev variable for last checked by day
    nextUncheckedDay = (ClockTowerTimeLibrary.unixToDays(uint40(block.timestamp)) - 2);

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
    mapping(bytes32 => EnumerableSet.AddressSet) subscribersMap;

    //mapping of subscriptions by id
    mapping(bytes32 => Subscription) public idSubMap;

    //mapping of unsubscribed addresses per subscription made during pagination
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
    function changeSysFeeReceiver(address newSysFeeAddress) external onlyRole(DEFAULT_ADMIN_ROLE) {
       require((newSysFeeAddress != address(0)));

       //checks that address is different
       require(newSysFeeAddress != sysFeeReceiver);
         
        sysFeeReceiver = newSysFeeAddress;
    }

    /// @notice Allow system fee
    /// @param status true of false
    function systemFeeActivate(bool status) external onlyRole(DEFAULT_ADMIN_ROLE) {
        allowSystemFee = status;
    }

    /// @notice Add allowed ERC20 token
    /// @param erc20Contract ERC20 Contract address
    /// @param minimum Token minimum in wei
    /// @param decimals Number of token decimals
    function addERC20Contract(address erc20Contract, uint256 minimum, uint8 decimals) external onlyRole(DEFAULT_ADMIN_ROLE) {

        require(erc20Contract != address(0));
        require(!erc20IsApproved(erc20Contract), "1");

        approvedERC20[erc20Contract] = ApprovedToken(erc20Contract, decimals, false, minimum);
    }


    /// @notice Changes Caller fee
    /// @param _fee New Caller fee
    /// @dev 10000 = No fee, 10100 = 1%, 10001 = 0.01%
    /// @dev If caller fee is above 8.33% because then a second feefill would happen on annual subs
    function changeCallerFee(uint256 _fee) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_fee >= 10000 && _fee <= 10833);
        callerFee = _fee;
    }

    /// @notice Change system fee
    /// @dev 10000 = No fee, 10100 = 1%, 10001 = 0.01%
    /// @param _sys_fee New System fee
    function changeSystemFee(uint256 _sys_fee) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_sys_fee >= 10000 && _sys_fee <= 19999);
        systemFee = _sys_fee;
    }

    /// @notice Change max remits
    /// @param _maxRemits New number of max remits per transaction
    function changeMaxRemits(uint256 _maxRemits) external onlyRole(DEFAULT_ADMIN_ROLE) {
        maxRemits = _maxRemits;
    }

    
    /// @notice Set pageStart coordinates
    /// @param _pageStart Contains of coordinates of where next remit should start
    function setPageStart(PageStart calldata _pageStart) external onlyRole(DEFAULT_ADMIN_ROLE) {
        pageStart = _pageStart;
    }

    /// @notice Set next unchecked day
    /// @param _nextUncheckedDay next day to be remitted
    function setNextUncheckedDay(uint40 _nextUncheckedDay) external onlyRole(DEFAULT_ADMIN_ROLE) {
        nextUncheckedDay = _nextUncheckedDay;
    }

    /// @notice pause subscriptions that contain a certain token
    /// @param _tokenAddress address of token to be paused
    /// @param pause true = pause, false = unpause
    function pauseToken(address _tokenAddress, bool pause) external onlyRole(DEFAULT_ADMIN_ROLE) {

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

    /// @notice sets cancel limit
    /// @param _cancelLimit amount of unsubscribes that can be janitor per transaction
    function setCancelLimit(uint256 _cancelLimit) external  onlyRole(DEFAULT_ADMIN_ROLE) {

        cancelLimit = _cancelLimit;

    }

   
    /// @notice Function that allows provider to unsubscribe users in batches. Should only be used when cancelling large subscriptions
    /// @dev Will cancel subscriptions up to cancel limit
    /// @param subscription Subscription struct
    function cleanupCancelledSubscribers(Subscription memory subscription) external onlyRole(JANITOR_ROLE) {

        //requires that subscription exists and is cancelled
        //checks subscription exists
        require(subExists(subscription.id), "3");

        //checks that it is already cancelled
        require(idSubMap[subscription.id].cancelled);

        //gets total subscribed subscribers
        uint256 length = subscribersMap[subscription.id].length();

        uint256 remainingSubs = length;

        //can't have zero subscribers
        require(remainingSubs > 0, "22");

        
        //sets number of loops based on if amount is below limit or not
        uint256 loops = remainingSubs < cancelLimit ? remainingSubs : cancelLimit;
        

        uint256 sysbalance;        
        
        //loops backward through remaining subs or max amount
        for(uint256 i = length; i > (length - loops); i--) {
            
            //gets address
            address subscriber = subscribersMap[subscription.id].at(i - 1);
           
            //checks if subscriber is already unsubscribed 
            if(!unsubscribedMap[subscription.id].contains(subscriber)) {

                //Change status to cancelled
                subStatusMap[subscriber][subscription.id] = Status.CANCELLED;

                //emit unsubscribe to log
                emit SubLog(subscription.id, subscription.provider, subscriber, uint40(block.timestamp), subscription.amount, subscription.token, SubscriptEvent.UNSUBSCRIBED);

                uint256 subBalance = feeBalance[subscription.id][subscriber];

                if(allowSystemFee) {
                    uint256 sysAmount = (subBalance * systemFee / 10000) - subBalance;
                    subBalance -= sysAmount;

                    //pays remaining balance to system
                    sysbalance += sysAmount;
                }

                emit SubLog(subscription.id, subscription.provider, subscriber, uint40(block.timestamp), subscription.amount, subscription.token, SubscriptEvent.SUBREFUND);

                //sends remainder to subscriber
                IERC20(subscription.token).safeTransfer(subscriber, convertAmount(subBalance, approvedERC20[subscription.token].decimals));

                //zeros out fee balance
                delete feeBalance[subscription.id][subscriber];
            }

            //removes from set
            subscribersMap[subscription.id].remove(subscriber);            
        }

        if(allowSystemFee) {
            //Refunds fee to protocol
            IERC20(subscription.token).safeTransfer(sysFeeReceiver, convertAmount(sysbalance, approvedERC20[subscription.token].decimals));
        }
        
    }

    /// @notice function that cleans up subscribers on unsubscribed list 
    /// @dev will process up to cancelLimit
    /// @param id of subscription
    function cleanUnsubscribeList(bytes32 id) external onlyRole(JANITOR_ROLE) {

        require(subExists(id), "3");

        //cant be in pagination
        require(id != pageStart.id);

        //gets total subscribed subscribers
        uint256 length = unsubscribedMap[id].length();

        uint256 remainingSubs = length;

        //can't have zero subscribers
        require(remainingSubs > 0, "22");

        //sets number of loops based on if amount is below limit or not
        uint256 loops = remainingSubs < cancelLimit ? remainingSubs : cancelLimit;

        //decrements through subscribers to delete
        for(uint256 i = unsubscribedMap[id].length(); i > (length - loops); i--) {

            //gets address
            address subscriber = unsubscribedMap[id].at(i - 1);

            //deletes subscriber from subscriber list and unsubscribed list
            subscribersMap[id].remove(subscriber);
            unsubscribedMap[id].remove(subscriber);
        }

    }

    //VIEW FUNCTIONS ----------------------------------------

    /// @notice gets length of unsubcribed list by id
    /// @param id subscription id
    /// @return length of enumerable set
    /// @dev unsubscribed list is not the total list of unsubscribed users but only those done during pagination. 
    function getUnsubscribedLength(bytes32 id) external view returns (uint256) {
        return unsubscribedMap[id].length();
    } 

    ///@notice Get subscription id by time
    ///@param frequency 0 to 3 number for frequency. O = weekly, 1 = monthly, 2 quarterly, 3 yearly
    ///@param dueDay day in proper range for frequency when subscription is paid
    ///@return Set of ids
    function getIdByTime(uint256 frequency, uint16 dueDay) external view returns (bytes32[] memory) {

        bytes32[] memory subs = new bytes32[](subscriptionMap[frequency][dueDay].length());
        //iterates through set to create array
        for(uint256 i; i < subscriptionMap[frequency][dueDay].length(); i++){
            subs[i] = subscriptionMap[frequency][dueDay].at(i);
        }
        return subs;
    }

    /// @notice Get subscriptions by account address and type (provider or subscriber)
    /// @param bySubscriber If true then get subscriptions user is subscribed to. If false get subs user created
    /// @param account Account address 
    /// @return Returns array of subscriptions in the Subview struct form
    function getAccountSubscriptions(bool bySubscriber, address account) external view returns (SubView[] memory) {

        bytes32[] memory ids;
        if(bySubscriber) {
            ids = subscribedTo[account].values();
        } else {
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
            subViews[i].totalSubscribers = subscribersMap[subViews[i].subscription.id].length(); 
            
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
    function getAccount(address account) external view returns (Account memory) {
        
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
            //}
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

        uint256 length = subscribersMap[id].length() - unsubscribedMap[id].length();
       
        SubscriberView[] memory scriberViews = new SubscriberView[](length);

        for(uint256 i; i < subscribersMap[id].length(); i++) {

            //doesnt count subscribers in unsubscribed list
            if(!unsubscribedMap[id].contains(subscribersMap[id].at(i))) {
                uint256 feeBalanceTemp = feeBalance[id][subscribersMap[id].at(i)];
                SubscriberView memory scriberView = SubscriberView(subscribersMap[id].at(i), feeBalanceTemp);
                scriberViews[i] = scriberView;
            }
        }

        return scriberViews;
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
    function addToUnsubscribeList(bytes32 id, address account) private {
        
        //adds unsubscribed address to set
        if(!unsubscribedMap[id].contains(account)) {
            emit UList(uint40(block.timestamp), id, account);
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
    /// @param _subscription Subscription struct
    /// @dev Requires ERC20 allowance to be set before function is called
    function subscribe(Subscription calldata _subscription) external {

        require(subExists(_subscription.id), "3");

        //gets saved subscription 
        Subscription memory subscription = idSubMap[_subscription.id];

        //checks that token is not paused
        require(!approvedERC20[subscription.token].paused, '20');

        //cant subscribe while subscription is pagination checkpoint
        require(_subscription.id != pageStart.id, "24");

        uint256 convertedAmount = convertAmount(subscription.amount, approvedERC20[subscription.token].decimals);

        //check if there is enough allowance and balance
        require(IERC20(subscription.token).allowance(msg.sender, address(this)) >= convertedAmount
                &&
                IERC20(subscription.token).balanceOf(msg.sender) >= convertedAmount, "10");
    
        //cant subscribe to subscription you own
        require(msg.sender != subscription.provider, "0");

        //can't subscribe to same subscription multiple times
        require(!subscribersMap[subscription.id].contains(msg.sender) || unsubscribedMap[subscription.id].contains(msg.sender), "25");

        //checks that subscription is not cancelled
        require(!subscription.cancelled, "23");

        //checks if this subscription has any subscribers
        //if this is the first subscription it adds it the time trigger mapping
        if(subscribersMap[subscription.id].length() == 0) {
            subscriptionMap[uint256(subscription.frequency)][subscription.dueDay].add(subscription.id);
        }


        //Adds to subscriber set
        if(!subscribersMap[subscription.id].contains(msg.sender)) {
            subscribersMap[subscription.id].add(msg.sender);
        }

        //Removes from unsubscribed set
        if(unsubscribedMap[subscription.id].contains(msg.sender)) {
            unsubscribedMap[subscription.id].remove(msg.sender);
        }

        //adds it to account
        addAccountSubscription(SubIndex(subscription.id, subscription.dueDay, subscription.frequency, Status.ACTIVE), false);
        
        uint256 fee = subscription.amount;
        //uint256 multiple = 1;

        //prorates fee amount

        //gets current time slot based on day
        uint40 currentDay = ClockTowerTimeLibrary.unixToDays(uint40(block.timestamp));

        bool isBeforeRemit;

        //checks if prorated amount is below caller fee
        bool tooLow;
        uint callerAmount = (subscription.amount * callerFee / 10000) - subscription.amount;
        
        if(nextUncheckedDay <= currentDay) {
            isBeforeRemit = true;
        }

        //uint256 offset;

        fee = ClockTowerTimeLibrary.prorate((block.timestamp), subscription.dueDay, fee, uint8(subscription.frequency));

        //checks if prorated fee is too low or if subscriber subscribes on due date before remittance
        if(fee < callerAmount || (fee == subscription.amount && isBeforeRemit)) {
            tooLow = true;
            fee = callerAmount;
        }

        /*
        //offsets proration back a day if subscriber subscribes on due date before remittance
        if(fee == subscription.amount && isBeforeRemit) {
            offset = 86400;
            fee = ClockTowerTimeLibrary.prorate((block.timestamp - offset), subscription.dueDay, fee, uint8(subscription.frequency));
        }
        */

        uint remainder;
        uint fillAmount = fee;
        
        //checks if prorated amount is over a weeks worth.
        if(subscription.frequency == Frequency.MONTHLY && !tooLow) {
            if((fee * 100) / subscription.amount >= 25) {
                fillAmount = subscription.amount * 25 / 100;
                remainder = fee - fillAmount;
            }
        }

        if((subscription.frequency == Frequency.QUARTERLY || subscription.frequency == Frequency.YEARLY)  && !tooLow) {
            if((fee * 1000) / subscription.amount >= 83) {
                fillAmount = subscription.amount * 83 / 1000;
                remainder = fee - fillAmount;
            }
        }
    
        /*
        //charges a third's worth of the amount to the contract 
        if(subscription.frequency == Frequency.QUARTERLY && !tooLow) {
            fee /= 3;
            multiple = 2;
        }
               
        //charges a twelth of the amount to the contract
        if(subscription.frequency == Frequency.YEARLY && !tooLow) {
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
        if((subscription.frequency == Frequency.QUARTERLY || subscription.frequency == Frequency.YEARLY) && !tooLow) {
            //funds the remainder to the provider
            IERC20(subscription.token).safeTransferFrom(msg.sender, subscription.provider, convertAmount((fee * multiple), approvedERC20[subscription.token].decimals));
        }
        */

        //pays first subscription to fee balance
        feeBalance[subscription.id][msg.sender] += fillAmount;

        //emit subscription to log
        emit SubLog(subscription.id, subscription.provider, msg.sender, uint40(block.timestamp), subscription.amount, subscription.token, SubscriptEvent.SUBSCRIBED);
        emit SubLog(subscription.id, subscription.provider, msg.sender, uint40(block.timestamp), fillAmount, subscription.token, SubscriptEvent.FEEFILL);

         //funds cost with fee balance
        IERC20(subscription.token).safeTransferFrom(msg.sender, address(this), convertAmount(fillAmount, approvedERC20[subscription.token].decimals));
        if((remainder > 0) && !tooLow) {
            emit SubLog(subscription.id, subscription.provider, msg.sender, uint40(block.timestamp), remainder, subscription.token, SubscriptEvent.PROVPAID);
            //funds the remainder to the provider
            IERC20(subscription.token).safeTransferFrom(msg.sender, subscription.provider, convertAmount(remainder, approvedERC20[subscription.token].decimals));
        }
    }
    
    /// @notice Unsubscribes account from subscription
    /// @param _subscription Subscription struct 
    function unsubscribe(Subscription calldata _subscription) external {

        require(subExists(_subscription.id) && subStatusMap[msg.sender][_subscription.id] != Status.UNSUBSCRIBED, "3");

        Subscription memory subscription = idSubMap[_subscription.id];
 
        subStatusMap[msg.sender][subscription.id] = Status.UNSUBSCRIBED;

        //if paginating add to unsubscribe list otherwise delete
        if(pageStart.id == _subscription.id) {
            addToUnsubscribeList(subscription.id, msg.sender);
        } else {
            subscribersMap[subscription.id].remove(msg.sender);
        }

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
     /// @param _subscription Subscription struct
     /// @param subscriber Subscriber address
    function unsubscribeByProvider(Subscription calldata _subscription, address subscriber) external {

        //checks subscription exists
        require(subExists(_subscription.id) && (subStatusMap[subscriber][_subscription.id] != Status.UNSUBSCRIBED), "3");

        Subscription memory subscription = idSubMap[_subscription.id];

        //must be provider
        require(createdSubs[msg.sender].contains(subscription.id), "8");


        //requires subscriber to be part of subscription and not already unsubscribed
        require(subscribersMap[subscription.id].contains(subscriber) && !unsubscribedMap[subscription.id].contains(subscriber), "9");
       
        subStatusMap[subscriber][subscription.id] = Status.UNSUBSCRIBED;

        //if paginating add to unsubscribe list otherwise delete
        if(pageStart.id == _subscription.id) {
            addToUnsubscribeList(subscription.id, subscriber);
        } else {
            subscribersMap[subscription.id].remove(subscriber);
        }

        //emit unsubscribe to log
        emit SubLog(subscription.id, subscription.provider, subscriber, uint40(block.timestamp), subscription.amount, subscription.token, SubscriptEvent.UNSUBSCRIBED);

        //pays remaining balance to system
        uint256 balance = feeBalance[subscription.id][subscriber];

        //zeros out fee balance
        delete feeBalance[subscription.id][subscriber];

        //Refunds fee balance
        IERC20(subscription.token).safeTransfer(subscriber, convertAmount(balance, approvedERC20[subscription.token].decimals));
        
    }
        
    /// @notice Function that provider uses to cancel subscription
    /// @dev Will cancel all subscriptions 
    /// @param _subscription Subscription struct
    function cancelSubscription(Subscription calldata _subscription) external {

        //checks subscription exists
        require(subExists(_subscription.id), "3");

        Subscription memory subscription = idSubMap[_subscription.id];

        //require user be provider
        require(msg.sender == subscription.provider, "13");

        //require subscription is not alerady cancelled
        require(!subscription.cancelled, "23");

        //marks provider as cancelled
        provStatusMap[msg.sender][subscription.id] = Status.CANCELLED; 

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
        uint40 currentDay = ClockTowerTimeLibrary.unixToDays(uint40(block.timestamp));

        require(currentDay >= nextUncheckedDay, "6");

        bool isEmptyDay = true;

        ClockTowerTimeLibrary.Time memory time;

        //checks if day is current day or a past date 
        if(currentDay != nextUncheckedDay) {
           time = ClockTowerTimeLibrary.unixToTime(nextUncheckedDay * 86400);
        }  else {
            time = ClockTowerTimeLibrary.unixToTime(block.timestamp);
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
                
                
                //loops through subscriptions
                for(uint256 s = subscriptionMap[f][timeTrigger].length(); s > 0; s--) {

                    //checks which subscription to start if paginated
                    if(!pageStart.initialized || (pageStart.subscriptionIndex >= s && pageStart.initialized)) {

                        //gets subscription
                        Subscription memory subscription = idSubMap[subscriptionMap[f][timeTrigger].at(s - 1)];

                        
                        //deletes out of time map if empty
                        if(subscribersMap[subscription.id].length() == 0) {
                            subscriptionMap[f][timeTrigger].remove(subscription.id);
                            continue;
                        }
                        

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
                            
                            uint256 convertedAmount = convertAmount(subscription.amount, remitSub.decimals);
                        
                            //calculates fee balance
                            uint256 subFee = (subscription.amount * callerFee / 10000) - subscription.amount;
                            uint256 totalFee;

                            uint256 startLength = (subscribersMap[remitSub.id].length() - unsubscribedMap[remitSub.id].length());
                            
                            //decrements through subscribers
                            for(uint256 u = subscribersMap[remitSub.id].length(); u > 0; u--) {

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
                                    address subscriber = subscribersMap[remitSub.id].at(u - 1);

                                    //skips unsubscribed
                                    if(unsubscribedMap[remitSub.id].contains(subscriber)) {
                                        continue;
                                    }

                                    //check if there is enough allowance and balance
                                    if(IERC20(remitSub.token).allowance(subscriber, address(this)) >= convertedAmount
                                    && 
                                    IERC20(remitSub.token).balanceOf(subscriber) >= convertedAmount) {
                                        //SUCCESS
                                        remitCounter++;

                                        emit Coordinates(remitSub.id, u, s, remitSub.f, nextUncheckedDay);

                                        //checks feeBalance. If positive it decreases balance. 
                                        //If fee balance < fee amount it sends subscription amount to contract as fee payment.
                                        if(feeBalance[remitSub.id][subscriber] > subFee) {

                                            //accounts for fee
                                            totalFee += subFee;
                                            feeBalance[remitSub.id][subscriber] -= subFee;
                                    
                                            //log as succeeded
                                            emit SubLog(remitSub.id, remitSub.provider, subscriber, uint40(block.timestamp), subscription.amount, remitSub.token, SubscriptEvent.SUBPAID);
                                            emit SubLog(remitSub.id, remitSub.provider, subscriber, uint40(block.timestamp), subscription.amount, remitSub.token, SubscriptEvent.PROVPAID);

                                            //remits from subscriber to provider
                                            IERC20(remitSub.token).safeTransferFrom(subscriber, remitSub.provider, convertedAmount);
                                        } else {

                                            //FEEFILL

                                            //Caller gets paid remainder of feeBalance
                                            //totalFee += feeBalance[remitSub.id][subscriber];
                                            //delete feeBalance[remitSub.id][subscriber];

                                            //log as feefill
                                            emit SubLog(remitSub.id, remitSub.provider, subscriber, uint40(block.timestamp), subscription.amount, remitSub.token, SubscriptEvent.FEEFILL);

                                            //adjusts feefill based on frequency
                                            
                                            //variables for feefill
                                            uint256 feefill = subscription.amount;
                                            uint256 multiple = 1;

                                            
                                            /*
                                            if(f == 2) {
                                                feefill /= 3;
                                                multiple = 2;
                                            }
                                            */
                                            
                                            //fills a weeks worth of amount
                                            if(f == 1) {
                                                feefill /= 4;
                                                multiple = 3;
                                            }
                                            else if(f == 2 || f == 3) {
                                                feefill /= 12;
                                                multiple = 11;
                                            }
                                        
                                            //remits to contract to refill fee balance and pays caller fee
                                            feeBalance[remitSub.id][subscriber] += feefill;

                                            //pays the caller the full fee
                                            totalFee += subFee;
                                            feeBalance[remitSub.id][subscriber] -= subFee;

                                            IERC20(remitSub.token).safeTransferFrom(subscriber, address(this), convertAmount(feefill, remitSub.decimals));

                                            if(f == 1 || f == 2 || f == 3) {
                                                emit SubLog(remitSub.id, remitSub.provider, subscriber, uint40(block.timestamp), (feefill * multiple), remitSub.token, SubscriptEvent.PROVPAID);
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
                                        subStatusMap[subscriber][remitSub.id] = Status.UNSUBSCRIBED;
                                        subscribersMap[remitSub.id].remove(subscriber);

                                        //emit unsubscribe to log
                                        emit SubLog(remitSub.id, remitSub.provider, subscriber, uint40(block.timestamp), subscription.amount, remitSub.token, SubscriptEvent.UNSUBSCRIBED);

                                        //log as failed
                                        emit SubLog(remitSub.id, remitSub.provider, subscriber, uint40(block.timestamp), 0, remitSub.token, SubscriptEvent.FAILED);
                                        emit Coordinates(remitSub.id, u, s, remitSub.f, nextUncheckedDay);
                                    
                                    }
                                    //sends fees to caller on last subscriber in list (unless there are no subscribers)
                                    if(u == 1 && startLength > 0) {

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
                        } else {
                            //deletes subscription from time maps if cancelled
                            if(subscription.cancelled) {
                                subscriptionMap[f][timeTrigger].remove(subscription.id);
                            }
                            //turns off pagination coordinates if subscription is cancelled or paused
                            if(pageStart.initialized && (pageStart.id == subscription.id)) {
                               delete pageStart;
                               pageGo = false;
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