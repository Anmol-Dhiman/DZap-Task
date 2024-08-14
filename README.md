# DZap Smart Contract Task

### Task Description

- Staking NFT and get rewards per block
- Staking should be pausable
- user can claim rewards after a delay time
- user can withdraw nft after delay time
- owner can change rewards per block, claim delay, withdraw delay

### Deployment Scripts

```solidity
# To load the variables in the .env file
source .env

# To deploy and verify staking contract
forge script --chain sepolia script/StakingTask.s.sol --rpc-url $SEPOLIA_RPC_URL --broadcast --verify -vvvv

# To deploy and verify mockNFT contract
forge script --chain sepolia script/MockNFT.s.sol --rpc-url $SEPOLIA_RPC_URL --broadcast --verify -vvvv

```

### Test scripts

```solidity
forge test
```

### Deployed Contract (Sepolia)

- StakingContract : <a href="https://sepolia.etherscan.io/address/0x600f947a88caf40eb57c2d8f501e781c4241e6a1#code">0x600f947A88caF40eb57c2d8f501E781C4241E6A1</a>

- MockNFT : <a href="https://sepolia.etherscan.io/address/0x06F1E088FD03CFb779B9df404B4394Bb613af3F4#code">0x06F1E088FD03CFb779B9df404B4394Bb613af3F4</a>

### Test Results

![Test Outputs](images/testOutput.png)
