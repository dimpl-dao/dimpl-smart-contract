import { ethers } from "hardhat";
const fs = require("fs");
const path = require("path");

function readFiles(
  dir: string,
  processFile: (arg0: any, arg1: any, arg2: any, arg3: any) => void
) {
  // read directory
  fs.readdir(dir, (error: any, fileNames: any[]) => {
    if (error) throw error;

    fileNames.forEach((filename: any) => {
      // get current file name
      const name = path.parse(filename).name;
      // get current file extension
      const ext = path.parse(filename).ext;
      // get current file path
      const filepath = path.resolve(dir, filename);

      // get information about the file
      fs.stat(filepath, function (error: any, stat: { isFile: () => any }) {
        if (error) throw error;

        // check if the current path is a file or a folder
        const isFile = stat.isFile();

        // exclude folders
        if (isFile) {
          // callback, do something with the file
          processFile(filepath, name, ext, stat);
        } else {
          readFiles(filepath, processFile);
        }
      });
    });
  });
}

async function main() {
  // Hardhat always runs the compile task when running scripts with its command
  // line interface.
  //
  // If this script is run directly using `node` you may want to call compile
  // manually to make sure everything is compiled
  // await hre.run('compile');

  readFiles("artifacts/contracts/", async (filepath, name, ext, stat) => {
    if (filepath.endsWith(".json") && !filepath.endsWith(".dbg.json")) {
      const json = await require(filepath);
      const iface = new ethers.utils.Interface(json.abi) as any;
      const abi = json.abi.map((fragment: any, index: number) => {
        if (fragment.type === "function") {
          const sighash = iface.getSighash(fragment.name);
          fragment.sighash = sighash;
        } else if (fragment.type === "event") {
          const topic = iface.getEventTopic(fragment.name);
          fragment.topic = topic;
        }
        fragment.signature = `${fragment.name || "contructor"}(${fragment.inputs
          .map((input: any) => input.internalType)
          .join(",")})`;
        return fragment;
      });
      json.abi = abi;
      fs.writeFile(filepath, JSON.stringify(json), (err: any) => {
        if (err) console.log(err);
        else {
          console.log("File written successfully\n");
        }
      });
    }
  });
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
