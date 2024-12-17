import { HardhatRuntimeEnvironment as HRE, TaskArguments } from "hardhat/types";
import { getContractAddress, getContractFactory } from "../utils/contracts";

// Publishes new implementation contract and updates proxy contract to use it
export async function upgrade(taskArgs: TaskArguments, hre: HRE) {
  const { contract } = taskArgs;
  const { ethers, network, upgrades } = hre;

  console.log(`Upgrading ${contract} contract on ${network.name}...`);

  const factory = await getContractFactory(network.name, contract, ethers);
  const [owner] = await ethers.getSigners();
  console.log("Deployer: ", owner.address);

  const address = getContractAddress(network.name);
  console.log("Address: ", address);
  const instance = await upgrades.upgradeProxy(address, factory, {
    timeout: 0,
  });
  console.log("Upgraded contract address: ", instance.address);

  await instance.deployed();

  console.log(`Upgraded ${contract} contract on ${network.name}!`);
}
