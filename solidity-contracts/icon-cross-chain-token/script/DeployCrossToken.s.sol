pragma solidity >=0.8.18;
import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import "@multi-token-standard/implementation/NewCrossToken.sol";
import "openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "@multi-token-standard/tokens/SpokeTokenManager.sol";

contract DeployCrossToken is Script {

    using Strings for string;

    uint256 internal deployerPrivateKey;
    SpokeTokenManager spokeTokenManager;
    address public spokeTokenManagerAddress;


    constructor() {
        deployerPrivateKey = vm.envUint("PRIVATE_KEY");
    }

    modifier broadcast(uint256 privateKey) {
        vm.startBroadcast(privateKey);
        _;
        vm.stopBroadcast();
    }

    function deployNewCrossTokenContract(string memory name, string memory symbol, address xCall, address iconTokenAddress, address xCallManager) public broadcast(deployerPrivateKey) {
        NewCrossToken crossToken = new NewCrossToken(); 
        NewCrossToken newCrossToken = NewCrossToken(
            address(
                new ERC1967Proxy(
                    address(crossToken),
                    abi.encodeWithSelector(
                        crossToken.initialize.selector,
                        name,
                        symbol,
                        xCall,
                        iconTokenAddress,
                        xCallManager
                    )
                )
            )
        );
        console2.log(address(newCrossToken));
    }

    function deploySpokeTokenManager(address token, address xCall, address iconTokenAddress, address xCallManager) public broadcast(deployerPrivateKey) {
        spokeTokenManager = new SpokeTokenManager();
        spokeTokenManagerAddress = address(spokeTokenManager);
        spokeTokenManager = SpokeTokenManager(
            address(
                new ERC1967Proxy(
                    spokeTokenManagerAddress,
                    abi.encodeWithSelector(
                        spokeTokenManager.initialize.selector,
                        address(token), 
                        address(xCall),
                        iconTokenAddress,
                        address(xCallManager)
                    )
                )
            )
        );
        console2.log("SpokeTokenManager (Implementation) address:", spokeTokenManagerAddress);
        console2.log("SpokeTokenManager (Proxy) address:", address(spokeTokenManager));
    }

}
