import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import "@nomicfoundation/hardhat-chai-matchers";
import "@openzeppelin/hardhat-upgrades";
import "hardhat-deploy";
import dotenv from "dotenv";
dotenv.config();

const { ALCHEMY_API_KEY_HOLESKY, ALCHEMY_API_KEY_STG, ALCHEMY_API_KEY, PRIVATE_KEY, ETHERSCAN_API_KEY, COINMARKETCAP_API_KEY } = process.env;

const config: HardhatUserConfig = {
  solidity: {
    version: "0.8.18",
    settings: {
      optimizer: {
        enabled: true,
        runs: 800,
      },
    },
  },
  defaultNetwork: "holesky",
  networks: {
    hardhat: {
      chainId: 1337
    },
    mainnet: {
      url: ALCHEMY_API_KEY,
      accounts: [`0x${PRIVATE_KEY}`],
    },
    goerli: {
      url: ALCHEMY_API_KEY_STG,
      accounts: [`0x${PRIVATE_KEY}`]
    },
    holesky: {
      url: ALCHEMY_API_KEY_HOLESKY,
      accounts: [`0x${PRIVATE_KEY}`]
    },
    coverage: {
      url: "http://127.0.0.1:8555"
    }
  },
  etherscan: {
    apiKey: ETHERSCAN_API_KEY,
    customChains: [
      {
        network: "holesky",
        chainId: 17000,
        urls: {
          apiURL: "https://api-holesky.etherscan.io/api",
          browserURL: "https://holesky.etherscan.io/"
        }
      }
    ]
  },
  gasReporter: {
    currency: 'USD',
    enabled: true,
    coinmarketcap: COINMARKETCAP_API_KEY,
    gasPrice: 15
  },
  typechain: {
    outDir: "types",
    target: "ethers-v5"
  }
};

export default config;
