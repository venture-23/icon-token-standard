package icon.cross.chain.token.lib.tokens;

import com.iconloop.score.test.Account;
import com.iconloop.score.test.Score;
import com.iconloop.score.test.ServiceManager;
import com.iconloop.score.test.TestBase;
import foundation.icon.xcall.NetworkAddress;
import icon.cross.chain.token.lib.interfaces.tokens.XCall;
import icon.cross.chain.token.lib.interfaces.tokens.XCallScoreInterface;
import icon.cross.chain.token.lib.interfaces.tokens.XTokenReceiver;
import icon.cross.chain.token.lib.interfaces.tokens.XTokenReceiverScoreInterface;
import icon.cross.chain.token.lib.mock.MockContract;
import icon.cross.chain.token.lib.utils.HubTokenMessages;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.function.Executable;
import org.mockito.AdditionalMatchers;
import org.mockito.Mockito;
import score.Address;
import score.Context;

import java.math.BigInteger;

import static java.math.BigInteger.TEN;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.Mockito.*;

class HubTokenTest extends TestBase {
    private static final String name = "HubToken";
    private static final String symbol = "HUB";
    private static final BigInteger decimals = BigInteger.valueOf(18);

    private static final BigInteger totalSupply = BigInteger.valueOf(100000).multiply(TEN.pow(decimals.intValue()));
    private static final ServiceManager sm = getServiceManager();
    private static final Account owner = sm.createAccount();

    private static Score tokenScore;

    private static MockContract<XTokenReceiver> receiverContract;
    private static MockContract<XCall> xCall;
    private static HubTokenTester tokenSpy;
    private static String ethNid = "1.ETH";
    private static String bscNid = "1.BSC";
    private static String ICON_NID = "1.ICON";
    private static NetworkAddress ethereumSpokeAddress = new NetworkAddress(ethNid, "0x1");
    private static NetworkAddress bscSpokeAddress = new NetworkAddress(bscNid, "0x2");
    private static BigInteger baseLimit = totalSupply;

    String[] sources = new String[]{"a", "b"};
    String[] destinations = new String[]{"c", "d"};


    public static class HubTokenTester extends HubTokenImpl {
        public HubTokenTester(Address _xCall, String[] _sources, String[] _destinations, String _nid,
                              String _tokenName, String _symbolName, BigInteger _decimals, BigInteger _initialSupply) {
            super(_xCall, _sources, _destinations, _nid, _tokenName, _symbolName, _decimals);

            // mint the initial token supply here
            mint(new NetworkAddress(_nid, Context.getCaller()), _initialSupply);
        }
    }

    @BeforeEach
    public void setup() throws Exception {
        xCall = new MockContract<>(XCallScoreInterface.class, sm, owner);
        tokenScore = sm.deploy(owner, HubTokenTester.class,
                xCall.getAddress(), sources, destinations, ICON_NID, name, symbol, decimals, totalSupply);
        tokenSpy = (HubTokenTester) spy(tokenScore.getInstance());
        tokenScore.setInstance(tokenSpy);
        receiverContract = new MockContract<>(XTokenReceiverScoreInterface.class, sm, owner);
        tokenScore.invoke(owner, "addChain", ethereumSpokeAddress.toString(), baseLimit);
        tokenScore.invoke(owner, "addChain", bscSpokeAddress.toString(), baseLimit);
    }

    @Test
    void crossTransfer_ICONUserToICONUser() {
        // Arrange
        Account alice = sm.createAccount();
        Account bob = sm.createAccount();
        BigInteger amount = BigInteger.TWO.pow(18);
        addBalance(alice, amount);

        // Act
        tokenScore.invoke(alice, "crossTransfer", new NetworkAddress(ICON_NID, bob.getAddress()).toString(), amount, new byte[0]);

        // Assert
        assertEquals(BigInteger.ZERO, balanceOf(alice));
        assertEquals(amount, balanceOf(bob));
        verify(tokenSpy).Transfer(alice.getAddress(), bob.getAddress(), amount, new byte[0]);
    }

