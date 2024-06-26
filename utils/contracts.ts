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
  evmProvidedGasLimit,
  providedGasLimits,
} from "./constants";
import { HardhatEthersHelpers } from "hardhat/types";

export const getContract = async (
  network: string,
  contract: string,
  ethLib: typeof ethers & HardhatEthersHelpers
) => {
  const address = getContractAddress(network);
  const factory = await getContractFactory(network, contract, ethLib);
  console.log("contract address: ", address);
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
  // i.e. "contracts/mainnet/FroggyFriends.sol:FroggyFriends"
  return `contracts/${network}/${contract}.sol:${contract}`;
};

export const getContractAddress = (network: string): string => {
  return contractAddresses.get(network) || froggyFriendsEth;
};

export const getChainId = (network: string): number => {
  // i.e. 101 is ethereum if no chain id is found
  return chainIds.get(network) || ethChainId;
};

export const getMinGasLimit = (network: string): number => {
  return minGasLimits.get(network) || evmGasLimit;
};

export const getProvidedGasLimit = (network: string): number => {
  return providedGasLimits.get(network) || evmProvidedGasLimit;
};

export const getLzEndpoint = (network: string): string => {
  return lzEndpoints.get(network) || lzEthereumEndpoint;
};
