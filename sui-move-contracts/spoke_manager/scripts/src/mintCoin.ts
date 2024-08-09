import { TransactionBlock } from "@mysten/sui.js/transactions";
import { deploymentConfig } from "../utils/execStuff";

export async function mintDemoCoin(
    packageId: string,
    treasuryCap: string, 
    amount: number,
    recipient: string
) {
    const tx = new TransactionBlock();
    const { keypair, client, address } = await deploymentConfig();

    tx.moveCall({
        target: `${packageId}::test_coin::mint`,
        arguments: [
            tx.object(treasuryCap),
            tx.pure.u64(amount),
            tx.pure.address(recipient),
        ]
    });
   
    const result = await client.signAndExecuteTransactionBlock({
        signer: keypair,
        transactionBlock: tx
    });
    console.log(`[Mint demo coins] Tx hash: ${result.digest}`);
}