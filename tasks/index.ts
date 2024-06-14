import { task } from "hardhat/config";
import { bridge } from "./bridge";

// npx hardhat bridge --network mainnet --dst base --contract FroggyFriends
task("bridge", "Wires two chains together for bridging using Layer Zero")
  .addParam("dst", "The destination chain to bridge to")
  .addParam("contract", "The contract name")
  .setAction(bridge);
