const { MerkleTree } = require("merkletreejs");
const keccak256 = require("keccak256");

let whitelistAddr = [
  "0x3733bDCA4daBf8aFE2C7fd513812d8343165E8ed",
  "0x06A3D819149D719D267Afa9FCDC5Eb192A0431CB",
];

const leafNodes = whitelistAddr.map((addr) => keccak256(addr));
const merkleTree = new MerkleTree(leafNodes, keccak256, { sortPairs: true });

const rootHash = merkleTree.getRoot();
console.log("ROOT: ", rootHash.toString("base64"));
