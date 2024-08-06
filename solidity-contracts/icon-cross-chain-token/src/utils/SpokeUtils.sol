// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.8.0;

import "../../library/btp/utils/Strings.sol";

library SpokeUtils {

    using Strings for string;


    function hasDuplicates(string[] memory arr) public pure returns (bool) {
        for (uint i = 0; i < arr.length; i++) {
            for (uint j = i + 1; j < arr.length; j++) {
                if (
                    keccak256(abi.encodePacked(arr[i])) ==
                    keccak256(abi.encodePacked(arr[j]))
                ) {
                    return true;
                }
            }
        }
        return false;
    }

    // Verifies that all required protocols exists in the protocols used for delivery.
    function verifyProtocolsUnordered(
        string[] memory requiredProtocols,
        string[] memory deliveryProtocols
    ) public pure returns (bool) {
        // Check if the arrays have the same length
        if (requiredProtocols.length != deliveryProtocols.length) {
            return false;
        }

        for (uint i = 0; i < requiredProtocols.length; i++) {
            for (uint j = 0; j < deliveryProtocols.length; j++) {
                if (requiredProtocols[i].compareTo(deliveryProtocols[j])) {
                    break;
                }
                if (j == deliveryProtocols.length - 1) return false;
            }
        }

        return true;
    }


}