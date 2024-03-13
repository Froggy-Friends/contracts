import { ethers, upgrades } from "hardhat";

async function main() {
    console.log("Starting deployment...");
    const FroggyFriends = await ethers.getContractFactory("FroggyFriends");
    const [owner] = await ethers.getSigners();
    console.log("\nDeployment Owner: ", owner.address);

    const froggyFriends = (await upgrades.upgradeProxy('0x586bd2155BDb9E9270439656D2d520A54e6b9448', FroggyFriends, { timeout: 0 })); // holesky
    // const froggyFriends = (await upgrades.upgradeProxy('0x7ad05c1b87e93BE306A9Eadf80eA60d7648F1B6F', FroggyFriends, { timeout: 0 })); //mainnet
    console.log("\nUpgraded contract address: ", froggyFriends.address);

    await froggyFriends.deployed();
    console.log("\nContract deployed...");

    await froggyFriends.deployTransaction.wait(5);
    console.log("\nContract deployed with 5 confirmations");
}

main()
    .then(() => process.exit(0))
    .catch(error => {
        console.log(error);
        process.exit(1);
    });