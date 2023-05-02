# Amplifi Deployment

## Setup local test environment

### start a local anvil node fork the main BSC chain

```shell
amplifi-v1-deployment> source env/anvil.env
amplifi-v1-deployment> anvil --rpc-url=$FORK_PRC --fork-block-number=$FORK_BLOCK_NUMBER
```

We do not change the chainId of forked BSC chain which is `56`, try to change chainId to whatever you perfer if it mess up any metamask settings. chainId could be changed with following parameter when starting anvil node.

```shell
amplifi-v1-deployment> anvil --rpc-url=$FORK_PRC --fork-block-number=$FORK_BLOCK_NUMBER --chain-id=203
```

### deploy contracts to local test network

Run following command.

```shell
amplifi-v1-deployment> forge script script/01_Deploy.s.sol:Deploy --rpc-url="http://localhost:8545" --broadcast
```

The command not only deployed all amplifi contract to local network, but also finished following tasks:

1. Deployed three more test ERC20 contract (WBNB/WETH/USDC);
2. Setup there pancake swap pool (WBNB-PUD/WBNB-WETH/WBNB-USDC);
3. Added token info into registrar contract.

All contract address deployed should be logged in the file `env/contracts.env`, also useful contract address would have had be print out in the console during the deploying.
