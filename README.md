# Crypto-Collateralized Stablecoin (WETH & WBTC)

## Overview

This project implements a decentralized, exogenously collateralized, algorithmically stabilized stablecoin pegged to USD. The stablecoin is backed by wrapped Ethereum (WETH) and wrapped Bitcoin (WBTC). The system ensures over-collateralization to maintain stability and prevent insolvency.

## Features

- **Exogenous Collateralization**: Supports WETH & WBTC as collateral.
- **Over-Collateralization**: Ensures the total value of collateral is always higher than the stablecoin supply.
- **Decentralized Governance**: Uses smart contract-based rules to manage minting, burning, deposits, and liquidations.
- **Price Stability**: Maintains a $1 peg by ensuring proper collateralization.
- **Liquidation Mechanism**: Ensures users remain solvent through an enforced health factor.

## Smart Contracts

### 1. **DecentralizedStableCoin.sol**

- Implements ERC20 with burn functionality.
- Only the DSCEngine can mint and burn tokens.
- Ensures that minted amounts follow protocol rules.

### 2. **DSCEngine.sol**

- Manages collateral deposits, withdrawals, and DSC minting.
- Enforces liquidation rules based on health factors.
- Uses Chainlink price oracles for asset valuation.
- Ensures the stablecoin remains over-collateralized.

### 3. **OracleLib.sol**

- Provides Chainlink price feed validation.
- Ensures price data is not stale before usage.

## Installation & Setup

### Prerequisites

- [Foundry](https://book.getfoundry.sh/getting-started/installation) (for testing and deployment)
- Node.js & npm (for scripts, if required)

### Steps

1. Clone the repository:
   ```sh
   git clone https://github.com/Arbiter09/Crypto-Collateralized-Stablecoin-WETH-WBTC-.git
   cd Crypto-Collateralized-Stablecoin-WETH-WBTC-
   ```
2. Install dependencies:
   ```sh
   forge install
   ```
3. Set up environment variables:
   ```sh
   cp .env.example .env
   ```
   - Add your private key in `.env` for deployment on live networks.

## Usage

### Deploying Contracts

Run the deploy script:

```sh
forge script script/DeployDSC.s.sol --broadcast --rpc-url YOUR_RPC_URL
```

### Interacting with the Stablecoin

- **Deposit collateral**:
  ```solidity
  engine.depositCollateral(address(weth), amount);
  ```
- **Mint DSC**:
  ```solidity
  engine.mintDsc(amount);
  ```
- **Burn DSC**:
  ```solidity
  engine.burnDsc(amount);
  ```
- **Redeem collateral**:
  ```solidity
  engine.redeemCollateral(address(weth), amount);
  ```
- **Liquidate insolvent accounts**:
  ```solidity
  engine.liquidate(address(weth), user, debtToCover);
  ```

## Testing

### Running Tests

To execute the test suite, run:

```sh
forge test
```

### Test Structure

#### **Unit Tests** (`unit/DSCEngineTest.t.sol`)

- Tests core functionalities of DSCEngine and DSC.
- Checks minting, burning, collateral deposits, and liquidation mechanisms.

#### **Fuzz Tests** (`fuzz/Handler.t.sol`)

- Uses random inputs to test edge cases for minting and redeeming collateral.

#### **Invariant Tests** (`fuzz/Invariants.t.sol`)

- Ensures the protocol remains over-collateralized at all times.

## License

This project is licensed under the **MIT License**.

## Acknowledgments

- Inspired by MakerDAO's DAI.
- Uses Foundry for Solidity development and testing.
- Uses OpenZeppelin's ERC20 implementation.
