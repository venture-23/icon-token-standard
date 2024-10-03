package icon.cross.chain.token.lib.utils;

import java.lang.String;
import java.math.BigInteger;

import icon.cross.chain.token.lib.interfaces.tokens.HubToken;
import score.Context;
import score.ObjectReader;

public final class HubTokenXCall {
    public static void process(HubToken score, String from, byte[] data) {
        ObjectReader reader = Context.newByteArrayObjectReader("RLPn", data);
        reader.beginList();
        String method = reader.readString().toLowerCase();
        switch (method) {
            case "xcrosstransfer":{
                String _from;
                String _to;
                BigInteger _value;
                byte[] _data;
                _from = reader.read(String.class);
                _to = reader.read(String.class);
                _value = reader.read(BigInteger.class);
                _data = reader.read(byte[].class);
                score.xCrossTransfer(from, _from, _to, _value, _data);
                break;
            } case "xcrosstransferrevert":{
                String _to;
                BigInteger _value;
                _to = reader.read(String.class);
                _value = reader.read(BigInteger.class);
                score.xCrossTransferRevert(from, _to, _value);
                break;
            } case "xtransfer":{
                String _to;
                BigInteger _value;
                byte[] _data;
                _to = reader.read(String.class);
                _value = reader.read(BigInteger.class);
                _data = reader.read(byte[].class);
                score.xTransfer(from, _to, _value, _data);
                break;
            } case "xhubtransfer":{
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
