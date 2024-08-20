import {deploy} from '../scripts/utils/deploy';
import { configureSpokeToken } from './src/configure';
import * as dotenv from "dotenv";

dotenv.config();


const STORAGE = process.env.X_STORAGE || "";
const MANAGER_CONFIG = process.env.MANAGER_CONFIG || "";
const ICON_TOKEN = process.env.ICON_TOKEN || "";
const TREASURY_CAP = process.env.TREASURY_CAP || "";

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
        TREASURY_CAP
    )    
}

main()