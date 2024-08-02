// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "forge-std/console.sol";

import "../../../src/implementation/AbcToken.sol";
import "../../../src/tokens/Messages.sol";

import "../../../library/btp/interfaces/ICallService.sol";
import "../../../src/interfaces/IXCallManager.sol";

import "../../../lib/openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol";



contract AbcTokenTest is Test {
    using Strings for string;
    using NetworkAddress for string;
    using ParseAddress for address;
    using ParseAddress for string;
    using RLPEncodeStruct for Messages.XCrossTransfer;
    using RLPEncodeStruct for Messages.XCrossTransferRevert;

    address public user = address(0x1234);
    address public owner = address(0x2345);


    AbcToken public abcToken;
    IXCallManager public xCallManager;
    ICallService public xCall;
    string public constant nid = "0x1.eth";
    string public constant ICON_BNUSD = "0x1.icon/cx1";
    string[] defaultSources = ["0x05", "0x06"];
    string[] defaultDestinations = ["cx2", "cx3"];
    string public constant name = "ABCTOKEN";
    string public constant symbol = "AT";
    string[] wrongDestinations= ["cx4", "cx5", "cx6"];

    function setUp() public {
        xCall = ICallService(address(0x01));
        xCallManager = IXCallManager(address(0x02));
        vm.mockCall(
            address(xCall),
            abi.encodeWithSelector(xCall.getNetworkAddress.selector),
            abi.encode(nid.networkAddress(address(xCall).toString()))
        );
        vm.mockCall(
            address(xCallManager),
            abi.encodeWithSelector(xCallManager.getProtocols.selector),
            abi.encode(
                IXCallManager.Protocols(defaultSources, defaultDestinations)
          
            )
        );
        vm.mockCall(
            address(xCallManager),
            abi.encodeWithSelector(xCallManager.verifyProtocols.selector),
            abi.encode(false)
        );
        vm.mockCall(
            address(xCallManager),
            abi.encodeWithSelector(
                xCallManager.verifyProtocols.selector,
                defaultSources
            ),
            abi.encode(true)
        );

        abcToken = new AbcToken();
        address abcTokenAddress = address(abcToken);
        vm.prank(owner);
        abcToken = AbcToken(
            address(
                new ERC1967Proxy(
                    abcTokenAddress,
                    abi.encodeWithSelector(
                        abcToken.initialize.selector,
                        name, 
                        symbol,
                        address(xCall),
                        ICON_BNUSD,
                        defaultSources,
                        defaultDestinations
                    )
                )
            )
        );
    }

    function testCrossTransfer() public {
        // Arrange
        uint amount = 100;
        uint256 fee = 10 ether;
        string memory to = "0x1.icon/hx1";
        vm.deal(user, fee);
        addTokens(user, amount);
        vm.prank(user);

        Messages.XCrossTransfer memory xcallMessage = Messages.XCrossTransfer(
            nid.networkAddress(user.toString()),
            to,
            amount,
            ""
        );
        Messages.XCrossTransferRevert memory rollback = Messages
            .XCrossTransferRevert(user, amount);

        vm.mockCall(
            address(xCall),
            fee,
            abi.encodeWithSelector(xCall.sendCallMessage.selector),
            abi.encode(0)
        );

        // Assert
        vm.expectCall(
            address(xCall),
            fee,
            abi.encodeWithSelector(
                xCall.sendCallMessage.selector,
                ICON_BNUSD,
                xcallMessage.encodeCrossTransfer(),
                rollback.encodeCrossTransferRevert(),
                defaultSources,
                defaultDestinations
            )
        );

        // Act
        abcToken.crossTransfer{value: fee}(to, amount);

        // Assert
        assertEq(abcToken.balanceOf(user), 0);
    }

    function testCrossTransferWithData() public {
        // Arrange
        uint amount = 100;
        uint256 fee = 10 ether;
        string memory to = "0x1.icon/hx1";
        bytes memory data = "test";
        vm.deal(user, fee);
        addTokens(user, amount);
        vm.prank(user);

        Messages.XCrossTransfer memory xcallMessage = Messages.XCrossTransfer(
            nid.networkAddress(user.toString()),
            to,
            amount,
            data
        );
        Messages.XCrossTransferRevert memory rollback = Messages
            .XCrossTransferRevert(user, amount);

        vm.mockCall(
            address(xCall),
            fee,
            abi.encodeWithSelector(xCall.sendCallMessage.selector),
            abi.encode(0)
        );

        // Assert
        vm.expectCall(
            address(xCall),
            fee,
            abi.encodeWithSelector(
                xCall.sendCallMessage.selector,
                ICON_BNUSD,
                xcallMessage.encodeCrossTransfer(),
                rollback.encodeCrossTransferRevert(),
                defaultSources,
                defaultDestinations
            )
        );

        // Act
        abcToken.crossTransfer{value: fee}(to, amount, data);

        // Assert
        assertEq(abcToken.balanceOf(user), 0);
    }

    function testhandleCallMessage_OnlyXCall() public {
        // Arrange
        vm.prank(user);

        // Assert
        vm.expectRevert("onlyCallService");

        // Act
        abcToken.handleCallMessage("", "", defaultSources);
    }

    function testhandleCallMessage_InvalidProtocol() public {
        // Arrange
        vm.prank(address(xCall));

        // Assert
        vm.expectRevert("Protocol Mismatch");

        // Act
        abcToken.handleCallMessage("", "", wrongDestinations);
    }

    function testReceiveCrossTransfer_onlyICONBnUSD() public {
        // Arrange
        vm.prank(address(xCall));
        uint amount = 100;

        Messages.XCrossTransfer memory message = Messages.XCrossTransfer(
            "",
            nid.networkAddress(user.toString()),
            amount,
            ""
        );

        // Assert
        vm.expectRevert("onlyiconTokenAddress");

        // Act
        abcToken.handleCallMessage(
            "Not ICON bnUSD",
            message.encodeCrossTransfer(),
            defaultSources
        );
    }

    function testReceiveCrossTransferRevert() public {
        // Arrange
        vm.prank(address(xCall));
        uint amount = 100;

        Messages.XCrossTransferRevert memory message = Messages
            .XCrossTransferRevert(user, amount);

        // Act
        abcToken.handleCallMessage(
            nid.networkAddress(address(xCall).toString()),
            message.encodeCrossTransferRevert(),
            defaultSources
        );

        // Assert
        assertEq(abcToken.balanceOf(user), amount);
    }

    function testReceiveCrossTransferRevert_onlyXCall() public {
        // Arrange
        vm.prank(address(xCall));
        uint amount = 100;

        Messages.XCrossTransferRevert memory message = Messages
            .XCrossTransferRevert(user, amount);

        // Assert
        vm.expectRevert("onlyCallService");

        // Act
        abcToken.handleCallMessage(
            ICON_BNUSD,
            message.encodeCrossTransferRevert(),
            defaultSources
        );
    }

    function addTokens(address account, uint amount) public {
        vm.prank(address(xCall));
        Messages.XCrossTransfer memory message = Messages.XCrossTransfer(
            "",
            nid.networkAddress(account.toString()),
            amount,
            ""
        );

        abcToken.handleCallMessage(
            ICON_BNUSD,
            message.encodeCrossTransfer(),
            defaultSources
        );
    }

    function testUpgrade_notOwner() public {
        // Arrange
        address abcTokenAddress = address(new SpokeToken());
        vm.prank(user);

        // Assert
        vm.expectRevert(
            abi.encodeWithSelector(
                OwnableUpgradeable.OwnableUnauthorizedAccount.selector,
                user
            )
        );
        abcToken.upgradeToAndCall(abcTokenAddress, "");
    }

    function testUpgrade() public {
        // Arrange
        address abcTokenAddress = address(new SpokeToken());
        vm.prank(owner);

        // Act
        abcToken.upgradeToAndCall(abcTokenAddress, "");

        // Assert
        assertEq(abcTokenAddress, abcToken.getImplementation());
    }
   
}