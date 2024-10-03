package icon.cross.chain.token.lib.utils;

import java.lang.String;
import java.math.BigInteger;
import score.ByteArrayObjectWriter;
import score.Context;

public final class SpokeTokenMessages {
    public static byte[] xHubTransfer(String _to, BigInteger _value, byte[] _data) {
        ByteArrayObjectWriter writer = Context.newByteArrayObjectWriter("RLPn");
        writer.beginList(4);
        writer.write("xHubTransfer");
        writer.write(_to);
        writer.write(_value);
        writer.write(_data);
        writer.end();
        return writer.toByteArray();
    }
}