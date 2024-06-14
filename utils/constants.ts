export const froggyFriendsEth = "0x7ad05c1b87e93BE306A9Eadf80eA60d7648F1B6F";
export const lzEthereumEndpoint = "0x66A71Dcef29A0fFBDBE3c6a460a3B5BC225Cd675";
export const lzBaseEndpoint = "0xb6319cC6c8c27A8F5dAF0dD3DF91EA35C4720dd7";
export const ethChainId = 101;
export const batchSizeLimit = 10;
export const evmGasLimit = 260000;
export const arbGasLimit = 2000000;
export const evmProvidedGasLimit = 261000; // must be greater than evmGasLimit, this is used to create adapterParams passed to sendFrom function
export const minGasToTransfer = 100000;
export const send = 0; // used to create layer zero adapterParams
export const sendAndCall = 1; // used to create layer zero adapterParams

// sourced from https://docs.layerzero.network/v1/developers/evm/technical-reference/mainnet/mainnet-addresses
export const chainIds = new Map([
  ["mainnet", 101],
  ["polygon", 109],
  ["arbitrum", 110],
  ["optimism", 111],
  ["base", 184],
]);

export const minGasLimits = new Map([
  ["mainnet", evmGasLimit],
  ["polygon", evmGasLimit],
  ["arbitrum", arbGasLimit],
  ["optimism", evmGasLimit],
  ["base", evmGasLimit],
]);

export const providedGasLimits = new Map([
  ["mainnet", evmGasLimit + 1000],
  ["polygon", evmGasLimit + 1000],
  ["arbitrum", arbGasLimit + 1000],
  ["optimism", evmGasLimit + 1000],
  ["base", evmGasLimit + 1000],
]);

export const contractAddresses = new Map([
  ["mainnet", froggyFriendsEth],
  ["base", "0x9DA02cBE93835E8b6c44563415C72D106B1ce00a"],
]);

export const lzEndpoints = new Map([
  ["mainnet", lzEthereumEndpoint],
  ["base", lzBaseEndpoint],
  ["sepolia", "0x7cacBe439EaD55fa1c22790330b12835c6884a91"],
  ["holesky", "0x4e08B1F1AC79898569CfB999FB92B5495FB18A2B"],
]);
