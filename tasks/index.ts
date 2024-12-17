import { task } from "hardhat/config";
import { bridge } from "./bridge";
import { publish } from "./publish";
import { portal } from "./portal";
import { upgrade } from "./upgrade";

// npx hardhat deploy --network mainnet --contract FroggyFriends
task("publish", "Publishes a proxy contract to a chain")
  .addParam("contract", "The contract name")
  .setAction(publish);

// npx hardhat bridge --network mainnet --dst base --contract FroggyFriends
task("bridge", "Wires two chains together for bridging using Layer Zero")
  .addParam("dst", "The destination chain to bridge to")
  .addParam("contract", "The contract name")
  .setAction(bridge);

// npx hardhat portal --network mainnet --dst base --contract FroggyFriends --tokenId 1
task("portal", "Sends NFT by tokenId to a destination chain")
  .addParam("dst", "The destination chain to bridge to")
  .addParam("contract", "The contract name")
  .addParam("token", "The tokenId of the NFT")
  .setAction(portal);

// npx hardhat upgrade --network mainnet --contract FroggyFriends
task("upgrade", "Upgrades a proxy contract")
  .addParam("contract", "The contract name")
  .setAction(upgrade);
