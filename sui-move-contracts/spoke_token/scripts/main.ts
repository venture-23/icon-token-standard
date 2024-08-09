import {deploy} from '../scripts/utils/deploy';
import { configure } from './src/configure';
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
    await configure(
        result?.packageId, 
        result?.AdminCapSpokeToken, 
        STORAGE, 
        result?.SpokeWitnessManager, 
        1, 
        ICON_TOKEN,
        [SOURCE],
        [DESTINATION],
        result?.TreasuryCap
    )
}

main()