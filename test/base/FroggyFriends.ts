import { expect } from "chai";
import { ethers, upgrades } from "hardhat";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { Contract, ContractFactory } from "ethers";
import { keccak256 } from "ethers/lib/utils";
import { FroggyFriends, FroggyFriendsBase } from "../../types";

describe("ONFT721: ", function () {
  const chainId_A = 1;
  const chainId_B = 2;
  const minGasToStore = 150000;
  const batchSizeLimit = 300;
  const defaultAdapterParams = ethers.utils.solidityPack(
    ["uint16", "uint256"],
    [1, 200000]
  );

  let owner: SignerWithAddress,
    warlock: SignerWithAddress,
    lzEndpointMockA: Contract,
    lzEndpointMockB: Contract,
    LZEndpointMock: ContractFactory,
    FroggyFriendsEthFactory: ContractFactory,
    FroggyFriendsBaseFactory: ContractFactory,
    FroggyFriendsEth: FroggyFriends,
    FroggyFriendsBase: FroggyFriendsBase;

  before(async function () {
    owner = (await ethers.getSigners())[0];
    warlock = (await ethers.getSigners())[1];
    LZEndpointMock = await ethers.getContractFactory("LZEndpointMock");
    FroggyFriendsEthFactory = await ethers.getContractFactory("FroggyFriends");
    FroggyFriendsBaseFactory = await ethers.getContractFactory(
      "FroggyFriendsBase"
    );
  });

  beforeEach(async function () {
    lzEndpointMockA = await LZEndpointMock.deploy(chainId_A);
    lzEndpointMockB = await LZEndpointMock.deploy(chainId_B);

    // generate a proxy to allow it to go ONFT
    FroggyFriendsEth = (await upgrades.deployProxy(FroggyFriendsEthFactory, [
      minGasToStore,
      lzEndpointMockA.address,
    ])) as FroggyFriends;
    FroggyFriendsBase = (await upgrades.deployProxy(FroggyFriendsBaseFactory, [
      minGasToStore,
      lzEndpointMockB.address,
    ])) as FroggyFriendsBase;

    // wire the lz endpoints to guide msgs back and forth
    lzEndpointMockA.setDestLzEndpoint(
      FroggyFriendsBase.address,
      lzEndpointMockB.address
    );
    lzEndpointMockB.setDestLzEndpoint(
      FroggyFriendsEth.address,
      lzEndpointMockA.address
    );

    // set each contracts source address so it can send to each other
    await FroggyFriendsEth.setTrustedRemote(
      chainId_B,
      ethers.utils.solidityPack(
        ["address", "address"],
        [FroggyFriendsBase.address, FroggyFriendsEth.address]
      )
    );
    await FroggyFriendsBase.setTrustedRemote(
      chainId_A,
      ethers.utils.solidityPack(
        ["address", "address"],
        [FroggyFriendsEth.address, FroggyFriendsBase.address]
      )
    );

    // set batch size limit
    await FroggyFriendsEth.setDstChainIdToBatchLimit(chainId_B, batchSizeLimit);
    await FroggyFriendsBase.setDstChainIdToBatchLimit(
      chainId_A,
      batchSizeLimit
    );

    // set min dst gas for swap
    await FroggyFriendsEth.setMinDstGas(chainId_B, 1, 150000);
    await FroggyFriendsBase.setMinDstGas(chainId_A, 1, 150000);
  });

  it("sendFrom() - your own tokens", async function () {
    const tokenId = 123;
    await FroggyFriendsEth.mint(owner.address, tokenId);

    // verify the owner of the token is on the source chain
    expect(await FroggyFriendsEth.ownerOf(tokenId)).to.be.equal(owner.address);

    // token doesn't exist on other chain
    await expect(FroggyFriendsBase.ownerOf(tokenId)).to.be.revertedWith(
      "ERC721: invalid token ID"
    );

    // can transfer token on srcChain as regular erC721
    await FroggyFriendsEth.transferFrom(
      owner.address,
      warlock.address,
      tokenId
    );
    expect(await FroggyFriendsEth.ownerOf(tokenId)).to.be.equal(
      warlock.address
    );

    // approve the proxy to swap your token
    await FroggyFriendsEth.connect(warlock).approve(
      FroggyFriendsEth.address,
      tokenId
    );

    // estimate nativeFees
    let nativeFee = (
      await FroggyFriendsEth.estimateSendFee(
        chainId_B,
        warlock.address,
        tokenId,
        false,
        defaultAdapterParams
      )
    ).nativeFee;

    // swaps token to other chain
    await FroggyFriendsEth.connect(warlock).sendFrom(
      warlock.address,
      chainId_B,
      warlock.address,
      tokenId,
      warlock.address,
      ethers.constants.AddressZero,
      defaultAdapterParams,
      { value: nativeFee }
    );

    // token is burnt
    expect(await FroggyFriendsEth.ownerOf(tokenId)).to.be.equal(
      FroggyFriendsEth.address
    );

    // token received on the dst chain
    expect(await FroggyFriendsBase.ownerOf(tokenId)).to.be.equal(
      warlock.address
    );

    // estimate nativeFees
    nativeFee = (
      await FroggyFriendsBase.estimateSendFee(
        chainId_A,
        warlock.address,
        tokenId,
        false,
        defaultAdapterParams
      )
    ).nativeFee;

    // can send to other onft contract eg. not the original nft contract chain
    await FroggyFriendsBase.connect(warlock).sendFrom(
      warlock.address,
      chainId_A,
      warlock.address,
      tokenId,
      warlock.address,
      ethers.constants.AddressZero,
      defaultAdapterParams,
      { value: nativeFee }
    );

    // token is burned on the sending chain
    expect(await FroggyFriendsBase.ownerOf(tokenId)).to.be.equal(
      FroggyFriendsBase.address
    );
  });

  it("sendFrom() - totalSupply is incremented", async function () {
    const tokenId = 123;
    const tokenId2 = 456;
    const tokenId3 = 789;
    await FroggyFriendsEth.mint(owner.address, tokenId);
    await FroggyFriendsEth.mint(owner.address, tokenId2);
    await FroggyFriendsEth.mint(owner.address, tokenId3);

    // verify the owner of the token is on the source chain
    expect(await FroggyFriendsEth.ownerOf(tokenId)).to.be.equal(owner.address);
    expect(await FroggyFriendsEth.ownerOf(tokenId2)).to.be.equal(owner.address);
    expect(await FroggyFriendsEth.ownerOf(tokenId3)).to.be.equal(owner.address);

    // token doesn't exist on other chain
    await expect(FroggyFriendsBase.ownerOf(tokenId)).to.be.revertedWith(
      "ERC721: invalid token ID"
    );
    await expect(FroggyFriendsBase.ownerOf(tokenId2)).to.be.revertedWith(
      "ERC721: invalid token ID"
    );
    await expect(FroggyFriendsBase.ownerOf(tokenId3)).to.be.revertedWith(
      "ERC721: invalid token ID"
    );

    // approve the proxy to swap your token
    await FroggyFriendsEth.connect(owner).approve(
      FroggyFriendsEth.address,
      tokenId
    );
    await FroggyFriendsEth.connect(owner).approve(
      FroggyFriendsEth.address,
      tokenId2
    );
    await FroggyFriendsEth.connect(owner).approve(
      FroggyFriendsEth.address,
      tokenId3
    );

    // estimate nativeFees
    let nativeFee = (
      await FroggyFriendsEth.estimateSendFee(
        chainId_B,
        owner.address,
        tokenId,
        false,
        defaultAdapterParams
      )
    ).nativeFee;

    // swaps token to other chain
    await FroggyFriendsEth.connect(owner).sendFrom(
      owner.address,
      chainId_B,
      owner.address,
      tokenId,
      owner.address,
      ethers.constants.AddressZero,
      defaultAdapterParams,
      { value: nativeFee }
    );
    await FroggyFriendsEth.connect(owner).sendFrom(
      owner.address,
      chainId_B,
      owner.address,
      tokenId2,
      owner.address,
      ethers.constants.AddressZero,
      defaultAdapterParams,
      { value: nativeFee }
    );
    await FroggyFriendsEth.connect(owner).sendFrom(
      owner.address,
      chainId_B,
      owner.address,
      tokenId3,
      owner.address,
      ethers.constants.AddressZero,
      defaultAdapterParams,
      { value: nativeFee }
    );

    // token is burnt
    expect(await FroggyFriendsEth.ownerOf(tokenId)).to.be.equal(
      FroggyFriendsEth.address
    );
    expect(await FroggyFriendsEth.ownerOf(tokenId2)).to.be.equal(
      FroggyFriendsEth.address
    );
    expect(await FroggyFriendsEth.ownerOf(tokenId3)).to.be.equal(
      FroggyFriendsEth.address
    );

    // token received on the dst chain
    expect(await FroggyFriendsBase.ownerOf(tokenId)).to.be.equal(owner.address);
    expect(await FroggyFriendsBase.ownerOf(tokenId2)).to.be.equal(
      owner.address
    );
    expect(await FroggyFriendsBase.ownerOf(tokenId3)).to.be.equal(
      owner.address
    );

    // total supply increases on dst chain
    expect(await FroggyFriendsBase.totalSupply()).to.be.equal(3);
  });

  it("sendFrom() - reverts if not owner on non proxy chain", async function () {
    const tokenId = 123;
    await FroggyFriendsEth.mint(owner.address, tokenId);

    // approve the proxy to swap your token
    await FroggyFriendsEth.approve(FroggyFriendsEth.address, tokenId);

    // estimate nativeFees
    let nativeFee = (
      await FroggyFriendsEth.estimateSendFee(
        chainId_B,
        owner.address,
        tokenId,
        false,
        defaultAdapterParams
      )
    ).nativeFee;

    // swaps token to other chain
    await FroggyFriendsEth.sendFrom(
      owner.address,
      chainId_B,
      owner.address,
      tokenId,
      owner.address,
      ethers.constants.AddressZero,
      defaultAdapterParams,
      {
        value: nativeFee,
      }
    );

    // token received on the dst chain
    expect(await FroggyFriendsBase.ownerOf(tokenId)).to.be.equal(owner.address);

    // reverts because other address does not own it
    await expect(
      FroggyFriendsBase.connect(warlock).sendFrom(
        warlock.address,
        chainId_A,
        warlock.address,
        tokenId,
        warlock.address,
        ethers.constants.AddressZero,
        defaultAdapterParams
      )
    ).to.be.revertedWith("ONFT721: send caller is not owner nor approved");
  });

  it("sendFrom() - on behalf of other user", async function () {
    const tokenId = 123;
    await FroggyFriendsEth.mint(owner.address, tokenId);

    // approve the proxy to swap your token
    await FroggyFriendsEth.approve(FroggyFriendsEth.address, tokenId);

    // estimate nativeFees
    let nativeFee = (
      await FroggyFriendsEth.estimateSendFee(
        chainId_B,
        owner.address,
        tokenId,
        false,
        defaultAdapterParams
      )
    ).nativeFee;

    // swaps token to other chain
    await FroggyFriendsEth.sendFrom(
      owner.address,
      chainId_B,
      owner.address,
      tokenId,
      owner.address,
      ethers.constants.AddressZero,
      defaultAdapterParams,
      {
        value: nativeFee,
      }
    );

    // token received on the dst chain
    expect(await FroggyFriendsBase.ownerOf(tokenId)).to.be.equal(owner.address);

    // approve the other user to send the token
    await FroggyFriendsBase.approve(warlock.address, tokenId);

    // estimate nativeFees
    nativeFee = (
      await FroggyFriendsBase.estimateSendFee(
        chainId_A,
        warlock.address,
        tokenId,
        false,
        defaultAdapterParams
      )
    ).nativeFee;

    // sends across
    await FroggyFriendsBase.connect(warlock).sendFrom(
      owner.address,
      chainId_A,
      warlock.address,
      tokenId,
      warlock.address,
      ethers.constants.AddressZero,
      defaultAdapterParams,
      { value: nativeFee }
    );

    // token received on the dst chain
    expect(await FroggyFriendsEth.ownerOf(tokenId)).to.be.equal(
      warlock.address
    );
  });

  it("sendFrom() - reverts if contract is approved, but not the sending user", async function () {
    const tokenId = 123;
    await FroggyFriendsEth.mint(owner.address, tokenId);

    // approve the proxy to swap your token
    await FroggyFriendsEth.approve(FroggyFriendsEth.address, tokenId);

    // estimate nativeFees
    let nativeFee = (
      await FroggyFriendsEth.estimateSendFee(
        chainId_B,
        owner.address,
        tokenId,
        false,
        defaultAdapterParams
      )
    ).nativeFee;

    // swaps token to other chain
    await FroggyFriendsEth.sendFrom(
      owner.address,
      chainId_B,
      owner.address,
      tokenId,
      owner.address,
      ethers.constants.AddressZero,
      defaultAdapterParams,
      {
        value: nativeFee,
      }
    );

    // token received on the dst chain
    expect(await FroggyFriendsBase.ownerOf(tokenId)).to.be.equal(owner.address);

    // approve the contract to swap your token
    await FroggyFriendsBase.approve(FroggyFriendsBase.address, tokenId);

    // reverts because contract is approved, not the user
    await expect(
      FroggyFriendsBase.connect(warlock).sendFrom(
        owner.address,
        chainId_A,
        warlock.address,
        tokenId,
        warlock.address,
        ethers.constants.AddressZero,
        defaultAdapterParams
      )
    ).to.be.revertedWith("ONFT721: send caller is not owner nor approved");
  });

  it("sendFrom() - reverts if not approved on non proxy chain", async function () {
    const tokenId = 123;
    await FroggyFriendsEth.mint(owner.address, tokenId);

    // approve the proxy to swap your token
    await FroggyFriendsEth.approve(FroggyFriendsEth.address, tokenId);

    // estimate nativeFees
    let nativeFee = (
      await FroggyFriendsEth.estimateSendFee(
        chainId_B,
        owner.address,
        tokenId,
        false,
        defaultAdapterParams
      )
    ).nativeFee;

    // swaps token to other chain
    await FroggyFriendsEth.sendFrom(
      owner.address,
      chainId_B,
      owner.address,
      tokenId,
      owner.address,
      ethers.constants.AddressZero,
      defaultAdapterParams,
      {
        value: nativeFee,
      }
    );

    // token received on the dst chain
    expect(await FroggyFriendsBase.ownerOf(tokenId)).to.be.equal(owner.address);

    // reverts because user is not approved
    await expect(
      FroggyFriendsBase.connect(warlock).sendFrom(
        owner.address,
        chainId_A,
        warlock.address,
        tokenId,
        warlock.address,
        ethers.constants.AddressZero,
        defaultAdapterParams
      )
    ).to.be.revertedWith("ONFT721: send caller is not owner nor approved");
  });

  it("sendFrom() - reverts if sender has not approved proxy contract", async function () {
    const tokenIdA = 123;
    const tokenIdB = 456;
    // mint to both owners
    await FroggyFriendsEth.mint(owner.address, tokenIdA);
    await FroggyFriendsEth.mint(warlock.address, tokenIdB);

    // approve owner.address to transfer, but not the other
    await FroggyFriendsEth.setApprovalForAll(FroggyFriendsEth.address, true);

    await expect(
      FroggyFriendsEth.connect(warlock).sendFrom(
        warlock.address,
        chainId_B,
        warlock.address,
        tokenIdA,
        warlock.address,
        ethers.constants.AddressZero,
        defaultAdapterParams
      )
    ).to.be.revertedWith("ONFT721: send caller is not owner nor approved");
    await expect(
      FroggyFriendsEth.connect(warlock).sendFrom(
        warlock.address,
        chainId_B,
        owner.address,
        tokenIdA,
        owner.address,
        ethers.constants.AddressZero,
        defaultAdapterParams
      )
    ).to.be.revertedWith("ONFT721: send caller is not owner nor approved");
  });

  it("sendBatchFrom()", async function () {
    await FroggyFriendsEth.setMinGasToTransferAndStore(400000);
    await FroggyFriendsBase.setMinGasToTransferAndStore(400000);

    const tokenIds = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10];

    // mint to owner
    for (let tokenId of tokenIds) {
      await FroggyFriendsEth.mint(warlock.address, tokenId);
    }

    // approve owner.address to transfer
    await FroggyFriendsEth.connect(warlock).setApprovalForAll(
      FroggyFriendsEth.address,
      true
    );

    // expected event params
    const payload = ethers.utils.defaultAbiCoder.encode(
      ["bytes", "uint[]"],
      [warlock.address, tokenIds]
    );
    const hashedPayload = keccak256(payload);

    let adapterParams = ethers.utils.solidityPack(
      ["uint16", "uint256"],
      [1, 200000]
    );

    // estimate nativeFees
    let nativeFee = (
      await FroggyFriendsEth.estimateSendBatchFee(
        chainId_B,
        warlock.address,
        tokenIds,
        false,
        defaultAdapterParams
      )
    ).nativeFee;

    // initiate batch transfer
    await expect(
      FroggyFriendsEth.connect(warlock).sendBatchFrom(
        warlock.address,
        chainId_B,
        warlock.address,
        tokenIds,
        warlock.address,
        ethers.constants.AddressZero,
        adapterParams, // TODO might need to change this
        { value: nativeFee }
      )
    )
      .to.emit(FroggyFriendsBase, "CreditStored")
      .withArgs(hashedPayload, payload);

    // only partial amount of tokens has been sent, the rest have been stored as a credit
    let creditedIdsA = [];
    for (let tokenId of tokenIds) {
      let owner = await FroggyFriendsBase.rawOwnerOf(tokenId);
      if (owner == ethers.constants.AddressZero) {
        creditedIdsA.push(tokenId);
      } else {
        expect(owner).to.be.equal(warlock.address);
      }
    }

    // clear the rest of the credits
    await expect(FroggyFriendsBase.clearCredits(payload))
      .to.emit(FroggyFriendsBase, "CreditCleared")
      .withArgs(hashedPayload);

    let creditedIdsB = [];
    for (let tokenId of creditedIdsA) {
      let owner = await FroggyFriendsBase.rawOwnerOf(tokenId);
      if (owner == ethers.constants.AddressZero) {
        creditedIdsB.push(tokenId);
      } else {
        expect(owner).to.be.equal(warlock.address);
      }
    }

    // all ids should have cleared
    expect(creditedIdsB.length).to.be.equal(0);

    // should revert because payload is no longer valid
    await expect(FroggyFriendsBase.clearCredits(payload)).to.be.revertedWith(
      "ONFT721: no credits stored"
    );
  });

  it("sendBatchFrom() - large batch", async function () {
    await FroggyFriendsEth.setMinGasToTransferAndStore(400000);
    await FroggyFriendsBase.setMinGasToTransferAndStore(400000);

    const tokenIds = [];

    for (let i = 1; i <= 300; i++) {
      tokenIds.push(i);
    }

    // mint to owner
    for (let tokenId of tokenIds) {
      await FroggyFriendsEth.mint(warlock.address, tokenId);
    }

    // approve owner.address to transfer
    await FroggyFriendsEth.connect(warlock).setApprovalForAll(
      FroggyFriendsEth.address,
      true
    );

    // expected event params
    const payload = ethers.utils.defaultAbiCoder.encode(
      ["bytes", "uint[]"],
      [warlock.address, tokenIds]
    );
    const hashedPayload = keccak256(payload);

    let adapterParams = ethers.utils.solidityPack(
      ["uint16", "uint256"],
      [1, 400000]
    );

    // estimate nativeFees
    let nativeFee = (
      await FroggyFriendsEth.estimateSendBatchFee(
        chainId_B,
        warlock.address,
        tokenIds,
        false,
        adapterParams
      )
    ).nativeFee;

    // initiate batch transfer
    await expect(
      FroggyFriendsEth.connect(warlock).sendBatchFrom(
        warlock.address,
        chainId_B,
        warlock.address,
        tokenIds,
        warlock.address,
        ethers.constants.AddressZero,
        adapterParams, // TODO might need to change this
        { value: nativeFee }
      )
    )
      .to.emit(FroggyFriendsBase, "CreditStored")
      .withArgs(hashedPayload, payload);

    // only partial amount of tokens has been sent, the rest have been stored as a credit
    let creditedIdsA = [];
    for (let tokenId of tokenIds) {
      let owner = await FroggyFriendsBase.rawOwnerOf(tokenId);
      if (owner == ethers.constants.AddressZero) {
        creditedIdsA.push(tokenId);
      } else {
        expect(owner).to.be.equal(warlock.address);
      }
    }

    // clear the rest of the credits
    await (await FroggyFriendsBase.clearCredits(payload)).wait();

    let creditedIdsB = [];
    for (let tokenId of creditedIdsA) {
      let owner = await FroggyFriendsBase.rawOwnerOf(tokenId);
      if (owner == ethers.constants.AddressZero) {
        creditedIdsB.push(tokenId);
      } else {
        expect(owner).to.be.equal(warlock.address);
      }
    }

    // console.log("Number of tokens credited: ", creditedIdsB.length)

    // all ids should have cleared
    expect(creditedIdsB.length).to.be.equal(0);

    // should revert because payload is no longer valid
    await expect(FroggyFriendsBase.clearCredits(payload)).to.be.revertedWith(
      "ONFT721: no credits stored"
    );
  });
});
