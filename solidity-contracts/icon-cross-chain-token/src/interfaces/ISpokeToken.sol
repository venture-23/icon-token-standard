// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/console.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Utils.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";

interface  ISpokeToken {

    /**
     * Returns the account balance of another account with string address {@param _owner},
     * which can be both ICON and BTP Address format.
    */
    function xBalanceOf(string calldata _owner) external view returns (uint256[] memory);

    
    /**
     * If {@param _to} is a EVM address, use ERC20 transfer
     * Transfers {@param _value} amount of tokens to BTP address {@param _to},
     * and MUST fire the {HubTransfer} event.
     * This function SHOULD throw if the caller account balance does not have enough tokens to spend.
     */
    function hubTransfer(
        string calldata _to,
        uint256[] memory _value,
        bytes calldata _data

    ) external;


    /**
     * Callable only via XCall service on EVM.
    */
    function xHubTransfer(
        string calldata from,
        string calldata _to,
        uint256[] memory _value,
        bytes calldata _data
    ) external;

    /**
     * (EventLog) Must trigger on any successful hub token transfers.
     */
    event HubTransfer(
        string  _from,
        string  _to,
        uint256[]  _value,
        bytes[] _data
    );


}
