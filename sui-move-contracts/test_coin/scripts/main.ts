import {deploy} from '../scripts/utils/deploy';
import * as dotenv from "dotenv";

dotenv.config();

async function main() {
    const result = await deploy();
    console.log(result);  
}

main()