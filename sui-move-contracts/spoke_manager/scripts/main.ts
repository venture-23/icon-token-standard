import {deploy} from '../scripts/utils/deploy';
import { configureSpokeManager } from './src/configure';
import * as dotenv from "dotenv";

dotenv.config();


const STORAGE = process.env.ICON_STORAGE || "";
const SOURCE = process.env.SOURCE || "";
const DESTINATION = process.env.DESTINATION || "";
const ICON_TOKEN = process.env.ICON_TOKEN || "";

async function main() {
    const result = await deploy();
    console.log(result);

    // await mintDemoCoin(result?.packageId, result?.TreasuryCap, 100, '');
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