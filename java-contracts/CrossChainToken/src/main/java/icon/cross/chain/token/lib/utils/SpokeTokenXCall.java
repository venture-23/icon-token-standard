package icon.cross.chain.token.lib.utils;

import java.lang.String;
import java.math.BigInteger;
import score.Context;
import score.ObjectReader;
import icon.cross.chain.token.lib.interfaces.tokens.SpokeToken;

public final class SpokeTokenXCall {
    public static void process(SpokeToken score, String from, byte[] data) {
        ObjectReader reader = Context.newByteArrayObjectReader("RLPn", data);
        reader.beginList();
        String method = reader.readString().toLowerCase();
        switch (method) {
            case "xhubtransfer":{
                String _to;
                BigInteger _value;
                byte[] _data;
                _to = reader.read(String.class);
                _value = reader.read(BigInteger.class);
                _data = reader.read(byte[].class);
                score.xHubTransfer(from, _to, _value, _data);
                break;
            } default:
                Context.revert("Method does not exist");
        }
    }
}
