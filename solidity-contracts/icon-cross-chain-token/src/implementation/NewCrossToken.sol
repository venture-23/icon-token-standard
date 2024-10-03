// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import "@multi-token-standard/tokens/SpokeToken.sol";

contract NewCrossToken is SpokeToken {
    constructor() {
        _disableInitializers();
    }

    function initialize_token(
        string calldata name,
        string calldata symbol,
        address _xCall,
        string memory _iconTokenAddress,
        address _xCallManager
    ) public initializer {
        SpokeToken.initialize(
            name,
            symbol,
            _xCall,
            _iconTokenAddress,
            _xCallManager
        );
    }
}
