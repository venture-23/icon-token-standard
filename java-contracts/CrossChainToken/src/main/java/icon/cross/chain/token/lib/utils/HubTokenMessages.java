package icon.cross.chain.token.lib.utils;

import java.lang.String;
import java.math.BigInteger;
import score.ByteArrayObjectWriter;
import score.Context;

public final class HubTokenMessages {
    public static byte[] xCrossTransfer(String _from, String _to, BigInteger _value, byte[] _data) {
        ByteArrayObjectWriter writer = Context.newByteArrayObjectWriter("RLPn");
        writer.beginList(5);
        writer.write("xCrossTransfer");
        writer.write(_from);
        writer.write(_to);
        writer.write(_value);
        writer.write(_data);
        writer.end();
        return writer.toByteArray();
    }

    public static byte[] xCrossTransferRevert(String _to, BigInteger _value) {
        ByteArrayObjectWriter writer = Context.newByteArrayObjectWriter("RLPn");
        writer.beginList(3);
        writer.write("xCrossTransferRevert");
        writer.write(_to);
        writer.write(_value);
        writer.end();
        return writer.toByteArray();
    }

    public static byte[] xTransfer(String _to, BigInteger _value, byte[] _data) {
        ByteArrayObjectWriter writer = Context.newByteArrayObjectWriter("RLPn");
        writer.beginList(4);
        writer.write("xTransfer");
        writer.write(_to);
        writer.write(_value);
        writer.write(_data);
        writer.end();
        return writer.toByteArray();
    }

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

