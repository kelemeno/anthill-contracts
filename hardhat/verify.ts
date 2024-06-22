// hardhat import should be the first import in the file
import * as hardhat from "hardhat";

// eslint-disable-next-line @typescript-eslint/no-explicit-any
function verifyPromise(address: string, constructorArguments?: Array<any>, libraries?: object): Promise<any> {
  return new Promise((resolve, reject) => {
    hardhat
      .run("verify:verify", { address, constructorArguments, libraries })
      .then(() => resolve(`Successfully verified ${address}`))
      .catch((e) => reject(`Failed to verify ${address}\nError: ${e.message}`));
  });
}

async function main() {
  const promises = [];

  // Contracts without constructor parameters
  for (const address of ["0xF3a4d6E6581e12Dc5b0eCd6EA3d483fF09c3cAE0"]) {
    const promise = verifyPromise(address);
    promises.push(promise);
  }

  // promises.push(verifyPromise(process.env.CONTRACTS_L2_SHARED_BRIDGE_IMPL_ADDR, [process.env.CONTRACTS_ERA_CHAIN_ID]));

  const messages = await Promise.allSettled(promises);
  for (const message of messages) {
    console.log(message.status == "fulfilled" ? message.value : message.reason);
  }
}

main()
  .then(() => process.exit(0))
  .catch((err) => {
    console.error("Error:", err.message || err);
    process.exit(1);
  });
