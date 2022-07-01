import NetworkConfigInterface from "./NetworkConfigInterface";

export const klaytnTestnet: NetworkConfigInterface = {
  chainId: 1001,
  blockExplorer: {
    name: "Klayfinder",
    generateContractUrl: (contractAddress: string) =>
      `https://baobab.klaytnfinder.io/account/${contractAddress}`,
  },
};

export const klaytnMainnet: NetworkConfigInterface = {
  chainId: 8217,
  blockExplorer: {
    name: "Klayfinder",
    generateContractUrl: (contractAddress: string) =>
      `https://klaytnfinder.io/account/${contractAddress}`,
  },
};
