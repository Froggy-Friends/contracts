import { ethers, upgrades, run } from "hardhat";

async function main() {
  console.log("Starting deployment...");
  const FroggyFriends = await ethers.getContractFactory("contracts/mainnet/FroggyFriends.sol:FroggyFriends");
  const [owner] = await ethers.getSigners();
  console.log("\nDeployment Owner: ", owner.address);

  const froggyFriends = (await upgrades.upgradeProxy('0x7ad05c1b87e93BE306A9Eadf80eA60d7648F1B6F', FroggyFriends, { timeout: 0 }));
  console.log("\nUpgraded contract address: ", froggyFriends.address);

  await froggyFriends.deployed();
  console.log("\nContract deployed...");

  await froggyFriends.deployTransaction.wait(5);
  console.log("\nContract deployed with 5 confirmations");

  console.log('\Verifying contract code on Etherscan...');
  await run("verify:verify",
    {
      address: froggyFriends.address,
      constructorArguments: []
    });
}

main()
  .then(() => process.exit(0))
  .catch(error => {
    console.log(error);
    process.exit(1);
  });