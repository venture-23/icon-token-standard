package icon.cross.chain.token.examples;


import foundation.icon.xcall.NetworkAddress;
import icon.cross.chain.token.lib.tokens.HubTokenImpl;
import score.Address;
import score.annotation.External;

import java.math.BigInteger;

import static icon.cross.chain.token.lib.utils.Check.onlyOwner;


public class NewCrossTokenImpl extends HubTokenImpl {
    public NewCrossTokenImpl(Address _xCall, Address _xCallManager, String _nid, String _tokenName, String _symbolName,  String _tokenNativeNid, BigInteger _decimals) {
        super(_xCall, _xCallManager, _nid, _tokenName, _symbolName, _tokenNativeNid, _decimals);
    }

    @External
    public void mint(String to, BigInteger amount) {
        onlyOwner();
        super._mint(NetworkAddress.parse(to), amount);
    }
}
