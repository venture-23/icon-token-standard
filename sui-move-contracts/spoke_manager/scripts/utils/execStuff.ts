
import {getFullnodeUrl, SuiClient} from "@mysten/sui.js/client";
import { Ed25519Keypair  } from "@mysten/sui.js/keypairs/ed25519";
import * as dotenv from "dotenv";

dotenv.config();
 type network_type = "mainnet" | "testnet" | "devnet" | "localnet";

const MNEMONICS = process.env.MNEMONICS || "";
const NETWORK  = process.env.NETWORK as network_type;
const ADDRESS = process.env.ADDRESS || "";

export async function deploymentConfig() {
    const keypair = Ed25519Keypair.deriveKeypair(MNEMONICS);
    const address = ADDRESS;
    const client = new SuiClient({
        url: getFullnodeUrl(NETWORK),
    });
    return {keypair, client, address};
}
