import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";

const config: HardhatUserConfig = {
  solidity: "0.8.28",
  networks: {
    hardhat: {
      forking: {
        url: "https://bsc-mainnet.infura.io/v3/115ea3fab2d343859564cf95138116b1",
        blockNumber: 47613500,
        enabled: true
      },
      gas: 10_000_000,
      gasPrice: 5_000_000_000,
    }
  },
};

export default config;
