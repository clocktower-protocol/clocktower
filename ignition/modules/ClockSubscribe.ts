import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";
import "@nomicfoundation/hardhat-ledger";
import hre from "hardhat"

export default buildModule("ClocktowerHardhat", (m) => {

    const customMaxFeePerGas = 50_000_000_000n
    const custommaxPriorityFeePerGas = 3_000_000_000n

    //converts env variables to boolean
    function convertENVBool(env_value:string) {
        let envBool:boolean = true
        if(env_value === "false"){
            envBool = false
        }
        return envBool
    }
    
    //(xX100)+10000
    const chainObjects = {
        hardhat: {
            callerFee: ((BigInt(process.env.HARDHAT_CALLER_FEE) * 100n) + 10000n),
            systemFee: ((BigInt(process.env.HARDHAT_SYSTEM_FEE) * 100n) + 10000n),
            maxRemits: BigInt(process.env.HARDHAT_MAX_REMITS),
            cancelLimit: BigInt(process.env.HARDHAT_CANCEL_LIMIT),
            allowSystemFee: convertENVBool(process.env.HARDHAT_ALLOW_SYSTEM_FEE),
            admin: process.env.HARDHAT_ADMIN_ADDRESS,
            janitor: process.env.HARDHAT_JANITOR_ADDRESS,
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
            systemFee: ((BigInt(process.env.SEPOLIA_SYSTEM_FEE) * 100n) + 10000n),
            maxRemits: BigInt(process.env.SEPOLIA_MAX_REMITS),
            cancelLimit: BigInt(process.env.SEPOLIA_CANCEL_LIMIT),
            allowSystemFee: convertENVBool(process.env.SEPOLIA_ALLOW_SYSTEM_FEE),
            admin: process.env.SEPOLIA_ADMIN_ADDRESS,
            janitor: process.env.SEPOLIA_JANITOR_ADDRESS,
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
        const clockSubscribe = m.contract(
            "ClockTowerSubscribe", 
            [chainObjects.hardhat.callerFee, chainObjects.hardhat.systemFee, chainObjects.hardhat.maxRemits, chainObjects.hardhat.cancelLimit, chainObjects.hardhat.allowSystemFee, chainObjects.hardhat.admin, chainObjects.hardhat.janitor]
        )

    //sepolia deployment
        
    /*
        const clockSubscribe = m.contract("ClockTowerSubscribe", [chainObjects.sepolia.callerFee, chainObjects.sepolia.systemFee, chainObjects.sepolia.maxRemits, chainObjects.sepolia.cancelLimit, chainObjects.sepolia.allowSystemFee, chainObjects.sepolia.admin, chainObjects.sepolia.janitor])

        //adds ERC20 tokens
        for( let i = 0; i < chainObjects.sepolia.erc20.length; i++) {
            m.call(clockSubscribe, "addERC20Contract", [chainObjects.sepolia.erc20[i].address, chainObjects.sepolia.erc20[i].tokenMinimum])
        }

    */
        


    return { clockSubscribe }
})