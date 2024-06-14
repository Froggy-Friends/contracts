import { task } from "hardhat/config";
import { bridge } from "./bridge";
import { publish } from "./publish";

// npx hardhat deploy --network mainnet --contract FroggyFriends
task("publish", "Publishes a proxy contract to a chain")
  .addParam("contract", "The contract name")
  .setAction(publish);

// npx hardhat bridge --network mainnet --dst base --contract FroggyFriends
task("bridge", "Wires two chains together for bridging using Layer Zero")
  .addParam("dst", "The destination chain to bridge to")
  .addParam("contract", "The contract name")
  .setAction(bridge);
