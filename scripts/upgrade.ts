import { ethers, upgrades } from "hardhat";

async function main() {
    console.log("Starting deployment...");
    const FroggyFriends = await ethers.getContractFactory("FroggyFriends");
    const [owner] = await ethers.getSigners();
    console.log("\nDeployment Owner: ", owner.address);

    const froggyFriends = (await upgrades.upgradeProxy('0x29Fe598F004685c15B91E05bb8401062F45E0355', FroggyFriends, { timeout: 0 }));
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