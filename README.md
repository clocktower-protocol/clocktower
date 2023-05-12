# Clocktower

A decentralized system to schedule crypto transactions in the future. 

One of the main limitations of decentralized smart contracts is that they must be acted upon by outside users. This makes it impossible to automatically schedule any actions in the future like you would with a cron job in normal computing. Without the ability to schedule transactions in the future commonplace financial services like payroll, subscriptions, regular payments, and many others become impossible or overly complicated. 

The Clocktower project seeks to solve this issue by acting as a public service unlocking the potential of the future from the limitations of a system stuck in the perpetual present. 

We seek to accomplish this by creating EVM compliant smart contracts that are polled at regularly timed intervals. Users will be able to schedule transactions at a time of their choosing. By incorporating such features as subscriptions, future payments, batch transaction and ERC20 compatibility we hope to unlock the potential of other fintech and defi projects seeking a way to expand what is possible while staying true to the principles of privacy, simplicity and decentralization. 

## Timing System

The Ethereum blockchain in many ways is like a giant decentralized clock, currently creating a block every twelve seconds. For each node, seconds matter, as they go through the task of creating blocks and gossiping them to the network. Its ironic that even with this elaborate timing mechanism smart contracts are unable to know what time it is unless asked, like a person with an expensive watch who can't look at it unless told to. 

There are many ways to measure time in a scheduling system. The most common being Unix Epoch time which is an incrementing count of seconds since Thursday January 1st 1970 0:00. However polling the contract every second would be too expensive as well as not very useful in the context of subscriptions and payments. 

Another option would be using blocks as our time increment. Blocks are sometimes used to represent moments in time on Ethereum based systems. The problem with this approach is that there is no guarantee that a block will be set at twelve seconds in the future.

Things are further complicated when considering that timed transactions need to be set at standard increments. But these increments have differing scopes. For instance, weekly subscription need to be scheduled for a day of the week while a monthly subscription needs a day of the month. And not every month has the same amount of days. 

With this in mind we have chosen the following increments that can represent the most common schedules:

### Allowed Time Ranges

- Weekly Subscriptions -- 1 - 7 (Weekdays)
- Monthly Subscriptions -- 1 - 28 (Day of Month)
- Quarterly Subscriptions -- 1 - 90 (Day of Quarter)
- Yearly Subscription -- 1 - 365 (Day of Year  (not indcluding leap days))

### Future Transaction Range
- Future Transactions -- Unixtime / 3600 (Unix Hours)

## Data Structures
The following are the data structs required by external functions:

### Subscription Data

#### Structs

##### Subscription

