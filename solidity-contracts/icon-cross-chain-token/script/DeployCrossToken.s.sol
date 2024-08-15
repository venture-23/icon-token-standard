pragma solidity >=0.8.18;
import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import "@multi-token-standard/implementation/NewCrossToken.sol";
import "openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract DeployCrossToken is Script {

    using Strings for string;

    uint256 internal deployerPrivateKey;

    address xCallManager = 0xd5CECE180a52e0353654B3337c985E8d5E056344;
    constructor() {
        deployerPrivateKey = vm.envUint("PRIVATE_KEY");
    }

    modifier broadcast(uint256 privateKey) {
        vm.startBroadcast(privateKey);
        _;
        vm.stopBroadcast();
    }

    function deployContract() public broadcast(deployerPrivateKey) {
        NewCrossToken crossToken = new NewCrossToken(); 
        NewCrossToken newCrossToken = NewCrossToken(
            address(
                new ERC1967Proxy(
                    address(crossToken),
                    abi.encodeWithSelector(
                        crossToken.initialize.selector,
                        "NewCrossToken", 
                        "NCT",
                        0x28ecb198e86a7FcA1cf51032635967fc26cDDAaD,
                        "0x2.icon/cx38cfd5689c7951606d049c04b0a4a549c2910b6b",
                        xCallManager
                    )
                )
            )
        );
        console2.log(address(newCrossToken));
    }

}