    @Test
    void crossTransfer_ICONUserToSpoke() {
        // Arrange
        Account alice = sm.createAccount();
        NetworkAddress aliceNetworkAddress = new NetworkAddress(ICON_NID, alice.getAddress());
        NetworkAddress bob = new NetworkAddress(ethNid, "0x32");
        BigInteger amount = BigInteger.TWO.pow(18);
        addBalance(alice, amount);
        tokenScore.invoke(owner, "configureProtocols", ethNid, sources, destinations);
        tokenScore.invoke(owner, "configureProtocols", bscNid, sources, destinations);

        byte[] expectedCallData = HubTokenMessages.xCrossTransfer(aliceNetworkAddress.toString(), bob.toString(), amount, new byte[0]);
        byte[] expectedRollbackData = HubTokenMessages.xCrossTransferRevert(bob.toString(), amount);

        // Act
        tokenScore.invoke(alice, "crossTransfer", bob.toString(), amount, new byte[0]);

        // Assert
        assertEquals(BigInteger.ZERO, balanceOf(alice));
        assertEquals(BigInteger.ZERO, balanceOf(bob));
        assertEquals(totalSupply, tokenScore.call("xTotalSupply"));
        assertEquals(amount, tokenScore.call("xSupply", ethereumSpokeAddress.net()));
        verify(tokenSpy).XTransfer(aliceNetworkAddress.toString(), bob.toString(), amount, new byte[0]);
        verify(xCall.mock).sendCallMessage(Mockito.eq(ethereumSpokeAddress.toString()),
                AdditionalMatchers.aryEq(expectedCallData),
                AdditionalMatchers.aryEq(expectedRollbackData),
                AdditionalMatchers.aryEq(sources),
                AdditionalMatchers.aryEq(destinations));
    }

    @Test
    void crossTransfer_spokeToICONUser() {
        // Arrange
        NetworkAddress alice = new NetworkAddress(ethNid, "0x32");
        Account bob = sm.createAccount();
        NetworkAddress bobNetworkAddress = new NetworkAddress(ICON_NID, bob.getAddress());
        BigInteger amount = BigInteger.TWO.pow(18);
        tokenScore.invoke(owner, "configureProtocols", ethNid, sources, destinations);
        tokenScore.invoke(owner, "configureProtocols", bscNid, sources, destinations);

        tokenScore.invoke(owner, "crossTransfer", alice.toString(), amount, new byte[0]);

        // Act
        byte[] msg = HubTokenMessages.xCrossTransfer(alice.toString(), bobNetworkAddress.toString(), amount, new byte[0]);
        tokenScore.invoke(xCall.account, "handleCallMessage", ethereumSpokeAddress.toString(), msg, sources);

        // Assert
        assertEquals(BigInteger.ZERO, balanceOf(alice));
        assertEquals(amount, balanceOf(bob));
        assertEquals(totalSupply, tokenScore.call("xTotalSupply"));
        assertEquals(BigInteger.ZERO, tokenScore.call("xSupply", ethereumSpokeAddress.net()));
        assertEquals(BigInteger.ZERO, tokenScore.call("xSupply", bscSpokeAddress.net()));
        verify(tokenSpy).XTransfer(alice.toString(), bobNetworkAddress.toString(), amount, new byte[0]);
    }

