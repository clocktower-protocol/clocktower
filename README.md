# Clocktower

A decentralized subscription protocol for scheduling crypto transactions in the future. Clocktower enables automated recurring payments and subscriptions on the blockchain with support for multiple ERC20 tokens.

## 🏗️ Architecture

Clocktower consists of two main smart contracts:

### Core Contracts

- **`ClockTowerSubscribe.sol`** - Main subscription protocol contract
- **`ClockTowerTimeLibrary.sol`** - Time calculation utilities

### Key Features

- **Multi-token Support**: Accepts any approved ERC20 token for subscriptions
- **Flexible Billing Cycles**: Weekly, Monthly, Quarterly, and Yearly subscriptions
- **Automated Payments**: Scheduled transaction execution with fee incentives
- **Prorated Refunds**: Automatic calculation of partial refunds for early cancellations
- **Access Control**: Role-based permissions for admin functions
- **Gas Optimization**: Efficient pagination for large subscription batches

## 📋 Prerequisites

- Node.js (v16 or higher)
- npm or yarn
- Hardhat development environment
- Ethereum wallet (for deployment)

## 🚀 Quick Start

### 1. Installation

```bash
# Clone the repository
git clone <repository-url>
cd clocktower

# Install dependencies
npm install
```

### 2. Environment Setup

Create a `.env` file in the root directory with the following variables:

```env
# Network URLs
ALCHEMY_SEPOLIA_BASE_URL=your_alchemy_sepolia_base_url
ALCHEMY_BASE_URL=your_alchemy_base_url

# Deployer Addresses
SEPOLIA_BASE_DEPLOYER_ADDRESS=your_sepolia_base_deployer_address
BASE_DEPLOYER_ADDRESS=your_base_deployer_address

# API Keys (optional)
COINMARKETCAP_API_KEY=your_coinmarketcap_api_key
ETHERSCAN_KEY=your_etherscan_api_key

# Fork Configuration (optional)
FORK_DATA_SOURCE=your_fork_data_source_url
```

### 3. Compilation

```bash
# Compile contracts
npx hardhat compile
```

### 4. Testing

```bash
# Run all tests
npx hardhat test

# Run tests with gas reporting
npx hardhat test --gas
```

### 5. Local Development

```bash
# Start local Hardhat node
npx hardhat node
```

## 🧪 Testing

The test suite covers comprehensive functionality including:

- Subscription creation and management
- Payment processing and fee calculations
- Time-based operations and proration
- Access control and permissions
- Error handling and edge cases

### Test Structure

```bash
test/
└── Clocktower.ts          # Main test suite
```

### Running Specific Tests

```bash
# Run specific test file
npx hardhat test test/Clocktower.ts

# Run with verbose output
npx hardhat test --verbose
```



## 📖 Smart Contract Documentation

For detailed smart contract documentation, including function signatures, events, and technical specifications, please visit [clocktower.finance](https://clocktower.finance).



## 🔧 Configuration

### Hardhat Configuration

The project uses Hardhat with the following plugins:

- **@nomicfoundation/hardhat-toolbox** - Development tools
- **hardhat-abi-exporter** - ABI export functionality
- **hardhat-contract-sizer** - Contract size analysis
- **solidity-docgen** - Documentation generation

## 🛠️ Development

### Project Structure

```
clocktower/
├── contracts/              # Smart contracts
│   ├── ClockTowerSubscribe.sol
│   └── ClockTowerTimeLibrary.sol
├── test/                   # Test files
├── scripts/                # Deployment scripts
├── ignition/               # Ignition deployment modules
├── docs/                   # Generated documentation
├── abi/                    # Contract ABIs
└── artifacts/              # Compiled contracts
```



## 📄 License

This project is licensed under the BUSL-1.1 License - see the [LICENSE](LICENSE) file for details.



## 🔗 Links

- **Website**: [clocktower.finance](https://clocktower.finance) - Official documentation and resources
- **Tests**: [test/Clocktower.ts](test/Clocktower.ts)
 
