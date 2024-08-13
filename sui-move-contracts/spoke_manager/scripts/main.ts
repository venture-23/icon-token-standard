import {deploy} from '../scripts/utils/deploy';
import { configureSpokeManager } from './src/configure';
import * as dotenv from "dotenv";

dotenv.config();


const STORAGE = process.env.X_STORAGE || "";
const SOURCE = process.env.SOURCE || "";
const DESTINATION = process.env.DESTINATION || "";
const ICON_TOKEN = process.env.ICON_TOKEN || "";

async function main() {
    const result = await deploy();
    console.log(result);
    
    await configureSpokeManager(
        result?.packageId, 
        result?.AdminCap, 
        STORAGE, 
        result?.WitnessManager, 
        1, 
        ICON_TOKEN,
        [SOURCE],
        [DESTINATION],
    )
}

main()