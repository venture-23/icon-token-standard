package icon.cross.chain.token.lib.interfaces.tokens;

import foundation.icon.score.client.ScoreInterface;
import score.Address;
import score.annotation.External;

import java.math.BigInteger;

@ScoreInterface
public interface TokenFallback {
    @External
    void tokenFallback(Address _from, BigInteger _value, byte[] _data);
}
