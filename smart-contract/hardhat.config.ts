import fs from "fs";
import * as dotenv from "dotenv";
import { HardhatUserConfig, task } from "hardhat/config";
import "@nomiclabs/hardhat-etherscan";
import "@nomiclabs/hardhat-waffle";
import "@typechain/hardhat";
import "hardhat-gas-reporter";
import "solidity-coverage";
import CollectionConfig from "./config/CollectionConfig";

dotenv.config();

// This is a sample Hardhat task. To learn how to create your own go to
// https://hardhat.org/guides/create-task.html
task("accounts", "Prints the list of accounts", async (taskArgs, hre) => {
  const accounts = await hre.ethers.getSigners();

  for (const account of accounts) {
    console.log(account.address);
  }
});

task(
  "rename-contract",
  "Renames the smart contract replacing all occurrences in source files",
  async (taskArgs: { newName: string }, hre) => {
    // Validate new name
    if (!/^([A-Z][A-Za-z0-9]+)$/.test(taskArgs.newName)) {
      throw new Error(
        "The contract name must be in PascalCase: https://en.wikipedia.org/wiki/Camel_case#Variations_and_synonyms"
      );
    }

    const oldContractFile = `${__dirname}/contracts/${CollectionConfig.contractName}.sol`;
    const newContractFile = `${__dirname}/contracts/${taskArgs.newName}.sol`;

    if (!fs.existsSync(oldContractFile)) {
      throw new Error(
        `Contract file not found: "${oldContractFile}" (did you change the configuration manually?)`
      );
    }

    if (fs.existsSync(newContractFile)) {
      throw new Error(
        `A file with that name already exists: "${oldContractFile}"`
      );
    }

    // Replace names in source files
    replaceInFile(
      __dirname + "/../minting-dapp/src/scripts/lib/NftContractType.ts",
      CollectionConfig.contractName,
      taskArgs.newName
    );
    replaceInFile(
      __dirname + "/config/CollectionConfig.ts",
      CollectionConfig.contractName,
      taskArgs.newName
    );
    replaceInFile(
      __dirname + "/lib/NftContractProvider.ts",
      CollectionConfig.contractName,
      taskArgs.newName
    );
    replaceInFile(
      oldContractFile,
      CollectionConfig.contractName,
      taskArgs.newName
    );

    // Rename the contract file
    fs.renameSync(oldContractFile, newContractFile);

    console.log(
      `Contract renamed successfully from "${CollectionConfig.contractName}" to "${taskArgs.newName}"!`
    );

    // Rebuilding types
    await hre.run("typechain");
  }
).addPositionalParam("newName", "The new name");

// You need to export an object to set up your config
// Go to https://hardhat.org/config/ to learn more

const config: HardhatUserConfig = {
  solidity: {
    version: "0.8.12",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200,
      },
    },
  },
  networks: {
    hardhat: {},
    cypress: {
      url: process.env.CYPRESS_URL,
      httpHeaders: {
        Authorization:
          "Basic " +
          Buffer.from(
            process.env.ACCESS_KEY_ID + ":" + process.env.SECRET_ACCESS_KEY
          ).toString("base64"),
        "x-chain-id": "8217",
      },
      accounts: [process.env.PUBLIC_ADDRESS || ""],
      chainId: 8217,
      gas: 8500000,
    },
    baobab: {
      url: process.env.BAOBAB_URL,
      httpHeaders: {
        Authorization:
          "Basic " +
          Buffer.from(
            process.env.ACCESS_KEY_ID + ":" + process.env.SECRET_ACCESS_KEY
          ).toString("base64"),
        "x-chain-id": "1001",
      },
      accounts: [process.env.PUBLIC_ADDRESS || ""],
      chainId: 1001,
      gas: 8500000,
    },
  },
  mocha: {
    timeout: 100000,
  },
};

// Setup "testnet" network
if (process.env.NETWORK_TESTNET_URL !== undefined) {
  config.networks!.testnet = {
    url: process.env.NETWORK_TESTNET_URL,
    accounts: [process.env.PRIVATE_KEY!],
  };
}

// Setup "mainnet" network
if (process.env.NETWORK_MAINNET_URL !== undefined) {
  config.networks!.mainnet = {
    url: process.env.NETWORK_MAINNET_URL,
    accounts: [process.env.PRIVATE_KEY!],
  };
}

export default config;

/**
 * Replaces all occurrences of a string in the given file.
 */
function replaceInFile(file: string, search: string, replace: string): void {
  const fileContent = fs
    .readFileSync(file, "utf8")
    .replace(new RegExp(search, "g"), replace);

  fs.writeFileSync(file, fileContent, "utf8");
}