    @Test
    void crossTransfer_spokeToICONContract() {
        // Arrange
        NetworkAddress alice = new NetworkAddress(ethNid, "0x32");
        NetworkAddress receiverContractNetworkAddress = new NetworkAddress(ICON_NID, receiverContract.getAddress());
        BigInteger amount = BigInteger.TWO.pow(18);
        byte[] data = "test".getBytes();
        tokenScore.invoke(owner, "configureProtocols", ethNid, sources, destinations);
        tokenScore.invoke(owner, "configureProtocols", bscNid, sources, destinations);

        tokenScore.invoke(owner, "crossTransfer", alice.toString(), amount, data);

        // Act
        byte[] msg = HubTokenMessages.xCrossTransfer(alice.toString(), receiverContractNetworkAddress.toString(), amount, data);
        tokenScore.invoke(xCall.account, "handleCallMessage", ethereumSpokeAddress.toString(), msg, sources);

        // Assert
        assertEquals(BigInteger.ZERO, balanceOf(alice));
        assertEquals(amount, balanceOf(receiverContract.account));
        assertEquals(totalSupply, tokenScore.call("xTotalSupply"));
        assertEquals(BigInteger.ZERO, tokenScore.call("xSupply", ethereumSpokeAddress.net()));
        verify(tokenSpy).XTransfer(Mockito.eq(alice.toString()), Mockito.eq(receiverContractNetworkAddress.toString()), Mockito.eq(amount), AdditionalMatchers.aryEq(data));
        verify(receiverContract.mock).xTokenFallback(Mockito.eq(alice.toString()), Mockito.eq(amount), AdditionalMatchers.aryEq(data));
    }

    @Test
    void crossTransfer_ICONUserToSpoke_rollback() {
        // Arrange
        Account alice = sm.createAccount();
        NetworkAddress aliceNetworkAddress = new NetworkAddress(ICON_NID, alice.getAddress());
        NetworkAddress bob = new NetworkAddress(ethNid, "0x32");
        NetworkAddress xCallNetworkAddress = new NetworkAddress(ICON_NID,  xCall.getAddress().toString());
        BigInteger amount = BigInteger.TWO.pow(18);
        addBalance(alice, amount);
        tokenScore.invoke(owner, "configureProtocols", ethNid, sources, destinations);
        tokenScore.invoke(owner, "configureProtocols", bscNid, sources, destinations);

        byte[] expectedCallData = HubTokenMessages.xCrossTransfer(aliceNetworkAddress.toString(), bob.toString(), amount, new byte[0]);
        byte[] expectedRollbackData = HubTokenMessages.xCrossTransferRevert(bob.toString(), amount);
        tokenScore.invoke(alice, "crossTransfer", bob.toString(), amount, new byte[0]);
        verify(xCall.mock).sendCallMessage(Mockito.eq(ethereumSpokeAddress.toString()),
                AdditionalMatchers.aryEq(expectedCallData),
                AdditionalMatchers.aryEq(expectedRollbackData),
                AdditionalMatchers.aryEq(sources),
                AdditionalMatchers.aryEq(destinations));
        // Act
        tokenScore.invoke(xCall.account, "handleCallMessage", xCallNetworkAddress.toString(), expectedRollbackData, sources);

        // Assert
        assertEquals(BigInteger.ZERO, balanceOf(alice));
        assertEquals(amount, balanceOf(bob));
        assertEquals(totalSupply, tokenScore.call("xTotalSupply"));
        assertEquals(BigInteger.ZERO, tokenScore.call("xSupply", ethereumSpokeAddress.net()));
        assertEquals(BigInteger.ZERO, tokenScore.call("xSupply", bscSpokeAddress.net()));
    }

    @Test
    void crossTransfer_SpokeToSpoke() {
        // Arrange
        NetworkAddress alice = new NetworkAddress(bscNid, "0x35");
        NetworkAddress bob = new NetworkAddress(ethNid, "0x32");
        BigInteger amount = BigInteger.TWO.pow(18);
        tokenScore.invoke(owner, "configureProtocols", ethNid, sources, destinations);
        tokenScore.invoke(owner, "configureProtocols", bscNid, sources, destinations);

        tokenScore.invoke(owner, "crossTransfer", alice.toString(), amount, new byte[0]);

        byte[] expectedCallData = HubTokenMessages.xCrossTransfer(bob.toString(), bob.toString(), amount, new byte[0]);
        byte[] expectedRollbackData = HubTokenMessages.xCrossTransferRevert(bob.toString(), amount);

        when(tokenSpy.getHopFee(bob.net())).thenReturn(BigInteger.TEN);

        // Act
        byte[] msg = HubTokenMessages.xCrossTransfer(alice.toString(), bob.toString(), amount, new byte[0]);
        tokenScore.invoke(xCall.account, "handleCallMessage", bscSpokeAddress.toString(), msg, sources);

        // Assert
        assertEquals(BigInteger.ZERO, balanceOf(alice));
        assertEquals(BigInteger.ZERO, balanceOf(bob));
        assertEquals(totalSupply, tokenScore.call("xTotalSupply"));
        assertEquals(amount, tokenScore.call("xSupply", ethereumSpokeAddress.net()));
        assertEquals(BigInteger.ZERO, tokenScore.call("xSupply", bscSpokeAddress.net()));
        verify(tokenSpy).XTransfer(bob.toString(), bob.toString(), amount, new byte[0]);
        verify(xCall.mock).sendCallMessage(Mockito.eq(ethereumSpokeAddress.toString()),
                AdditionalMatchers.aryEq(expectedCallData),
                AdditionalMatchers.aryEq(expectedRollbackData),
                AdditionalMatchers.aryEq(sources),
                AdditionalMatchers.aryEq(destinations));
    }

