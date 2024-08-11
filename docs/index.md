# Solidity API

## ERC20

### transferFrom

```solidity
function transferFrom(address from, address to, uint256 value) external returns (bool)
```

### balanceOf

```solidity
function balanceOf(address tokenOwner) external returns (uint256)
```

### approve

```solidity
function approve(address spender, uint256 tokens) external returns (bool)
```

### transfer

```solidity
function transfer(address to, uint256 value) external returns (bool)
```

### allowance

```solidity
function allowance(address owner, address spender) external returns (uint256)
```

## ClockTowerSubscribe

### callerFee

```solidity
uint256 callerFee
```

Percentage of subscription given to user who calls remit as a fee

_10000 = No fee, 10100 = 1%, 10001 = 0.01%
If caller fee is above 8.33% because then a second feefill would happen on annual subs_

### systemFee

```solidity
uint256 systemFee
```

Fee paid to protocol in ethereum

_in wei_

### maxRemits

```solidity
uint256 maxRemits
```

### pageStart

```solidity
struct ClockTowerSubscribe.PageStart pageStart
```

_Index if transaction pagination needed due to remit amount being larger than block_

### approvedERC20

```solidity
mapping(address => struct ClockTowerSubscribe.ApprovedToken) approvedERC20
```

### pageGo

```solidity
bool pageGo
```

### nextUncheckedDay

```solidity
uint40 nextUncheckedDay
```

_Variable for last checked by day_

### admin

```solidity
address payable admin
```

### allowExternalCallers

```solidity
bool allowExternalCallers
```

### allowSystemFee

```solidity
bool allowSystemFee
```

### Frequency

```solidity
enum Frequency {
  WEEKLY,
  MONTHLY,
  QUARTERLY,
  YEARLY
}
```

### Status

```solidity
enum Status {
  ACTIVE,
  CANCELLED,
  UNSUBSCRIBED
}
```

### SubscriptEvent

```solidity
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
```

### Account

_subscriptions array are subscriptions the user has subscribed to
provSubs array are subscriptions the user has created_

```solidity
struct Account {
  address accountAddress;
  bool exists;
  struct ClockTowerSubscribe.SubIndex[] subscriptions;
  struct ClockTowerSubscribe.SubIndex[] provSubs;
}
```

### Subscription

```solidity
struct Subscription {
  bytes32 id;
  uint256 amount;
  address provider;
  address token;
  bool exists;
  bool cancelled;
  enum ClockTowerSubscribe.Frequency frequency;
  uint16 dueDay;
}
```

### SubIndex

```solidity
struct SubIndex {
  bytes32 id;
  uint16 dueDay;
  enum ClockTowerSubscribe.Frequency frequency;
  enum ClockTowerSubscribe.Status status;
}
```

### PageStart

_Struct for pagination_

```solidity
struct PageStart {
  bytes32 id;
  uint256 subscriberIndex;
}
```

### SubView

_same as subscription but adds the status for subscriber_

```solidity
struct SubView {
  struct ClockTowerSubscribe.Subscription subscription;
  enum ClockTowerSubscribe.Status status;
  uint256 totalSubscribers;
}
```

### SubscriberView

_Subscriber struct for views_

```solidity
struct SubscriberView {
  address subscriber;
  uint256 feeBalance;
}
```

### Time

```solidity
struct Time {
  uint16 dayOfMonth;
  uint16 weekDay;
  uint16 quarterDay;
  uint16 yearDay;
  uint16 year;
  uint16 month;
}
```

### FeeEstimate

```solidity
struct FeeEstimate {
  uint256 fee;
  address token;
}
```

### ApprovedToken

```solidity
struct ApprovedToken {
  address tokenAddress;
  uint256 minimum;
  bool exists;
}
```

### Details

```solidity
struct Details {
  string url;
  string description;
}
```

### ProviderDetails

```solidity
struct ProviderDetails {
  string description;
  string company;
  string url;
  string domain;
  string email;
  string misc;
}
```

### CallerLog

```solidity
event CallerLog(uint40 timestamp, uint40 checkedDay, address caller, bool isFinished)
```

### SubLog

```solidity
event SubLog(bytes32 id, address provider, address subscriber, uint40 timestamp, uint256 amount, address token, enum ClockTowerSubscribe.SubscriptEvent subScriptEvent)
```

### DetailsLog

```solidity
event DetailsLog(bytes32 id, address provider, uint40 timestamp, string url, string description)
```

### ProvDetailsLog

```solidity
event ProvDetailsLog(address provider, uint40 timestamp, string description, string company, string url, string domain, string email, string misc)
```

### constructor

```solidity
constructor(uint256 callerFee_, uint256 systemFee_, uint256 maxRemits_, bool allowSystemFee_, address admin_) public payable
```

Contract constructor

