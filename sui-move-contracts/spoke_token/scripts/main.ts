import {deploy} from '../scripts/utils/deploy';
import { mintDemoCoin } from './src/mintCoin';

async function main() {
    const result = await deploy();
    console.log(result);

    await mintDemoCoin(result?.packageId, result?.TreasuryCap, 100, '0xfaef51a8054c15bb6b5e8a30e0bd42c141b96109b7ba127523fad4eca4017214');
}

main()