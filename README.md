# Clocktower

A decentralized system to schedule crypto transactions in the future. 

One of the main limitations of decentralized smart contracts is that they must be acted upon by outside users. This makes it impossible to schedule any actions in the future like you would with a cron job in normal computing. Without the ability to schedule transactions in the future commonplace financial services like payroll, subscriptions, regular payments, and many others become impossible or overly complicated. 

The Clocktower project seeks to solve this issue by acting as a public service unlocking the potential of the future from the limitations of a system stuck in the perpetual present. 

We seek to accomplish this by creating an EVM compliant smart contract that is polled at regularly timed intervals. Users will be able to deposit and schedule transactions at a time of their choosing. By incorporating such features as custom libraries, batch transactions, reversible transactions and ERC20 compatibility we hope to attract not only regular users but unlock the potential of other fintech and defi projects seeking a way to expand what is possible while staying true to the principles of privacy, simplicity and decentralization. 

## Timing System

The Ethereum blockchain in many ways is like a giant decentralized clock currently creating a block every twelve seconds. Amongst the nodes themselves seconds matter as they go through the task of creating blocks and gossiping them to the network. Its therefore ironic that even with this elaborte timing mechanism smart contracts are unable to know what time it is unless asked to, like a person with an expensive watch who can't look at it without being told to. 

There are many ways to measure time in a scheduling system. The most common being Unix Epoch time which is an incrementing count of seconds since Thursday January 1st 1970 0:00. However polling the contract every second would be too expensive as well as not very useful in the context of subscriptions and payments. 

Another option would be using blocks as our time increment. Blocks are sometimes used to represent moments in time on Ethereum based systems. The problem with this approach is that there is no guarantee that a block will be set at twelve seconds in the future.

We have decided to use an hour increment from a somewhat arbitrary point in Epoch Time around when The Merge occurred. None of this is necessarily known by the user who only needs to submit time information in standard Unix Epoch time while the conversions are done internally in the contract. 

It does however mean that hours are the smallest precision you can get for scheduling. We think this appropriate for the type of utility our system offers. 

## Data Structures

## Global Variables

## Functions



```shell
REPORT_GAS=true npx hardhat test
npx hardhat node
npx hardhat run scripts/deploy.ts
```
