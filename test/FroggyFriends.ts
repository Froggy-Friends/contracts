import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { expect } from "chai";
import { ethers, upgrades } from "hardhat";
import { FroggyFriends } from "../types";
import * as snapshot from '../snapshot.json';

describe("Froggy Friends", async () => {
  let froggyFriends: FroggyFriends;
  let owner: SignerWithAddress;

  beforeEach(async () => {
    [owner] = await ethers.getSigners();
    
    let factory = await ethers.getContractFactory("FroggyFriends");

    // deploy froggy friends
    froggyFriends = (await upgrades.deployProxy(factory)) as FroggyFriends;
    await froggyFriends.deployed();
  });

  describe("airdrop", async () => {
    const { wallets, tokenIds } = snapshot;

    it("invalid size", async () => {
        await expect(froggyFriends.airdrop(['0x6b01aD68aB6F53128B7A6Fe7E199B31179A4629a'], [1,2]))
            .revertedWithCustomError(froggyFriends, 'InvalidSize'); 
    });

    it("over max supply", async () => {
        await froggyFriends.airdrop(wallets.slice(0, 444), tokenIds.slice(0, 444));
        await froggyFriends.airdrop(wallets.slice(444, 888), tokenIds.slice(444, 888));
        await froggyFriends.airdrop(wallets.slice(888, 1332), tokenIds.slice(888, 1332));
        await froggyFriends.airdrop(wallets.slice(1332, 1776), tokenIds.slice(1332, 1776));
        await froggyFriends.airdrop(wallets.slice(1776, 2220), tokenIds.slice(1776, 2220));
        await froggyFriends.airdrop(wallets.slice(2220, 2664), tokenIds.slice(2220, 2664));
        await froggyFriends.airdrop(wallets.slice(2664, 3108), tokenIds.slice(2664, 3108));
        await froggyFriends.airdrop(wallets.slice(3108, 3552), tokenIds.slice(3108, 3552));
        await froggyFriends.airdrop(wallets.slice(3552, 3996), tokenIds.slice(3552, 3996));
        await froggyFriends.airdrop(wallets.slice(3996, 4444), tokenIds.slice(3996, 4444));
        await expect(froggyFriends.airdrop(wallets.slice(0, 1), tokenIds.slice(0, 1)))
            .revertedWithCustomError(froggyFriends, 'OverMaxSupply');
    });

    it('entire supply', async () => {
        await froggyFriends.airdrop(wallets.slice(0, 444), tokenIds.slice(0, 444));
        await froggyFriends.airdrop(wallets.slice(444, 888), tokenIds.slice(444, 888));
        await froggyFriends.airdrop(wallets.slice(888, 1332), tokenIds.slice(888, 1332));
        await froggyFriends.airdrop(wallets.slice(1332, 1776), tokenIds.slice(1332, 1776));
        await froggyFriends.airdrop(wallets.slice(1776, 2220), tokenIds.slice(1776, 2220));
        await froggyFriends.airdrop(wallets.slice(2220, 2664), tokenIds.slice(2220, 2664));
        await froggyFriends.airdrop(wallets.slice(2664, 3108), tokenIds.slice(2664, 3108));
        await froggyFriends.airdrop(wallets.slice(3108, 3552), tokenIds.slice(3108, 3552));
        await froggyFriends.airdrop(wallets.slice(3552, 3996), tokenIds.slice(3552, 3996));
        await froggyFriends.airdrop(wallets.slice(3996, 4444), tokenIds.slice(3996, 4444));
        const totalSupply = await froggyFriends.totalSupply();
        expect(totalSupply).equals(4444);
    });
  });
});
