// hardhat import should be the first import in the file
// import * as hardhat from "hardhat";
import * as fs from "fs";
import { ethers } from "ethers";

const LOGS_STRING =
  "tuple(address address2,bytes32[] topics,bytes data,bytes32 blockHash,uint256 blockNumber,uint256 blockTimestamp,bytes32 transactionHash,uint256 transactionIndex,uint256 logIndex,bool removed)";

type Logs = {
  address: string;
  topics: string[];
  data: ethers.BytesLike;
  blockHash: string;
  blockNumber: number;
  blockTimestamp: number;
  transactionHash: string;
  transactionIndex: number;
  logIndex: number;
  removed: boolean;
};

type Logs2 = {
  address2: string;
  topics: string[];
  data: ethers.BytesLike;
  blockHash: string;
  blockNumber: number;
  blockTimestamp: number;
  transactionHash: string;
  transactionIndex: number;
  logIndex: number;
  removed: boolean;
};

async function main() {
  const logsFile = JSON.parse(fs.readFileSync(`script-out/logs.json`, { encoding: "utf-8" }));

  const logs = logsFile.logs as Logs[];
  const logs2 = logs.map((log) => ({
    address2: log.address,
    ...log,
  })) as Logs2[];

  const encodedLogs = logs2.map((log) => ethers.AbiCoder.defaultAbiCoder().encode([LOGS_STRING], [log]));
  fs.writeFileSync(`script-out/encodedLogsLength.json`, JSON.stringify({ encodedLogsLength: logs2.length }, null, 2));
  for (let i = 0; i < encodedLogs.length; i++) {
    fs.writeFileSync(`script-out/encodedLogs/${i}.json`, JSON.stringify({ encodedLog: encodedLogs[i] }, null, 2));
  }
}

main()
  .then(() => process.exit(0))
  .catch((err) => {
    console.error("Error:", err.message || err);
    process.exit(1);
  });
