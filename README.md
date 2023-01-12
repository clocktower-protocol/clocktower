# Clocktower

A decentralized system to schedule crypto transactions in the future. 

One of the main limitations of decentralized smart contracts is that they must be acted upon by outside users. This makes it impossible to schedule any actions in the future like you would with a cron job in normal computing. Without the ability to schedule transactions in the future commonplace financial services like payroll, subscriptions, regular payments, and many others become impossible or overly complicated. 

The Clocktower project seeks to solve this issue by acting as a public service unlocking the potential of the future from the limitations of a system stuck in the perpetual present. 

We seek to accomplish this by creating EVM compliant smart contracts that are polled at regularly timed intervals. Users will be able to schedule transactions at a time of their choosing. By incorporating such features as subscriptions, future payments, batch transactions, reversible transactions and ERC20 compatibility we hope to unlock the potential of other fintech and defi projects seeking a way to expand what is possible while staying true to the principles of privacy, simplicity and decentralization. 

## Timing System

The Ethereum blockchain in many ways is like a giant decentralized clock, currently creating a block every twelve seconds. For each node, seconds matter, as they go through the task of creating blocks and gossiping them to the network. Its therefore ironic that even with this elaborate timing mechanism smart contracts are unable to know what time it is unless asked, like a person with an expensive watch who can't look at it unless told to. 

There are many ways to measure time in a scheduling system. The most common being Unix Epoch time which is an incrementing count of seconds since Thursday January 1st 1970 0:00. However polling the contract every second would be too expensive as well as not very useful in the context of subscriptions and payments. 

Another option would be using blocks as our time increment. Blocks are sometimes used to represent moments in time on Ethereum based systems. The problem with this approach is that there is no guarantee that a block will be set at twelve seconds in the future.

Things are further complicated when considering that timed transactions need to be set at standard increments. But these increments, or time triggers as we call them, have differing scopes. For instance,weekly subscription need to be scheduled for a day of the week while a monthly subscription needs a day of the month. And not every month has the same amount of days. 

With this in mind we have chosen the following time trigger ranges that can represent the most common schedules:

- Future Transactions -- Unixtime / 3600 (Unix Hours)
- Weekly Subscriptions -- 1 - 7 (Weekdays)
- Monthly Subscriptions -- 1 - 28 (Day of Month)
- Quarterly Subscriptions -- 1 - 90 (Day of Quarter)
- Yearly Subscription -- 1 - 365 (Day of Year  (not indcluding leap days))

## Data Structures

## Global Variables


## Functions
### Subscription Functions
#### Create Subscription
```
createSubscription(uint amount, address token, string description, Frequency frequency, uint16 dueDay)
```
Description: Allows provider to create a new subscription. 

Frequency Options
- Weekly
- Monthly
- Quarterly
- Yearly

DueDay Ranges
- Weekly Subscriptions -- 1 - 7 (Weekdays)
- Monthly Subscriptions -- 1 - 28 (Day of Month)
- Quarterly Subscriptions -- 1 - 90 (Day of Quarter)
- Yearly Subscription -- 1 - 365 (Day of Year  (not indcluding leap days))
#### Cancel Subscription
```
cancelSubscription(Subscription subscription)
```
Description: Allows provider to cancel subscription. All existing subscribers will no longer be charged
#### Subscribe
```
subscribe(Subscription subscription)
```
Description: Allows user to subscribe to subscription
#### Unsubscribe
```
unsubscribe(bytes32 id)
```
Description: Allows user to unsubscribe to subscription




```shell
REPORT_GAS=true npx hardhat test
npx hardhat node
npx hardhat run scripts/deploy.ts
```
