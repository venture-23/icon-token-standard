import {SuiObjectChangePublished} from "@mysten/sui.js/client";
import { TransactionBlock } from "@mysten/sui.js/transactions";
import {deploymentConfig} from "./execStuff";

const {execSync} = require('child_process');
function sleep(ms: number): Promise<void> {
    return new Promise(resolve =>{
        setTimeout(resolve, ms)
    })
}

export async function deploy() {
    try {
        console.log("============start deployment=============");
        
        const { keypair, client, address } = await deploymentConfig();
        const packagePath = process.cwd();
        const { modules, dependencies } = JSON.parse(
            execSync(`sui move build --dump-bytecode-as-base64 --path ${packagePath} --skip-fetch-latest-git-deps`, {
                encoding: "utf-8",
            })
        );
        const tx = new TransactionBlock();
        const [upgradeCap] = tx.publish({
            modules,
            dependencies,
        });
        tx.transferObjects([upgradeCap], tx.pure(address));
        const result = await client.signAndExecuteTransactionBlock({
            signer: keypair,
            transactionBlock: tx,
            options: {
                showEffects: true,
                showObjectChanges: true,
            }
        });
        console.log(result.digest);
        const digest_ = result.digest;

        const packageId = ((result.objectChanges?.filter(
            (a: any) => a.type === 'published',
        ) as SuiObjectChangePublished[]) ?? [])[0].packageId.replace(/^(0x)(0+)/, '0x') as string;
        await sleep(10000);

        if (!digest_) {
            console.log("Digest is not available");
            return { packageId };
        }

        await client.getTransactionBlock({
            digest: String(digest_),
            // only fetch the effects and objects field
            options: {
                showEffects: true,
                showInput: false,
                showEvents: false,
                showObjectChanges: true,
                showBalanceChanges: false,
            },
        });

        let output: any;
        output = result.objectChanges;
        let  TreasuryCap: any, SpokeWitnessManager: any, AdminCapSpokeToken: any;
        for (let i = 0; i < output.length; i++) {
            const item = output[i];
            if (item.type === 'created') {
                if (item.objectType == `0x2::coin::TreasuryCap<${packageId}::test_coin::TEST_COIN>`) {
                    TreasuryCap = String(item.objectId);
                }
            }
            if (item.type === 'created') {
                if (item.objectType == `${packageId}::spoke_token::WitnessCarrier`) {
                    SpokeWitnessManager = String(item.objectId);
                }
            }

            if (item.type === 'created') {
                if (item.objectType == `${packageId}::spoke_token::AdminCap`) {
                    AdminCapSpokeToken = String(item.objectId);
                }
            }
        }
        return { packageId,  TreasuryCap, SpokeWitnessManager, AdminCapSpokeToken};
    } catch (error) {
        console.error(error);
        return { packageId: '',  TreasuryCap: '', SpokeWitnessManager:'', AdminCapSpokeToken:''};
    }
}