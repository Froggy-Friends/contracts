# Froggy Friends Upgradeable Contracts

The Froggy Friends upgradeable contracts are [Layer Zero](https://layerzero.network) Omnichain Non Fungible Tokens (ONFTs).  
Contracts are built with [Hardhat](https://hardhat.org/) tooling using the upgradeable proxy pattern.  
By importing the hardhat `upgrades` package in `scripts/deploy.ts` and using `upgrades.deployProxy` we are using the [transparent proxy](https://docs.openzeppelin.com/upgrades-plugins/1.x/proxies#transparent-proxies-and-function-clashes) pattern for upgradeable proxies.

## Important Notes

Tasks in the [tasks] folder depend on the folder names in [contracts]. Changing the contract folder names will break the tasks and they will need to be updated.

## Building

> npm run compile

Building generates these new folders:

```
artifacts - compiled smart contracts
cache - cached solidity dependency files i.e. openzeppelin
types - tyepscript types for compiled contracts
```

## Testing

> npm run test

## Deployment

> npm run deploy

This npm shortcut in package.json runs the command:
`npx hardhat run scripts/deploy.ts --network mainnet`

Change the network argument to deploy to a different chain:

```
--network base
--network blast
--network sepolia
```

## Upgrades

> npm run upgrade

Similar to the deploy command, change the --network argument to upgrade contract on a different chain.
