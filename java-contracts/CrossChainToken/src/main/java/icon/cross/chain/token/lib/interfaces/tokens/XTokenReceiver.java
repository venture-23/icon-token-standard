/*
 * Copyright (c) 2024-2024 Icon Foundation.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

package icon.cross.chain.token.lib.interfaces.tokens;

import java.math.BigInteger;

import foundation.icon.score.client.ScoreInterface;

@ScoreInterface
public interface XTokenReceiver extends TokenFallback {
    /**
     * @param _from NetworkAddress pointing to an address on a XCall connected chain
     * @param _value amount to receive
     * @param _data used in tokenFallbacks
     *
     * If the token issuer wants the contract to handle tokens in the ICON chain then they need to implement
     * this method otherwise it is an optional method.
     * Receives cross chain enabled tokens. This method is called if the {@code _to} in a XCall initiated method
     * is a contract address.
     */
    void xTokenFallback(String _from, BigInteger _value, byte[] _data);
}
