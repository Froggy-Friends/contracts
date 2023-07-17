import { ethers, upgrades } from "hardhat";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { FroggyTraits } from "../../types";
import { expect } from "chai";

describe("Froggy Traits", async () => {
  let froggyTraits: FroggyTraits;
  let owner: SignerWithAddress;

  beforeEach(async () => {
    [owner] = await ethers.getSigners();
    let factory = await ethers.getContractFactory("FroggyTraits");
    const LzPolygonEndpoint = "0x3c2269811836af69497E5F486A85D7316753cf62";
    const baseUrl = "https://metadata.froggyfriends.io/traits/";
    froggyTraits = (await upgrades.deployProxy(factory, [baseUrl, LzPolygonEndpoint])) as FroggyTraits;
    await froggyTraits.deployed();
  });

  describe("", async () => {
    
  });
});
