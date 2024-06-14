import { HardhatRuntimeEnvironment as HRE, TaskArguments } from "hardhat/types";
import { getContractFactory, getLzEndpoint } from "../utils/contracts";
import { minGasToTransfer } from "../utils/constants";

// Call once per chain to wire them together i.e. once on mainnet, once on base, etc.
export async function deploy(taskArgs: TaskArguments, hre: HRE) {
  const { contract } = taskArgs;
  const { ethers, network, upgrades } = hre;

  console.log(`Deploying ${contract} contract to ${network.name}...`);

  const factory = await getContractFactory(network.name, contract, ethers);
  const [owner] = await ethers.getSigners();
  console.log("Deployer: ", owner.address);

  const instance = await upgrades.deployProxy(factory, [
    minGasToTransfer,
    getLzEndpoint(network.name),
  ]);
  console.log("Contract address: ", instance.address);

  await instance.deployed();

  console.log(`Deployed ${contract} contract to ${network.name}!`);
}
