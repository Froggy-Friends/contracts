import { task } from "hardhat/config";
import { bridge } from "./bridge";
import { deploy } from "./deploy";

// npx hardhat deploy --network mainnet --contract FroggyFriends
task("deploy", "Deploys a contract to a chain")
  .addParam("contract", "The contract name")
  .setAction(deploy);

// npx hardhat bridge --network mainnet --dst base --contract FroggyFriends
task("bridge", "Wires two chains together for bridging using Layer Zero")
  .addParam("dst", "The destination chain to bridge to")
  .addParam("contract", "The contract name")
  .setAction(bridge);