    @Test
    void crossTransfer_SpokeToSpoke_withoutFeeLogic() {
        // Arrange
        NetworkAddress alice = new NetworkAddress(bscNid, "0x35");
        NetworkAddress bob = new NetworkAddress(ethNid, "0x32");
        BigInteger amount = BigInteger.TWO.pow(18);
        tokenScore.invoke(owner, "configureProtocols", ethNid, sources, destinations);
        tokenScore.invoke(owner, "configureProtocols", bscNid, sources, destinations);

        tokenScore.invoke(owner, "crossTransfer", alice.toString(), amount, new byte[0]);

        // Act
        byte[] msg = HubTokenMessages.xCrossTransfer(alice.toString(), bob.toString(), amount, new byte[0]);
        tokenScore.invoke(xCall.account, "handleCallMessage", bscSpokeAddress.toString(), msg, sources);

        // Assert
        assertEquals(BigInteger.ZERO, balanceOf(alice));
        assertEquals(amount, balanceOf(bob));
        assertEquals(totalSupply, tokenScore.call("xTotalSupply"));
        assertEquals(BigInteger.ZERO, tokenScore.call("xSupply", ethereumSpokeAddress.net()));
        assertEquals(BigInteger.ZERO, tokenScore.call("xSupply", bscSpokeAddress.net()));
        verify(tokenSpy).XTransfer(alice.toString(), bob.toString(), amount, new byte[0]);
    }

    @Test
    void crossTransfer_SpokeToSpoke_withFee() {
        // Arrange
        NetworkAddress alice = new NetworkAddress(bscNid, "0x35");
        NetworkAddress bob = new NetworkAddress(ethNid, "0x32");
        BigInteger amount = BigInteger.TWO.pow(18);
        BigInteger xCallFee = BigInteger.TEN;
        BigInteger fee = BigInteger.valueOf(7);
        tokenScore.invoke(owner, "configureProtocols", ethNid, sources, destinations);
        tokenScore.invoke(owner, "configureProtocols", bscNid, sources, destinations);

        tokenScore.invoke(owner, "crossTransfer", alice.toString(), amount, new byte[0]);

        when(tokenSpy.getHopFee(bob.net())).thenReturn(xCallFee);
        when(tokenSpy.getTokenFee(bob.net(), xCallFee, amount)).thenReturn(fee);

        byte[] msg = HubTokenMessages.xCrossTransfer(alice.toString(), bob.toString(), amount, new byte[0]);
        amount = amount.subtract(fee);

        byte[] expectedCallData = HubTokenMessages.xCrossTransfer(bob.toString(), bob.toString(), amount, new byte[0]);
        byte[] expectedRollbackData = HubTokenMessages.xCrossTransferRevert(bob.toString(), amount);

        // Act
        tokenScore.invoke(xCall.account, "handleCallMessage", bscSpokeAddress.toString(), msg, sources);

        // Assert
        assertEquals(BigInteger.ZERO, balanceOf(alice));
        assertEquals(BigInteger.ZERO, balanceOf(bob));
        assertEquals(totalSupply.subtract(fee), tokenScore.call("xTotalSupply"));
        assertEquals(amount, tokenScore.call("xSupply", ethereumSpokeAddress.net()));
        assertEquals(BigInteger.ZERO, tokenScore.call("xSupply", bscSpokeAddress.net()));
        verify(tokenSpy).XTransfer(bob.toString(), bob.toString(), amount, new byte[0]);
        verify(xCall.mock).sendCallMessage(Mockito.eq(ethereumSpokeAddress.toString()),
                AdditionalMatchers.aryEq(expectedCallData),
                AdditionalMatchers.aryEq(expectedRollbackData),
                AdditionalMatchers.aryEq(sources),
                AdditionalMatchers.aryEq(destinations));
    }

