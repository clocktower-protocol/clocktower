# Clocktower

A decentralized system to schedule crypto transactions in the future. 



As services on the web proliferate, subscription payment systems have become an important source of recurring revenue for digital content providers. Centralized payment services have reduced the friction of payments on the web, and have made traditional forms of payment (credit/debit/bank transfer) common and simple. However, this convenience comes at a price--online content and providers frequently pay [more than 3% for this functionality](https://www.helcim.com/visa-usa-interchange-rates/) and these costs are passed to the consumer. Payment platforms have become the front-line for censorship of people and ideas on the web, inspiring some to [leave popular crowdfunding platorms in favor of their own platforms](https://www.businessinsider.com/sam-harris-deletes-patreon-account-after-platform-boots-conservatives-2018-12). While the major payment networks have generally not taken an activist role in online political speech, they remain a potential choke-point for free speech and an open internet.

A possible solution lies outside the traditional payment system in the realm of cryptocurrency. Ethereum's decentralized network and stablecoins could be used to make recurring payments to content creators and other service providers, although there are technical challenges to overcome. One of the main limitations of decentralized smart contracts is that they must be acted upon by outside users. This makes it impossible to schedule actions in the future, as with a cron job in normal computing. Without the ability to schedule transactions in the future, common financial services like payroll, subscriptions, regular payments, and many others become impossible or overly complicated. 

The Clocktower project seeks to solve this problem by acting as a public service unlocking the potential of the future from the limitations of a system stuck in the perpetual present. 

We seek to accomplish this by creating EVM-compliant smart contracts that are polled at regularly timed intervals. Users will be able to schedule transactions at a future time of their choosing. Other By incorporating such features as subscriptions, future payments, batch transactions, reversible transactions and ERC20 compatibility, we hope to unlock the potential of other fintech and defi projects seeking a way to expand what is possible while staying true to the principles of privacy, simplicity and decentralization. 


## Timing System

In a sense, the Ethereum blockchain is like a giant decentralized clock, currently creating a block every twelve seconds. For each node, seconds matter, as they go through the task of creating blocks and gossiping them to the network. Its therefore ironic that even with this elaborate timing mechanism smart contracts are unable to know what time it is unless asked, like a person with an expensive watch who can't look down at it unless told to do so.

There are many ways to measure time in a scheduling system, the most common being Unix Epoch time which has been incrementing seconds since Thursday January 1st 1970 0:00. However, polling the contract every second would be too expensive and inefficent in the context of subscriptions and payments. 

Another option would be using Ethereum blocks themselves as our time increment. Blocks are sometimes used to represent moments in time on Ethereum based systems. The problem with this approach is that there is no guarantee that a block will be set at twelve seconds in the future and one of the critical goals of Clocktower is to eventually be able to schedule transactions years into the future.

The situation is further complicated when considering that timed transactions need to be set at standard increments. But these increments, or time triggers as we call them, have differing scopes. For instance, a weekly subscription needs to be scheduled for a day of the week while a monthly subscription needs a day of the month. And not every month has the same number of days. 

With this in mind we have chosen the following standard time trigger ranges that can represent the most common schedules:

- Future Transactions -- Unixtime / 3600 (Unix Hours)
- Weekly Subscriptions -- 1 - 7 (Weekdays)
- Monthly Subscriptions -- 1 - 28 (Day of Month)
- Quarterly Subscriptions -- 1 - 90 (Day of Quarter)
- Yearly Subscription -- 1 - 365 (Day of Year  (not indcluding leap days))


## Protocol Overview

The Clocktower system begins with a provider configuring basic parameters of a paid web service they would like to provide at a fixed interval (weekly, monthly, yearly, etc). This could be done through direct interaction with the contract or, in most circumstances, through a web front-end. After signing the transaction, the subscription is now available to anyone who would like to become a subscriber. Off-chain, provider advertises service to potential subscribers and can send a link for signup. When a potential subscriber wants to signup, they sign two transactions. The first gives unlimited allowance to the contract to take a preferred ERC20 token from the wallet. The second approves the subscription and pays the first interval payment in addition to filling the fee balance for the account. The fee will be kept as low as possible while still incentivizing a population of Callers to call the remit function on the clocktower contract. As long as this balance has sufficient funding to cover the fees and the subscription price, a given subscriber will continue to be in good standing and current. If there is not enough to cover the subscription, but enough to cover the fee, the fee will be taken until the account can no longer cover the fee. At this point, clocktower will automatically remove this account from the list of active subsciptions.