_10000 = No fee, 10100 = 1%, 10001 = 0.01%
If caller fee is above 8.33% because then a second feefill would happen on annual subs_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| callerFee_ | uint256 | The percentage of the subscription the Caller is paid each period |
| systemFee_ | uint256 | The amount of chain token in wei the system is paid |
| maxRemits_ | uint256 | The maximum remits per transaction |
| allowSystemFee_ | bool | Is the system fee turned on? |
| admin_ | address | The admin address |

### accountLookup

```solidity
address[] accountLookup
```

### feeBalance

```solidity
mapping(bytes32 => mapping(address => uint256)) feeBalance
```

### subscriptionMap

```solidity
mapping(uint256 => mapping(uint16 => struct ClockTowerSubscribe.Subscription[])) subscriptionMap
```

### subscribersMap

```solidity
mapping(bytes32 => address[]) subscribersMap
```

### receive

```solidity
receive() external payable
```

### fallback

```solidity
fallback() external payable
```

### isAdmin

```solidity
modifier isAdmin()
```

Checks if user is admin

### collectFees

```solidity
function collectFees() external
```

Method to get accumulated systemFees

### changeAdmin

```solidity
function changeAdmin(address payable newAddress) external
```

Changes admin address

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| newAddress | address payable | New admin address |

### setExternalCallers

```solidity
function setExternalCallers(bool status) external
```

Allows external callers

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| status | bool | true or false |

### systemFeeActivate

```solidity
function systemFeeActivate(bool status) external
```

Allow system fee

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| status | bool | true of false |

### addERC20Contract

```solidity
function addERC20Contract(address erc20Contract, uint256 minimum) external
```

Add allowed ERC20 token

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| erc20Contract | address | ERC20 Contract address |
| minimum | uint256 | Token minimum in wei |

### removeERC20Contract

```solidity
function removeERC20Contract(address erc20Contract) external
```

Remove ERC20Contract from allowed list

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| erc20Contract | address | Address of ERC20 token contract |

### changeCallerFee

```solidity
function changeCallerFee(uint256 _fee) external
```

Changes Caller fee

_10000 = No fee, 10100 = 1%, 10001 = 0.01%
If caller fee is above 8.33% because then a second feefill would happen on annual subs_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| _fee | uint256 | New Caller fee |

### changeSystemFee

```solidity
function changeSystemFee(uint256 _fixed_fee) external
```

Change system fee

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| _fixed_fee | uint256 | New System Fee in wei |

### changeMaxRemits

```solidity
function changeMaxRemits(uint256 _maxRemits) external
```

Change max remits

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| _maxRemits | uint256 | New number of max remits per transaction |

### unixToTime

```solidity
function unixToTime(uint256 unix) internal pure returns (struct ClockTowerSubscribe.Time time)
```

Converts unix time number to Time struct

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| unix | uint256 | Unix Epoch Time number |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| time | struct ClockTowerSubscribe.Time | Time struct |

### isLeapYear

```solidity
function isLeapYear(uint256 year) internal pure returns (bool leapYear)
```

Checks if year is a leap year

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| year | uint256 | Year number |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| leapYear | bool | Boolean value. True if leap year false if not |

### getDaysInMonth

```solidity
function getDaysInMonth(uint256 year, uint256 month) internal pure returns (uint256 daysInMonth)
```

Returns number of days in month

_Month range is 1 - 12_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| year | uint256 | Number of year |
| month | uint256 | Number of month. 1 - 12 |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| daysInMonth | uint256 | Number of days in the month |

### getDayOfWeek

```solidity
function getDayOfWeek(uint256 unixTime) internal pure returns (uint16 dayOfWeek)
```

Gets numberical day of week from Unixtime number

_1 = Monday, 7 = Sunday_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| unixTime | uint256 | Unix Epoch Time number |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| dayOfWeek | uint16 | Returns Day of Week |

### getdayOfQuarter

```solidity
function getdayOfQuarter(uint256 yearDays, uint256 year) internal pure returns (uint16 quarterDay)
```

Gets day of quarter

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| yearDays | uint256 | Day of year |
| year | uint256 | Number of year |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| quarterDay | uint16 | Returns day in quarter |

### unixToDays

```solidity
function unixToDays(uint40 unixTime) internal pure returns (uint40 dayCount)
```

Converts unix time to number of days past Jan 1st 1970

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| unixTime | uint40 | Number in Unix Epoch Time |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| dayCount | uint40 | Number of days since Jan. 1st 1970 |

### prorate

```solidity
function prorate(uint256 unixTime, uint40 dueDay, uint256 fee, uint8 frequency) internal pure returns (uint256)
```

Prorates amount based on days remaining in subscription cycle

_The dueDay will be within differing ranges based on frequency. 
0 = Weekly, 1 = Monthly, 2 = Quarterly, 3 = Yearly_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| unixTime | uint256 | Current time in Unix Epoch Time |
| dueDay | uint40 | The day in the cycle the subscription is due |
| fee | uint256 | Amount to be prorated |
| frequency | uint8 | Frequency number of cycle |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| [0] | uint256 | Prorated amount |

### getAccountSubscriptions

```solidity
function getAccountSubscriptions(bool bySubscriber, address account) external view returns (struct ClockTowerSubscribe.SubView[])
```

