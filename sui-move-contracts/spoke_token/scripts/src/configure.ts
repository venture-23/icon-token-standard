import { TransactionBlock } from "@mysten/sui.js/transactions";
import { deploymentConfig } from "../utils/execStuff";

export async function configure(
    packageId: string,
    admin: string, 
    storage: string, 
    witness_object: string,
    version: number,
    icon_token: string,
    sources: Array<string>,
    destination: Array<string>,
    treasuryCap: string
) {
    const tx = new TransactionBlock();
    const { keypair, client, address } = await deploymentConfig();

    tx.moveCall({
        target: `${packageId}::spoke_token::configure`,
        arguments: [
            tx.object(admin),
            tx.object(storage),
            tx.object(witness_object),
            tx.pure.u64(version),
            tx.pure.string(icon_token),
            tx.pure(sources),
            tx.pure(destination),
            tx.object(treasuryCap),
        ]
    });
   
    const result = await client.signAndExecuteTransactionBlock({
        signer: keypair,
        transactionBlock: tx
    });
    console.log(`[Mint demo coins] Tx hash: ${result.digest}`);
}