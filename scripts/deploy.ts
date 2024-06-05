import { ethers, run, upgrades } from "hardhat";

const lzMainnet = "0x66A71Dcef29A0fFBDBE3c6a460a3B5BC225Cd675";
const lzSepolia = "0x7cacBe439EaD55fa1c22790330b12835c6884a91";
const lzHolesky = "0x4e08B1F1AC79898569CfB999FB92B5495FB18A2B";
const lzBase = "0xb6319cC6c8c27A8F5dAF0dD3DF91EA35C4720dd7";

async function main() {
  console.log("Starting deployment...");
  const FroggyFriends = await ethers.getContractFactory("base/FroggyFriends");
  const [owner] = await ethers.getSigners();
  console.log("\nDeployment Owner: ", owner.address);

  const _minGasToTransfer = 100000;
  const _lzEndpoint = lzMainnet;
  const froggyFriends = await upgrades.deployProxy(FroggyFriends, [
    _minGasToTransfer,
    _lzEndpoint,
  ]);
  console.log("\nContract Address: ", froggyFriends.address);

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