    @Test
    void crossTransfer_Limits() {
        // Arrange
        Account alice = sm.createAccount();
        NetworkAddress bob = new NetworkAddress(ethNid, "0x32");
        BigInteger amount = BigInteger.TWO.pow(18);
        addBalance(alice, amount);
        tokenScore.invoke(owner, "setSpokeLimit", ethNid, amount.subtract(BigInteger.ONE));

        // Act
        Executable aboveLimit = () -> tokenScore.invoke(alice, "crossTransfer", bob.toString(), amount, new byte[0]);
        AssertionError e = assertThrows(AssertionError.class, aboveLimit);

        // Assert
        assertEquals("Reverted(0): This chain is not allowed to mint more tokens", e.getMessage());
    }

    @Test
    void xTransfer() {
        // Arrange
        NetworkAddress bob = new NetworkAddress(ethNid, "0x32");
        BigInteger amount = BigInteger.TWO.pow(18);
        addBalance(bob, amount);
        BigInteger xCallFee = BigInteger.TEN;
        BigInteger fee = BigInteger.valueOf(7);
        when(tokenSpy.getHopFee(bob.net())).thenReturn(xCallFee);
        when(tokenSpy.getTokenFee(bob.net(), xCallFee, amount)).thenReturn(fee);
        tokenScore.invoke(owner, "configureProtocols", ethNid, sources, destinations);
        tokenScore.invoke(owner, "configureProtocols", bscNid, sources, destinations);


        byte[] expectedCallData = HubTokenMessages.xCrossTransfer(bob.toString(), bob.toString(), amount.subtract(fee), new byte[0]);
        byte[] expectedRollbackData = HubTokenMessages.xCrossTransferRevert(bob.toString(), amount.subtract(fee));

        // Act
        byte[] msg = HubTokenMessages.xTransfer(bob.toString(), amount, new byte[0]);
        tokenScore.invoke(xCall.account, "handleCallMessage", bob.toString(), msg, sources);

        // Assert
        assertEquals(BigInteger.ZERO, balanceOf(bob));
        assertEquals(totalSupply.subtract(fee), tokenScore.call("xTotalSupply"));
        assertEquals(amount.subtract(fee), tokenScore.call("xSupply", ethereumSpokeAddress.net()));
        verify(tokenSpy).XTransfer(bob.toString(), bob.toString(), amount.subtract(fee), new byte[0]);
        verify(xCall.mock).sendCallMessage(Mockito.eq(ethereumSpokeAddress.toString()),
                AdditionalMatchers.aryEq(expectedCallData),
                AdditionalMatchers.aryEq(expectedRollbackData),
                AdditionalMatchers.aryEq(sources),
                AdditionalMatchers.aryEq(destinations));
    }

    void addBalance(Account account, BigInteger amount) {
        tokenScore.invoke(owner, "transfer", account.getAddress(), amount, new byte[0]);
    }

    void addBalance(NetworkAddress account, BigInteger amount) {
        tokenScore.invoke(owner, "hubTransfer", account.toString(), amount, new byte[0]);
    }

    BigInteger balanceOf(Account account) {
        return (BigInteger)tokenScore.call("balanceOf", account.getAddress());
    }

    BigInteger balanceOf(NetworkAddress account) {
        return (BigInteger)tokenScore.call("xBalanceOf", account.toString());
    }
}
