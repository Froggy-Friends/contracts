import { HardhatRuntimeEnvironment as HRE, TaskArguments } from "hardhat/types";
import { getContractFactory, getLzEndpoint } from "../utils/contracts";
import { minGasToTransfer } from "../utils/constants";

// Call once per chain to wire them together i.e. once on mainnet, once on base, etc.
export async function publish(taskArgs: TaskArguments, hre: HRE) {
  const { contract } = taskArgs;
  const { ethers, network, upgrades } = hre;

  console.log(`Deploying ${contract} contract to ${network.name}...`);

  const factory = await getContractFactory(network.name, contract, ethers);
  const [owner] = await ethers.getSigners();
  const lzEndpoint = getLzEndpoint(network.name);
  console.log("Deployer: ", owner.address);
  console.log("minGasToTransfer: ", minGasToTransfer);
  console.log("lzEndpoint: ", lzEndpoint);

  try {
    const instance = await upgrades.deployProxy(factory, [
      minGasToTransfer,
      lzEndpoint,
    ]);

    console.log("Contract address: ", instance.address);

    await instance.waitForDeployment();

    console.log(`Deployed ${contract} contract to ${network.name}!`);
  } catch (error: any) {
    console.error("Deployment failed:", error);
    if (error.reason) {
      console.error("Revert reason:", error.reason);
    }
  }
}
