import CollectionConfigInterface from "../lib/CollectionConfigInterface";
import { klaytnTestnet, klaytnMainnet } from "../lib/Networks";
import { openSea } from "../lib/Marketplaces";

const CollectionConfig: CollectionConfigInterface = {
  testnet: klaytnTestnet,
  mainnet: klaytnMainnet,
  // The contract name can be updated using the following command:
  // yarn rename-contract NEW_CONTRACT_NAME
  // Please DO NOT change it manually!
  contractName: "Webe",
  tokenName: "WEBE",
  tokenSymbol: "WBE",
  hiddenMetadataUri:
    "https://weirdbears.s3.ap-northeast-2.amazonaws.com/hidden.png",
  contractAddress: "",
  marketplaceIdentifier: "webe",
  marketplaceConfig: openSea,
};

export default CollectionConfig;
