import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import "@nomicfoundation/hardhat-chai-matchers";
import "@openzeppelin/hardhat-upgrades";
import "hardhat-deploy";
import "hardhat-contract-sizer";
import dotenv from "dotenv";
import "./tasks";
dotenv.config();

const {
  ALCHEMY_API_KEY,
  ALCHEMY_API_KEY_SEPOLIA,
  ALCHEMY_API_KEY_BASE,
  INFURA_API_KEY_BLAST,
  PRIVATE_KEY,
  ETHERSCAN_API_KEY,
  BASESCAN_API_KEY,
  BLASTSCAN_API_KEY,
  COINMARKETCAP_API_KEY,
} = process.env;

const config: HardhatUserConfig = {
  solidity: {
    version: "0.8.24",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200,
      },
    },
  },
  defaultNetwork: "sepolia",
  networks: {
    hardhat: {
      chainId: 1337,
    },
    mainnet: {
      url: ALCHEMY_API_KEY,
      accounts: [`0x${PRIVATE_KEY}`],
    },
    sepolia: {
      url: ALCHEMY_API_KEY_SEPOLIA,
      accounts: [`0x${PRIVATE_KEY}`],
    },
    base: {
      url: ALCHEMY_API_KEY_BASE,
      accounts: [`0x${PRIVATE_KEY}`],
      verify: {
        etherscan: {
          apiUrl: "https://api.basescan.org/api",
          apiKey: BASESCAN_API_KEY,
        },
      },
    },
    blast: {
      url: INFURA_API_KEY_BLAST,
      accounts: [`0x${PRIVATE_KEY}`],
      verify: {
        etherscan: {
          apiKey: BLASTSCAN_API_KEY,
          apiUrl: "https://api.blastscan.io/api",
        },
      },
    },
    coverage: {
      url: "http://127.0.0.1:8555",
    },
  },
  etherscan: {
    apiKey: ETHERSCAN_API_KEY, // update when verifying other chains i.e. BASESCAN_API_KEY for Base
    customChains: [
      {
        network: "base",
        chainId: 8453,
        urls: {
          apiURL: "https://api.basescan.org/api",
          browserURL: "https://basescan.org",
        },
      },
      {
        network: "blast",
        chainId: 81457,
        urls: {
          apiURL: "https://api.blastscan.io/api",
          browserURL: "https://blastscan.io",
        },
      },
    ],
  },
  gasReporter: {
    currency: "USD",
    enabled: false,
    coinmarketcap: COINMARKETCAP_API_KEY,
    gasPrice: 15,
  },
  typechain: {
    outDir: "types",
    target: "ethers-v5",
  },
  contractSizer: {
    alphaSort: true,
    disambiguatePaths: false,
    runOnCompile: false,
    strict: true,
    only: [],
  },
};

export default config;
