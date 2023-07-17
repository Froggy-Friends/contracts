import { ethers } from "hardhat";
import * as snapshot from '../snapshot.json';

async function main() {
    console.log("Starting airdrops...");
    const FroggyFriends = await ethers.getContractFactory("FroggyFriends");
    const froggyFriends = await FroggyFriends.attach("0xbC0dB73837A2448FDd984835B598D5f8288D8ad0");

    // airdrop supply
    const { wallets, tokenIds } = snapshot;
    console.log('total wallets: ', wallets.length);
    console.log('total tokens: ', tokenIds.length);
    // console.log('airdropping 0 - 444');
    // await froggyFriends.airdrop(wallets.slice(0, 444), tokenIds.slice(0, 444));
    // console.log('airdropping 444 - 888');
    // await froggyFriends.airdrop(wallets.slice(444, 888), tokenIds.slice(444, 888));
    // console.log('airdropping 888 - 1332');
    // await froggyFriends.airdrop(wallets.slice(888, 1332), tokenIds.slice(888, 1332));
    // console.log('airdropping 1332 - 1776');
    // await froggyFriends.airdrop(wallets.slice(1332, 1776), tokenIds.slice(1332, 1776));
    // console.log('airdropping 1776 - 2220');
    // await froggyFriends.airdrop(wallets.slice(1776, 2220), tokenIds.slice(1776, 2220));
    // console.log('airdropping 2220 - 2664');
    // await froggyFriends.airdrop(wallets.slice(2220, 2664), tokenIds.slice(2220, 2664));
    // console.log('airdropping 2664 - 3108');
    // await froggyFriends.airdrop(wallets.slice(2664, 3108), tokenIds.slice(2664, 3108));
    // console.log('airdropping 3108 - 3552');
    // await froggyFriends.airdrop(wallets.slice(3108, 3552), tokenIds.slice(3108, 3552));
    // console.log('airdropping 3552 - 3996');
    // await froggyFriends.airdrop(wallets.slice(3552, 3996), tokenIds.slice(3552, 3996));
    // console.log('airdropping 3996 - 4444');
    // await froggyFriends.airdrop(wallets.slice(3996, 4444), tokenIds.slice(3996, 4444));
}

main()
    .then(() => process.exit(0))
    .catch(error => {
        console.log(error);
        process.exit(1);
    });