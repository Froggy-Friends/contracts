import { HardhatRuntimeEnvironment as HRE, TaskArguments } from "hardhat/types";
import {
  getContract,
  getChainId,
  getProvidedGasLimit,
} from "../utils/contracts";
import { sendAndCall } from "../utils/constants";

// Sends NFT by tokenId to a destination chain
export async function portal(taskArgs: TaskArguments, hre: HRE) {
  const { dst, contract, token } = taskArgs;
  const { ethers, network } = hre;

  console.log(
    `Sending ${contract} number ${token} from ${network.name} to ${dst}...`
  );

  const [owner] = await ethers.getSigners();
  console.log("Deployer: ", owner.address);

  const srcContract = await getContract(network.name, contract, ethers);
  const dstChainId = getChainId(dst);
  const providedGasLimit = getProvidedGasLimit(dst);
  const payInZroTokens = false;

  console.log("srcContract: ", srcContract.address);
  console.log("dstChainId: ", dstChainId);
  console.log("tokenId: ", token);
  console.log("providedGasLimit: ", providedGasLimit);
  console.log("payInZroTokens: ", payInZroTokens);

  // providedGasLimite must be more than minGasLimit in bridge.ts i.e. 260000 for EVMs and 2000000 for Arbitrum
  const adapterParams = ethers.utils.solidityPack(
    ["uint16", "uint256"],
    [sendAndCall, providedGasLimit]
  );

  const fees = await srcContract.estimateSendFee(
    dstChainId,
    owner.address,
    token,
    payInZroTokens,
    adapterParams
  );
  const nativeFee = fees[0];
  console.log(`Estimated send native fees (wei): ${nativeFee}`);

  const tx = await srcContract.sendFrom(
    owner.address, // 'from' address to send tokens
    dstChainId, // remote LayerZero chainId
    owner.address, // 'to' address to send tokens
    token, // tokenId to send
    owner.address, // refund address (if too much message fee is sent, it gets refunded)
    ethers.constants.AddressZero, // address(0x0) if not paying in ZRO (LayerZero Token)
    adapterParams, // flexible bytes array to indicate messaging adapter services
    { value: nativeFee.mul(5).div(4) }
  );
  await tx.wait();
  console.log("Sending NFT tx: ", tx.hash);

  console.log(
    `Sent ${contract} number ${token} from ${network.name} to ${dst}!`
  );
}
