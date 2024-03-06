import { ethers, upgrades } from "hardhat";

async function main() {
    console.log("Starting deployment...");
    const FroggyFriends = await ethers.getContractFactory("FroggyFriends");
    const [owner] = await ethers.getSigners();
    console.log("\nDeployment Owner: ", owner.address);

    // deploy upgrade
    const froggyFriends = (await upgrades.upgradeProxy('0x7ad05c1b87e93BE306A9Eadf80eA60d7648F1B6F', FroggyFriends));

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