// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/console.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Utils.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";

import "../../library/btp/utils/NetworkAddress.sol";
import "../../library/btp/utils/Strings.sol";
import "../../library/btp/utils/ParseAddress.sol";
import "../../library/btp/interfaces/ICallService.sol";
import "../../library/btp/interfaces/ICallServiceReceiver.sol";

import "./Messages.sol";
import "./RLPEncodeStruct.sol";
import "./RLPDecodeStruct.sol";
import "../utils/SpokeUtils.sol";

contract SpokeToken is
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

    address public xCall;
    string public xCallNetworkAddress;
    string public nid;
    string public iconTokenAddress;
    string[] public sources;
    string[] public destinations;

    event ProtocolsConfigured(string[] sources, string[] destinations);

    constructor() {
        _disableInitializers();
    }

    function initialize(
        string calldata name,
        string calldata symbol,
        address _xCall,
        string memory _iconTokenAddress,
        string[] memory _source,
        string[] memory _destinatons
    ) public initializer {
        require(
            _xCall != address(0),
            "Zero address not allowed"
        );
        xCall = _xCall;
        xCallNetworkAddress = ICallService(xCall).getNetworkAddress();
        nid = xCallNetworkAddress.nid();
        iconTokenAddress = _iconTokenAddress;
        sources = _source;
        destinations = _destinatons;
        __ERC20_init(name, symbol);
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
        _burn(msg.sender, value);

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

        ICallService(xCall).sendCallMessage{value: msg.value}(
            iconTokenAddress,
            xcallMessage.encodeCrossTransfer(),
            rollback.encodeCrossTransferRevert(),
            sources,
            destinations
        );
    }

    function handleCallMessage(
        string calldata from,
        bytes calldata data,
        string[] calldata protocols
    ) external onlyCallService {
        require(SpokeUtils.verifyProtocolsUnordered(sources, protocols), "Protocol Mismatch");
        string memory method = data.getMethod();
        if (method.compareTo(Messages.CROSS_TRANSFER)) {
            require(from.compareTo(iconTokenAddress), "onlyiconTokenAddress");
            Messages.XCrossTransfer memory message = data.decodeCrossTransfer();
            (, string memory to) = message.to.parseNetworkAddress();
            _mint(to.parseAddress("Invalid account"), message.value);
        } else if (method.compareTo(Messages.CROSS_TRANSFER_REVERT)) {
            require(from.compareTo(xCallNetworkAddress), "onlyCallService");
            Messages.XCrossTransferRevert memory message = data
                .decodeCrossTransferRevert();
            _mint(message.to, message.value);
        } else {
            revert("Unknown message type");
        }
    }

    function setProtocols(
        string[] memory _sources,
        string[] memory _destinations
    ) external onlyOwner {
        require(
            !SpokeUtils.hasDuplicates(_sources),
            "Source protcols cannot contain duplicates"
        );
        require(
            !SpokeUtils.hasDuplicates(_destinations),
            "Destination protcols cannot contain duplicates"
        );
        sources = _sources;
        destinations = _destinations;

        emit ProtocolsConfigured(_sources, _destinations);

    }

}