```
 struct Subscription {
    bytes32 id;
    uint amount;
    address provider;
    address token;
    bool exists;
    bool cancelled;
    Frequency frequency;
    uint16 dueDay;
    string description;
}
```
| Name | Type | Description|
|---|---|---|
| `id` | bytes32 | Unique hash generated for each subscription |
| `amount` | uint | Amount of subscription in wei |
| `provider` | address | Address of the creator of the subscription |
| `token` | address | ERC20 address of token used in subscription |
| `exists` | bool | True if subscription exists |
| `cancelled` | bool | True if subscription is cancelled |
| `frequency` | Frequency | [Frequency](https://github.com/vhmarx/clocktower#frequency) |
| `dueDay` | uint16 | Day in frequency [range](https://github.com/vhmarx/clocktower#allowed-time-ranges) when subscription is paid |
| `description` | string | Description of subscription |


##### SubView
```
 struct SubView {
    Subscription subscription;
    Status status;
    uint totalSubscribers;
 }
```
| Name | Type | Description|
|---|---|---|
| `subscription` | Subscription | [Subscription](https://github.com/vhmarx/clocktower#subscription) |
| `status` | Status | [Status](https://github.com/vhmarx/clocktower#status) |
| `totalsubscribers` | uint | Total number of subscribers |

##### FeeEstimate
```
struct FeeEstimate {
    uint fee;
    address token;
}
```
| Name | Type | Description|
|---|---|---|
| `fee` | uint | Fee amount in wei |
| `token` | address | ERC20 address of token |

##### SubscriberView
```
struct SubscriberView {
    address subscriber;
    uint feeBalance;
}
```
| Name | Type | Description|
|---|---|---|
| `subscriber` | address | Subscriber address |
| `feeBalance` | uint | Fee balance of subscriber in wei |

#### Enums
(Enum values are represented by numbers starting at zero)

##### Frequency
```
enum Frequency {
    WEEKLY,
    MONTHLY,
    QUARTERLY,
    YEARLY
}
```
| Value | Description|
|---|---|
| `0` | WEEKLY |
| `1` | MONTHLY |
| `2` | QUARTERLY |
| `3` | YEARLY |

##### Status
```
enum Status {
    ACTIVE,
    CANCELLED,
    UNSUBSCRIBED
}
```
| Value | Description|
|---|---|
| `0` | ACTIVE |
| `1` | CANCELLED |
| `2` | UNSUBSCRIBED |

##### SubEvent
```
enum SubEvent {
    PAID,
    FAILED,
    SUBSCRIBED, 
    UNSUBSCRIBED,
    FEEFILL
}
```
| Value | Description|
|---|---|
| `0` | PAID |
| `1` | FAILED |
| `2` | SUBSCRIBED |
| `3` | UNSUBSCRIBED |
| `4` | FEEFILL |

##### ProvEvent
```
enum ProvEvent {
    CREATE,
    CANCEL,
    PAID,
    FAILED
}
```
| Value | Description|
|---|---|
| `0` | CREATE |
| `1` | CANCEL |
| `2` | PAID |
| `3` | FAILED |


## Global Variables
### Subscription Global Variables

| Name | Type | Description| Format |
|---|---|---|---|
| `callerFee` | uint | Percentage paid to caller on remits | 10000 = No fee, 10100 = 1%, 10001 = 0.01% |
| `systemFee` | uint | Flat fee paid to admin account when systemFee bool is true | wei |
| `maxGasPrice` | uint | Maximum gas value for remit function | gwei |
| `maxRemits` | uint | Maximum number of remits per remit function (usually based on block max) | |
| `admin` | address | Address for admin account |
| `lastCheckedDay` | uint40 | Last time remit ws called | Unix epoch time |

## Events
### Subscription Events
##### SubscriberLog
```
event SubscriberLog(
    bytes32 indexed id,
    address indexed subscriber,
    uint40 timestamp,
    uint amount,
    SubEvent indexed subEvent
)
```

Log emitted during subscriber events

| Name | Type | Indexed | Description |
|---|---|:---:|---|
| `id` | bytes32 | :heavy_check_mark: | Unique Subscription id |
| `subscriber` | address | :heavy_check_mark: | Address of subscriber |
| `timestamp` | uint40 | | Unix Epoch timestamp |
| `amount` | uint | | ERC20 subscription amount in wei |
| `subEvent` | SubEvent | :heavy_check_mark: | [SubEvent](https://github.com/vhmarx/clocktower#subevent)

##### CallerLog
```
event CallerLog(
    uint40 timestamp,
    uint40 checkedDay,
    address indexed caller,
    bool isFinished
)
```

Log emitted during Caller events

| Name | Type | Indexed | Description |
|---|---|:---:|---|
| `timestamp` | uint40 | | Unix epoch timestamp |
| `checkedDay` | uint40 | | Day in frequency range checked by Caller |
| `caller` | address | :heavy_check_mark: | Address of caller |
| `isFinished` | bool | | Shows if Caller is done |

##### ProviderLog
```
event ProviderLog(
    bytes32 indexed id,
    address indexed provider,
    uint40 timestamp,
    bool success,
    uint8 errorCode,
    ProvEvent indexed provEvent
)
```

Log emitted during Provider events

| Name | Type | Indexed | Description |
|---|---|:---:|---|
| `id` | bytes32 | :heavy_check_mark: | Unique subscription id |
| `provider` | address | :heavy_check_mark: | Provider address |
| `timestamp` | uint40 | | Unix epoch timestamp |
| `success` | bool | | Shows if event was successful |
| `errorCode` | uint8 | | Errorcode if there was a problem |
| `provEvent` | ProvEvent | :heavy_check_mark: | [ProvEvent](https://github.com/vhmarx/clocktower#provevent) |


## Functions
### Subscription Functions
#### Input Functions
##### createSubscription
```
function createSubscription(
    uint amount,
    address token, 
    string description, 
    Frequency frequency, 
    uint16 dueDay
) external payable
```
Allows provider to create a new subscription. 

Parameters:

| Name | Type | Description |
|---|---|---|
| `amount` | uint | Amount of subscription in wei |
| `token` | address | ERC20 address of token used in subscription |
| `description` | string | Description of subscription |
| `frequency` | Frequency | [Frequency](https://github.com/vhmarx/clocktower#frequency) |
| `dueDay` | uint16 | Day in [range](https://github.com/vhmarx/clocktower#allowed-time-ranges) based on frequency when subscription is paid |

##### subscribe
```
function subscribe(
    Subscription subscription
) external payable
```
Allows user to subscribe to subscription

Parameters: 
| Name | Type | Description |
|---|---|---|
| `subscription` | Subscription | [Subscription](https://github.com/vhmarx/clocktower#subscription) |


##### unsubscribe
```
function unsubscribe(
    bytes32 id
) external payable
```
Allows user to unsubscribe from subscription. 

msg.sender must be subscribed to subscription. 

Parameters:
| Name | Type | Description |
|---|---|---|
| `id` | bytes32 | Unique subscription id |

##### unsubscribeByProvider
```
function unsubscribeByProvider(
    address subscriber, 
    bytes32 id
) external
```
Allows provider to cancel subscriber from their created subscriptions. 

msg.sender must be creator of subscription and subscriber must be subscribed. 

Parameters: 
| Name | Type | Description |
|---|---|---|
| `subscriber` | address | Subscriber address |
| `id` | bytes32 | Unique subscription id |


##### cancelSubscription
```
function cancelSubscription(
    Subscription subscription
) external
```
Allows provider to cancel subscription. All existing subscribers will no longer be charged

msg.sender must be creator of subscription

Parameters: 
| Name | Type | Description |
|---|---|---|
| `subscription` | Subscription | [Subscription](https://github.com/vhmarx/clocktower#subscription) |


#### View Functions
##### getSubscribers
```
function getSubscribers(
    bytes32 id
) external view returns (address[] memory)
```

Returns an array of all subscriber addresses per subscription

Parameters: 
| Name | Type | Description |
|---|---|---|
| `id` | bytes32 | Unique subscription id |

Return Values:
| Name | Type | Description |
|---|---|---|
| `address[]` | address | Array of subscriber addresses |


##### getAccountSubscriptions
```
function getAccountSubscriptions(
    bool bySubscriber
    ) returns (SubView[])
```
Returns an array of objects containing subscription and status

If bySubscriber is true it gets a list of subscriptions msg.sender is subscribed to. 
If false it gets a list of subscriptions msg.sender created as the provider. 

Parameters: 
| Name | Type | Description |
|---|---|---|
| `bySubscriber` | bool | See above description of bool |

Return Values:
| Name | Type | Description |
|---|---|---|
| `SubView[]` | SubView | Array of [Subview](https://github.com/vhmarx/clocktower#subview) structs |

##### getSubscribersById
```
function getSubscribersById(
    bytes32 id
    ) external view returns (SubscriberView[] memory)
```

Returns array of objects containing subscriber info. 

Parameters: 
| Name | Type | Description |
|---|---|---|
| `id` | bytes32 | Unique subscription id |

Return Values:
| Name | Type | Description |
|---|---|---|
| `SubscriberView[]` | SubscriberView | Array of [SubscriberView](https://github.com/vhmarx/clocktower#subscriberview) structs |

##### getSubByIndex
```
function getSubByIndex(
    bytes32 id, 
    Frequency frequency, 
    uint16 dueDay
    ) view public returns(Subscription subscription)
```

Returns subscription object

Parameters: 
| Name | Type | Description |
|---|---|---|
| `id` | bytes32 | Unique subscription id |
| `frequency` | Frequency | [Frequency](https://github.com/vhmarx/clocktower#frequency) |
| `dueDay` | uint16 | Day in [range](https://github.com/vhmarx/clocktower#allowed-time-ranges) based on frequency when subscription is paid |

Return Values:
| Name | Type | Description |
|---|---|---|
| `subscription` | Subscription | [Subscription](https://github.com/vhmarx/clocktower#subscription) |


##### feeEstimate
```
function feeEstimate(

) returns(FeeEstimate[]) 
```
Returns an array of objects showing the next batch of remits and possible fees

Return Values:
| Name | Type | Description |
|---|---|---|
| `FeeEstimate[]` | FeeEstimate | Array of [FeeEstimate](https://github.com/vhmarx/clocktower#feeestimate) structs |

## Error Codes
### Subscription Error Codes
    0 = No error
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

## Future Payments Contract

### Future Payment Data

struct Permit {
    address owner;
    address spender;
    uint value;
    uint deadline;
    uint8 v;
    bytes32 r;
    bytes32 s;
}

struct Batch {
    address payable receiver;
    uint40 unixTime;
    uint payload;
    address token;
}

struct Transaction {
    bytes32 id;
    address sender;
    address payable receiver;
    address token;
    uint40 timeTrigger;
    Status status;
    uint payload;
}

enum Status {
    PENDING,
    SENT,
    FAILED,
    CANCELLED
}

- PENDING = 0
- SENT = 1
- FAILED = 2
- CANCELLED = 3

### Future Payment Functions
#### Input Functions
##### Add Payment
```
addPayment(address receiver, uint40 unixTime, uint payload, address token)
```
Allows user to add future payment. 

Requires 
- Allowance to be set.
##### Add Permit Payment
```
addPermitTransaction(address receiver, uint40 unixTime, uint payload, address token, Permit permit)
```
Allows user to add future payment in one transaction using passed permit object. 
##### Add Batch Payment
```
addBatchPayments(Batch[] batch)
```
Allows user to add a batch future payment using batch object. 

Requires:
- Allowance to be set
- Batch amount must be less than 100 payments
##### Cancel Payment
```
cancelPayment(bytes32 id, uint40 unixTrigger, address token)
```
Allows user to cancel a pending payment

Requires:
- Payment must have been created by user
#### View Functions
##### Get Account Payments
```
getAccountPayments() returns (Transaction[])
```
Returns an array of transaction objects

Requires:
- Only for user's account

```shell
REPORT_GAS=true npx hardhat test
npx hardhat node
npx hardhat run scripts/deploy.ts
```