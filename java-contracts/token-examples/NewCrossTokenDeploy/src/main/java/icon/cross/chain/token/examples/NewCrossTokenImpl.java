package icon.cross.chain.token.examples;


import icon.cross.chain.token.lib.tokens.HubTokenImpl;
import score.Address;

import java.math.BigInteger;


public class NewCrossTokenImpl extends HubTokenImpl{
    public NewCrossTokenImpl(Address _xCall, String[] sources, String[] destinations, String _nid, String _tokenName, String _symbolName, BigInteger _decimals) {
        super(_xCall, sources, destinations, _nid, _tokenName, _symbolName, _decimals);
    }
}
