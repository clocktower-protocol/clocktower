import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";
import "@nomicfoundation/hardhat-ledger";
import hre from "hardhat"

export default buildModule("ClocktowerHardhat", (m) => {
    

    //(xX100)+10000
    const chainObjects = {
        hardhat: {
            callerFee: ((BigInt(process.env.HARDHAT_CALLER_FEE) * 100n) + 10000n),
            systemFee: hre.ethers.parseEther(process.env.HARDHAT_SYSTEM_FEE),
            maxRemits: process.env.HARDHAT_MAX_REMITS,
            allowSystemFee: process.env.HARDHAT_ALLOW_SYSTEM_FEE,
            admin: process.env.HARDHAT_ADMIN_ADDRESS,
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
            callerFee: ((BigInt(process.env.SEPOLIA_CALLER_FEE) * 100n) + 10000n),
            systemFee: hre.ethers.parseEther(process.env.SEPOLIA_SYSTEM_FEE),
            maxRemits: process.env.SEPOLIA_MAX_REMITS,
            allowSystemFee: process.env.SEPOLIA_ALLOW_SYSTEM_FEE,
            admin: process.env.SEPOLIA_ADMIN_ADDRESS,
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