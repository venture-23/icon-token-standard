import { TransactionBlock } from "@mysten/sui.js/transactions";
import { deploymentConfig } from "../utils/execStuff";

function sleep(ms: number): Promise<void> {
    return new Promise(resolve =>{
        setTimeout(resolve, ms)
    })
}

export async function configureSpokeToken(
    packageId: string,
    admin: string, 
    storage: string,
    manager_config: string,
    witness_object: string,
    version: number,
    icon_token: string,
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
            tx.object(manager_config),
            tx.object(treasuryCap),
        ]
    });
   
    const result = await client.signAndExecuteTransactionBlock({
        signer: keypair,
        transactionBlock: tx
    });
    console.log(`[Configure Spoke Token] Tx hash: ${result.digest}`);
    await sleep(10000);
    let txb = await client.getTransactionBlock({
        digest: String(result.digest),
        options: {
            showEffects: true,
            showInput: false,
            showEvents: false,
            showObjectChanges: true,
            showBalanceChanges: false,
        },
    });

    let output: any;
    output = txb.objectChanges;
    let Config: string = "";
    for (let i = 0; i < output.length; i++) {
        const item = output[i];
        if (item.type === 'created') {
            if (item.objectType == `${packageId}::spoke_token::Config`) {
                Config = String(item.objectId);
            }
        }
    }
    console.log("Config ID: ", Config);
}