// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "forge-std/console.sol";

import "../../library/btp/interfaces/ICallService.sol";
import "../../src/mock/PlayToken.sol";
import "../../src/tokens/SpokeTokenManager.sol";
import "../../lib/openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract SpokeTokenManagerTest is Test {
    using Strings for string;
    using NetworkAddress for string;
    using ParseAddress for address;
    using ParseAddress for string;
    using RLPEncodeStruct for Messages.XCrossTransfer;
    using RLPEncodeStruct for Messages.XCrossTransferRevert;

    address public user = address(0x1234);
    address public owner = address(0x2345);

    event LogData(address sender, uint value, bytes data);

    PlayToken token;
    SpokeTokenManager spokeTokenManager;
    ICallService public xCall;
    string public constant nid = "0x1.eth";
    string public constant ICON_BNUSD = "0x1.icon/cx1";
    string[] defaultSources = ["0x05", "0x06"];
    string[] defaultDestinations = ["cx2", "cx3"];
    string[] wrongDestinations = ["cx4", "cx5", "cx6"];
    address public spokeTokenManagerAddress;

    function setUp() public {
        xCall = ICallService(address(0x01));
        vm.mockCall(
            address(xCall),
            abi.encodeWithSelector(xCall.getNetworkAddress.selector),
            abi.encode(nid.networkAddress(address(xCall).toString()))
        );

        token = new PlayToken(1000);
        spokeTokenManager = new SpokeTokenManager();
        spokeTokenManagerAddress = address(spokeTokenManager);
        vm.prank(owner);
        spokeTokenManager = SpokeTokenManager(
            address(
                new ERC1967Proxy(
                    spokeTokenManagerAddress,
                    abi.encodeWithSelector(
                        spokeTokenManager.initialize.selector,
                        address(token),
                        address(xCall),
                        ICON_BNUSD,
                        defaultSources,
                        defaultDestinations
                    )
                )
            )
        );
        console.log("SpokeTokenManager (Implementation) address:", spokeTokenManagerAddress);
        console.log("SpokeTokenManager (Proxy) address:", address(spokeTokenManager));
    }

    function testCrossTransferWithData() public {
        // Arrange
        uint amount = 100;
        uint256 fee = 10 ether;
        string memory to = "0x1.icon/hx1";
        bytes memory data = "test";
        vm.deal(user, fee);

        // tranfer some token to user 
        token.transfer(user, amount);

        // checking balance 
        assertEq(token.balanceOf(user), amount);
        assertEq(token.balanceOf(address(spokeTokenManager)), 0);

        // Approve the proxy address
        vm.prank(user);
        token.approve(address(spokeTokenManager), amount); 
        assertEq(token.allowance(user, address(spokeTokenManager)), amount);


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
        vm.prank(user);
        spokeTokenManager.crossTransfer{value: fee}(to, amount, data);

        // Assert
        assertEq(token.balanceOf(user), 0);
        assertEq(token.balanceOf(address(spokeTokenManager)), amount);
    }
}
