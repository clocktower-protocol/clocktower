import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";
import hre from "hardhat"

export default buildModule("ClocktowerHardhat", (m) => {
    
    const chainObjects = {
        hardhat: {
            callerFee: 10200n,
            systemFee: 10000000000000000n,
            maxRemits: 5n,
            allowSystemFee: false,
            admin: '0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266',
            erc20: [
                {
                    name: 'Clocktower Token',
                    ticker: 'CLOCK',
                    address: '',
                    tokenMinimum: hre.ethers.parseEther("0.01")
                }
            ]
        },
        sepolia: {
            callerFee: 10100n,
            systemFee: 10000000000000000n,
            maxRemits: 5n,
            allowSystemFee: false,
            admin: '0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266',
            erc20: [
                {
                    name: 'USDC',
                    ticker: 'USDC',
                    address: '0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238',
                    tokenMinimum: hre.ethers.parseEther("5")
                }, 
                {
                    name: 'Tether',
                    ticker: 'USDT',
                    address: '0x7169D38820dfd117C3FA1f22a697dBA58d90BA06',
                    tokenMinimum: hre.ethers.parseEther("5")
                }, 
            ]
        },

        
    }

    

    //****comment out deployments not currently being used****

    //hardhat deployment 
        const clockSubscribe = m.contract("ClockTowerSubscribe", [chainObjects.hardhat.callerFee, chainObjects.hardhat.systemFee, chainObjects.hardhat.maxRemits, chainObjects.hardhat.allowSystemFee, chainObjects.hardhat.admin])

    //sepolia deployment
        /*
        const clockSubscribe = m.contract("ClockTowerSubscribe", [chainObjects.sepolia.callerFee, chainObjects.sepolia.systemFee, chainObjects.sepolia.maxRemits, chainObjects.sepolia.allowSystemFee, chainObjects.sepolia.admin])

        //adds ERC20 tokens
        for( let i = 0; i < chainObjects.sepolia.erc20.length; i++) {
            m.call(clockSubscribe, "addERC20Contract", [chainObjects.sepolia.erc20[i].address, chainObjects.sepolia.erc20[i].tokenMinimum])
        }
        */


    return { clockSubscribe }
})