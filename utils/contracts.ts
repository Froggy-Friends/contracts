import type { ethers } from "ethers";
import {
  froggyFriendsEth,
  contractAddresses,
  chainIds,
  minGasLimits,
  evmGasLimit,
  ethChainId,
  lzEthereumEndpoint,
  lzEndpoints,
} from "./constants";
import { HardhatEthersHelpers } from "hardhat/types";

export const getContract = async (
  network: string,
  contract: string,
  ethLib: typeof ethers & HardhatEthersHelpers
) => {
  const address = contractAddresses.get(network) || froggyFriendsEth;
  const factory = await getContractFactory(network, contract, ethLib);
  console.log("contract address: ", address);
  console.log("contract factory: ", factory);
  return factory.attach(address);
};

export const getContractFactory = async (
  network: string,
  contract: string,
  ethLib: typeof ethers & HardhatEthersHelpers
) => {
  const contractName = getContractName(network, contract);
  console.log("contract name: ", contractName);
  return ethLib.getContractFactory(contractName);
};

export const getContractName = (network: string, contract: string) => {
  // i.e. "contracts/eth/FroggyFriends.sol:FroggyFriends"
  return `contracts/${network}/${contract}.sol:${contract}`;
};

export const getChainId = (network: string): number => {
  // i.e. 101 is ethereum if no chain id is found
  return chainIds.get(network) || ethChainId;
};

export const getMinGasLimit = (network: string): number => {
  return minGasLimits.get(network) || evmGasLimit;
};

export const getLzEndpoint = (network: string): string => {
  return lzEndpoints.get(network) || lzEthereumEndpoint;
};
