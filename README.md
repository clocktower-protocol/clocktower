# Clocktower

A decentralized system to schedule crypto transactions in the future. 

 ## Testing

 First install npm library libraries by running the following command within the clocktower directory:

 `npm install`

 Next in order to get gas calculations and fork data to work, create a `.env` file based on the template of the file labled `.env.example`. Provide your own keys. 

 If you want to test with a network fork. Make sure `FORK_DATA_SOURCE` is provided in the `.env` file and the networks->forking->enabled value in `hardhat.config.ts` is set to `true`.

 To run the tests use the following command:

`npx hardhat test`

### Troubleshooting

Sometimes an issue can occur with broken artifacts or cache this usually can be resolved by running:

`npx hardhat clean`
 
