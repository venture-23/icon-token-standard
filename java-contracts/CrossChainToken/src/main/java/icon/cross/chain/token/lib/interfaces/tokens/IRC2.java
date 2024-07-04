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

import foundation.icon.score.client.ScoreInterface;
import score.Address;
import score.annotation.EventLog;
import score.annotation.External;
import score.annotation.Optional;

import java.math.BigInteger;

@ScoreInterface
public interface IRC2 {
    @External(readonly = true)
    String name();

    @External(readonly = true)
    String symbol();

    @External(readonly = true)
    BigInteger decimals();

    @External(readonly = true)
    BigInteger totalSupply();

    @External(readonly = true)
    BigInteger balanceOf(Address _owner);

    @External
    void transfer(Address _to, BigInteger _value, @Optional byte[] _data);

    @EventLog
    void Transfer(Address _from, Address _to, BigInteger _value, byte[] _data);
}
