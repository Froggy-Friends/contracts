import { ethers, upgrades, run } from "hardhat";

const mainnet = "0x7ad05c1b87e93BE306A9Eadf80eA60d7648F1B6F";
const sepolia = "0xc8939011efd81fB0ca8382ed15EAb160c3a69313";
const goerli = "0xbC0dB73837A2448FDd984835B598D5f8288D8ad0";
const holesky = "0x29Fe598F004685c15B91E05bb8401062F45E0355";

async function main() {
  console.log("Starting deployment...");
  const FroggyFriends = await ethers.getContractFactory("FroggyFriends");
  const [owner] = await ethers.getSigners();
  console.log("\nDeployment Owner: ", owner.address);

  const froggyFriends = await upgrades.upgradeProxy(mainnet, FroggyFriends, {
    timeout: 0,
  });
  console.log("\nUpgraded contract address: ", froggyFriends.address);

  await froggyFriends.deployed();
  console.log("\nContract deployed...");

  await froggyFriends.deployTransaction.wait(5);
  console.log("\nContract deployed with 5 confirmations");

  console.log("Verifying contract code on Etherscan...");
  await run("verify:verify", {
    address: froggyFriends.address,
    constructorArguments: [],
  });
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.log(error);
    process.exit(1);
  });