Get subscriptions by account address and type (provider or subscriber)

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| bySubscriber | bool | If true then get subscriptions user is subscribed to. If false get subs user created |
| account | address | Account address |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| [0] | struct ClockTowerSubscribe.SubView[] | Returns array of subscriptions in the Subview struct form |

### getTotalSubscribers

```solidity
function getTotalSubscribers() external view returns (uint256)
```

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| [0] | uint256 | Returns total amount of subscribers |

### getAccount

```solidity
function getAccount(address account) public view returns (struct ClockTowerSubscribe.Account)
```

Gets account struct by address

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| account | address | Account address |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| [0] | struct ClockTowerSubscribe.Account | Returns Account struct for supplied address |

### getSubscribersById

```solidity
function getSubscribersById(bytes32 id) external view returns (struct ClockTowerSubscribe.SubscriberView[])
```

Gets subscribers by subscription id

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| id | bytes32 | Subscription id in bytes |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| [0] | struct ClockTowerSubscribe.SubscriberView[] | Returns array of subscribers in SubscriberView struct form |

### getSubByIndex

```solidity
function getSubByIndex(bytes32 id, enum ClockTowerSubscribe.Frequency frequency, uint16 dueDay) public view returns (struct ClockTowerSubscribe.Subscription subscription)
```

Gets subscription struct by id, frequency and due day

_0 = Weekly, 1 = Monthly, 2 = Quarterly, 3 = Yearly
The dueDay will be within differing ranges based on frequency._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| id | bytes32 | Subscription id in bytes |
| frequency | enum ClockTowerSubscribe.Frequency | Frequency number of cycle |
| dueDay | uint16 | The day in the cycle the subscription is due |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| subscription | struct ClockTowerSubscribe.Subscription | Subscription struct |

### feeEstimate

```solidity
function feeEstimate() external view returns (struct ClockTowerSubscribe.FeeEstimate[])
```

Function that sends back array of FeeEstimate structs per subscription

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| [0] | struct ClockTowerSubscribe.FeeEstimate[] | Array of FeeEstimate structs |

### subscribe

```solidity
function subscribe(struct ClockTowerSubscribe.Subscription subscription) external payable
```

Function that subscribes subscriber to subscription

_Requires ERC20 allowance to be set before function is called_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| subscription | struct ClockTowerSubscribe.Subscription | Subscription struct |

### unsubscribe

```solidity
function unsubscribe(struct ClockTowerSubscribe.Subscription subscription) external payable
```

Unsubscribes account from subscription

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| subscription | struct ClockTowerSubscribe.Subscription | Subscription struct |

### unsubscribeByProvider

```solidity
function unsubscribeByProvider(struct ClockTowerSubscribe.Subscription subscription, address subscriber) external
```

Allows provider to unsubscribe a subscriber by address

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| subscription | struct ClockTowerSubscribe.Subscription | Subscription struct |
| subscriber | address | Subsriber address |

### cancelSubscription

```solidity
function cancelSubscription(struct ClockTowerSubscribe.Subscription subscription) external
```

Function that provider uses to cancel subscription

_Will cancel all subscriptions_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| subscription | struct ClockTowerSubscribe.Subscription | Subscription struct |

### createSubscription

```solidity
function createSubscription(uint256 amount, address token, struct ClockTowerSubscribe.Details details, enum ClockTowerSubscribe.Frequency frequency, uint16 dueDay) external payable
```

Function that creates a subscription

_In wei
Token amount must be above token minimum for ERC20 token
Token address must be whitelisted by admin
Details are posted in event logs not storage
0 = Weekly, 1 = Monthly, 2 = Quarterly, 3 = Yearly
The dueDay will be within differing ranges based on frequency._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| amount | uint256 | Amount of ERC20 tokens paid each cycle |
| token | address | ERC20 token address |
| details | struct ClockTowerSubscribe.Details | Details struct for event logs |
| frequency | enum ClockTowerSubscribe.Frequency | Frequency number of cycle |
| dueDay | uint16 | The day in the cycle the subscription is due |

### editDetails

```solidity
function editDetails(struct ClockTowerSubscribe.Details details, bytes32 id) external
```

Change subcription details in event logs

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| details | struct ClockTowerSubscribe.Details | Details struct |
| id | bytes32 | Subscription id in bytes |

### editProvDetails

```solidity
function editProvDetails(struct ClockTowerSubscribe.ProviderDetails details) external
```

Changes Provider details in event logs

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| details | struct ClockTowerSubscribe.ProviderDetails | ProviderDetails struct |

### remit

```solidity
function remit() public payable
```

Transfers tokens from subscribers to provider

_Transfers the oldest outstanding transactions that are past their due date
If system fee is set then the chain token must also be added to the transaction
Each call will transmit either the total amount of current transactions due or the maxRemits whichever is smaller
The function will paginate so multiple calls can be made per day to clear the queue_

## CLOCKToken

### constructor

```solidity
constructor(uint256 initialSupply) public
```

