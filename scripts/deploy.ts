import { ethers, network, upgrades } from "hardhat";
import { lzBaseEndpoint, minGasToTransfer } from "../utils/constants";
import { getContractFactory } from "../utils/contracts";

async function main() {
  console.log("Starting deployment...");
  const factory = await getContractFactory(
    network.name,
    "FroggyFriends",
    ethers
  );
  const [owner] = await ethers.getSigners();
  console.log("\nDeployment Owner: ", owner.address);

  const contract = await upgrades.deployProxy(factory, [
    minGasToTransfer,
    lzBaseEndpoint,
  ]);
  console.log("\nContract Address: ", contract.address);

  await contract.deployed();
  console.log("\nContract deployed...");

  await contract.deployTransaction.wait(5);
  console.log("\nContract deployed with 5 confirmations");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.log(error);
    process.exit(1);
  });
