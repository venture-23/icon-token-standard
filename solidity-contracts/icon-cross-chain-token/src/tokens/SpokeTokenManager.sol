// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/console.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Utils.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";


import "multi-token-standard/library/utils/NetworkAddress.sol";
import "multi-token-standard/library/utils/Strings.sol";
import "multi-token-standard/library/utils/ParseAddress.sol";
import "multi-token-standard/library/interfaces/ICallService.sol";
import "multi-token-standard/library/interfaces/ICallServiceReceiver.sol";
import "multi-token-standard/library/interfaces/IXCallManager.sol";

import "./Messages.sol";
import "./RLPEncodeStruct.sol";
import "./RLPDecodeStruct.sol";

contract SpokeTokenManager is
    ERC20Upgradeable,
    ICallServiceReceiver,
    UUPSUpgradeable,
    OwnableUpgradeable
{
    using Strings for string;
    using NetworkAddress for string;
    using ParseAddress for address;
    using ParseAddress for string;
    using RLPEncodeStruct for Messages.XCrossTransfer;
    using RLPEncodeStruct for Messages.XCrossTransferRevert;
    using RLPDecodeStruct for bytes;
    using SafeERC20 for IERC20;

    address public xCall;
    address public token;
    string public xCallNetworkAddress;
    string public nid;
    string public iconTokenAddress;
    address xCallManager;

    address public constant NATIVE_ADDRESS = address(0);

    constructor() {
        _disableInitializers();
    }

    function initialize(
        address _token,
        address _xCall,
        string memory _iconTokenAddress,
        address _xcallManager
    ) public initializer {
        require(
            _xCall != address(0),
            "Zero address not allowed"
        );
        token = _token;
        xCall = _xCall;
        xCallNetworkAddress = ICallService(xCall).getNetworkAddress();
        nid = xCallNetworkAddress.nid();
        iconTokenAddress = _iconTokenAddress;
        xCallManager = _xcallManager;
        __Ownable_init(msg.sender);
    }

    /* ========== UUPS ========== */
    //solhint-disable-next-line no-empty-blocks
    function _authorizeUpgrade(address) internal override onlyOwner {}

    function getImplementation() external view returns (address) {
        return ERC1967Utils.getImplementation();
    }

    modifier onlyCallService() {
        require(msg.sender == xCall, "onlyCallService");
        _;
    }

    function crossTransfer(string memory to, uint value) external payable {
        _crossTransfer(to, value, "");
    }

    function crossTransfer(
        string memory to,
        uint value,
        bytes memory data
    ) external payable {
        _crossTransfer(to, value, data);
    }

    function _crossTransfer(
        string memory to,
        uint value,
        bytes memory data
    ) internal {
        require(value > 0, "Amount less than minimum amount");
        // transferred token from user address to contract 
        IERC20(token).transferFrom(msg.sender, address(this), value);
        string memory from = nid.networkAddress(msg.sender.toString());
        // Validate address
        to.parseNetworkAddress();
        Messages.XCrossTransfer memory xcallMessage = Messages.XCrossTransfer(
            from,
            to,
            value,
            data
        );

        Messages.XCrossTransferRevert memory rollback = Messages
            .XCrossTransferRevert(msg.sender, value);

        IXCallManager.Protocols memory protocols = IXCallManager(xCallManager)
            .getProtocols();
        ICallService(xCall).sendCallMessage{value: msg.value}(
            iconTokenAddress,
            xcallMessage.encodeCrossTransfer(),
            rollback.encodeCrossTransferRevert(),
            protocols.sources,
            protocols.destinations
        );
    }


    function handleCallMessage(
        string calldata from,
        bytes calldata data,
        string[] calldata protocols
    ) external onlyCallService {
        require(
            IXCallManager(xCallManager).verifyProtocols(protocols),
            "Protocol Mismatch"
        );
        
        string memory method = data.getMethod();
        if (method.compareTo(Messages.CROSS_TRANSFER)) {
            require(from.compareTo(iconTokenAddress), "onlyIconTokenAddress");
            Messages.XCrossTransfer memory message = data.decodeCrossTransfer();
            (, string memory to) = message.to.parseNetworkAddress();
            // transferred from contract to user 
            IERC20(token).transferFrom(address(this), to.parseAddress("Invalid address"), message.value);
        } else if (method.compareTo(Messages.CROSS_TRANSFER_REVERT)) {
            require(from.compareTo(xCallNetworkAddress), "onlyCallService");
            Messages.XCrossTransferRevert memory message = data
                .decodeCrossTransferRevert();
            IERC20(token).transferFrom(address(this), message.to, message.value);
        } else {
            revert("Unknown message type");
        }
    }
}
