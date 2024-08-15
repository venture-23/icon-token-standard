import {deploy} from '../scripts/utils/deploy';
import { configureSpokeToken } from './src/configure';
import * as dotenv from "dotenv";

dotenv.config();


const STORAGE = process.env.X_STORAGE || "";
const SOURCE = process.env.SOURCE || "";
const MANAGER_CONFIG = process.env.MANAGER_CONFIG || "";
const ICON_TOKEN = process.env.ICON_TOKEN || "";

async function main() {
    const result = await deploy();
    console.log(result);

    await configureSpokeToken(
        result?.packageId, 
        result?.AdminCap, 
        STORAGE, 
        MANAGER_CONFIG,
        result?.WitnessManager, 
        1, 
        ICON_TOKEN,
        result?.TreasuryCap
    )    
}

main()