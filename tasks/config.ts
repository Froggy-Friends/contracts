import { HardhatRuntimeEnvironment as HRE, TaskArguments } from "hardhat/types";
import { getContract, getChainId } from "../utils/contracts";
import { lzEthereumEndpoint } from "../utils/constants";
import { Contract } from "ethers";

export const ENDPOINT_ABI = [
  "function defaultSendVersion() view returns (uint16)",
  "function defaultReceiveVersion() view returns (uint16)",
  "function defaultSendLibrary() view returns (address)",
  "function defaultReceiveLibraryAddress() view returns (address)",
  "function uaConfigLookup(address) view returns (tuple(uint16 sendVersion, uint16 receiveVersion, address receiveLibraryAddress, address sendLibrary))",
];

export const MESSAGING_LIBRARY_ABI = [
  "function appConfig(address, uint16) view returns (tuple(uint16 inboundProofLibraryVersion, uint64 inboundBlockConfirmations, address relayer, uint16 outboundProofType, uint64 outboundBlockConfirmations, address oracle))",
  "function defaultAppConfig(uint16) view returns (tuple(uint16 inboundProofLibraryVersion, uint64 inboundBlockConfirmations, address relayer, uint16 outboundProofType, uint64 outboundBlockConfirmations, address oracle))",
];

// Gets layer zero User Application configuration for source chain
export async function config(taskArgs: TaskArguments, hre: HRE) {
  const { dst, contract } = taskArgs;
  const { ethers, network } = hre;

  console.log(
    `Config for ${contract} contract from ${network.name} to ${dst}...`
  );

  const [owner] = await ethers.getSigners();

  const srcContract = await getContract(network.name, contract, ethers);
  const dstChainId = getChainId(dst);

  const endpointContract = new Contract(
    lzEthereumEndpoint,
    ENDPOINT_ABI,
    owner
  );
  const endpoint = endpointContract.connect(owner);
  const appConfig = await endpoint.uaConfigLookup(srcContract.address);
  const sendVersion = appConfig.sendVersion;
  const receiveVersion = appConfig.receiveVersion;
  const sendLibraryAddress =
    sendVersion === 0
      ? await endpoint.defaultSendLibrary()
      : appConfig.sendLibrary;

  const sendLibraryContract = new Contract(
    sendLibraryAddress,
    MESSAGING_LIBRARY_ABI,
    owner
  );
  const sendLibrary = sendLibraryContract.connect(owner);
  let receiveLibrary: any;

  if (sendVersion !== receiveVersion) {
    const receiveLibraryAddress =
      receiveVersion === 0
        ? await endpoint.defaultReceiveLibraryAddress()
        : appConfig.receiveLibraryAddress;

    const receiveLibraryContract = new Contract(
      receiveLibraryAddress,
      MESSAGING_LIBRARY_ABI,
      owner
    );
    receiveLibrary = receiveLibraryContract.connect(owner);
  }

  const sendConfig = await sendLibrary.appConfig(
    srcContract.address,
    dstChainId
  );
  let inboundProofLibraryVersion = sendConfig.inboundProofLibraryVersion;
  let inboundBlockConfirmations =
    sendConfig.inboundBlockConfirmations.toNumber();

  if (receiveLibrary) {
    const receiveConfig = await receiveLibrary.appConfig(
      srcContract.address,
      dstChainId
    );
    inboundProofLibraryVersion = receiveConfig.inboundProofLibraryVersion;
    inboundBlockConfirmations =
      receiveConfig.inboundBlockConfirmations.toNumber();
  }
  const remoteConfig = {
    dst,
    inboundProofLibraryVersion,
    inboundBlockConfirmations,
    relayer: sendConfig.relayer,
    outboundProofType: sendConfig.outboundProofType,
    outboundBlockConfirmations:
      sendConfig.outboundBlockConfirmations.toNumber(),
    oracle: sendConfig.oracle,
  };

  console.log("srcContract: ", srcContract.address);
  console.log("dstChainId: ", dstChainId);
  console.log("Send version ", sendVersion);
  console.log("Receive version ", receiveVersion);
  console.table(remoteConfig);

  console.log(
    `Config fetched for ${contract} contract from ${network.name} to ${dst}!`
  );
}
