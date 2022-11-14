import NetworkConfigInterface from "../lib/NetworkConfigInterface";
import MarketplaceConfigInterface from "../lib/MarketplaceConfigInterface";

export default interface CollectionConfigInterface {
  testnet: NetworkConfigInterface;
  mainnet: NetworkConfigInterface;
  contractName: string;
  tokenName: string;
  tokenSymbol: string;
  hiddenMetadataUri: string;
  marketplaceIdentifier: string;
  contractAddress: string;
  marketplaceConfig: MarketplaceConfigInterface;
}
