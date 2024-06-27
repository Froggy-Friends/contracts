import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import "@openzeppelin/hardhat-upgrades";
import "hardhat-contract-sizer";
import { vars } from 'hardhat/config';
import "./tasks";

const PRIVATE_KEY = vars.get('PRIVATE_KEY');
const ALCHEMY_API_KEY_ETH = vars.get('ALCHEMY_API_KEY_ETH');
const ALCHEMY_API_KEY_SEPOLIA = vars.get('ALCHEMY_API_KEY_SEPOLIA');
const ALCHEMY_API_KEY_BASE = vars.get('ALCHEMY_API_KEY_BASE');
const ALCHEMY_API_KEY_BLAST = vars.get('ALCHEMY_API_KEY_BLAST');
const ETHERSCAN_API_KEY = vars.get('ETHERSCAN_API_KEY');
const COINMARKETCAP_API_KEY = vars.get('COINMARKETCAP_API_KEY');

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
      url: ALCHEMY_API_KEY_ETH,
      accounts: [`0x${PRIVATE_KEY}`],
    },
    sepolia: {
      url: ALCHEMY_API_KEY_SEPOLIA,
      accounts: [`0x${PRIVATE_KEY}`],
    },
    base: {
      url: ALCHEMY_API_KEY_BASE,
      accounts: [`0x${PRIVATE_KEY}`],
      // verify: {
      //   etherscan: {
      //     apiUrl: "https://api.basescan.org/api",
      //     apiKey: vars.get('BASESCAN_API_KEY'),
      //   },
      // },
    },
    blast: {
      chainId: 81457,
      url: ALCHEMY_API_KEY_BLAST,
      accounts: [`0x${PRIVATE_KEY}`],
      // verify: {
      //   etherscan: {
      //     apiKey: vars.get('BLASTSCAN_API_KEY'),
      //     apiUrl: "https://api.blastscan.io/api",
      //   },
      // },
    },
    coverage: {
      url: "http://127.0.0.1:8555",
    },
  },
  etherscan: {
    // update when verifying other chains i.e. BASESCAN_API_KEY for Base
    apiKey: ETHERSCAN_API_KEY, 
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
