# Clocktower

A decentralized system to schedule crypto transactions in the future. 

One of the main limitations of decentralized smart contracts is that they must be acted upon by outside users. This makes it impossible to schedule any actions in the future like you would with a cron job in normal computing. Without the ability to schedule transactions in the future commonplace financial services like payroll, subscriptions, timed gifts and many others become impossible or overly complicated. 

The Clocktower project seeks to solve this issue by acting as a public service unlocking the potential of the future from the limitations of a system stuck in the perpetual present. 

We seek to accomplish this by creating an EVM compliant smart contract that is polled at regular timed intervals. Users will be able to deposit and schedule transactions at a time of their choosing. By incorporating such features as custom libraries, batch transactions, reversible transactions and ERC20 compatibility we hope to attract not only regular users but unlock the potential of other fintech and defi projects seeking a way to expand what is possible while staying true to the principles of privacy, simplicity and decentralization. 

## Timing System

## Data Structures

## Global Variables

## Functions



```shell
REPORT_GAS=true npx hardhat test
npx hardhat node
npx hardhat run scripts/deploy.ts
```
