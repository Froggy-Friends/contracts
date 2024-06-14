import { HardhatRuntimeEnvironment as HRE, TaskArguments } from "hardhat/types";
import { getContract, getChainId, getMinGasLimit } from "../utils/contracts";
import { batchSizeLimit } from "../utils/constants";

// Call once per chain to wire them together
export async function bridge(taskArgs: TaskArguments, hre: HRE) {
  const { dst, contract } = taskArgs;
  const { ethers, network } = hre;

  console.log(`Wiring ${contract} contract from ${network.name} to ${dst}...`);

  const srcContract = await getContract(network.name, contract, ethers);
  const dstContract = await getContract(dst, contract, ethers);
  const dstChainId = getChainId(dst);
  const minGasLimit = getMinGasLimit(dst);
  console.log("srcContract: ", srcContract.address);
  console.log("dstContract: ", dstContract.address);
  console.log("dstChainId: ", dstChainId);
  console.log("minGasLimit: ", minGasLimit);

  // Step 1: Set destination chain as trusted remote
  const srcAndDst = ethers.utils.solidityPack(
    ["address", "address"],
    [srcContract.address, dstContract.address]
  );
  console.log("srcAndDst: ", srcAndDst);
  if (!(await srcContract.isTrustedRemote(dstChainId, srcAndDst))) {
    console.log("Setting trusted remote for ", network.name, "to ", dst);
    await srcContract.setTrustedRemote(getChainId(dst), srcAndDst);
  } else {
    console.log("Already trusted remote for ", network.name, "to ", dst);
  }

  // Step 2: Set batch size limit for transfers
  await srcContract.setDstChainIdToBatchLimit(dstChainId, batchSizeLimit);

  // Step 3: Set the minimum gas to transfer NFTs
  await srcContract.setMinDstGas(dstChainId, 1, minGasLimit);

  console.log(`Wired ${contract} contract from ${network.name} to ${dst}!`);
}
