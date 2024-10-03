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

import score.annotation.External;
import score.annotation.Optional;
import score.annotation.EventLog;

import java.math.BigInteger;

import foundation.icon.score.client.ScoreClient;
import foundation.icon.score.client.ScoreInterface;

@ScoreInterface
@ScoreClient
public interface SpokeToken extends IRC2 {
    /**
     * Returns the account balance of another account with string address {@code _owner},
     * which can be both ICON and BTP Address format.
     */
    @External(readonly = true)
    BigInteger xBalanceOf(String _owner);

    /**
     * Method to transfer spoke token.
     *
     * @param _to receiver address in string format
     * @param _value amount to send
     * @param _data _data can be empty
     *
     * If {@code _to} is a ICON address, use IRC2 transfer
     * Transfers {@code _value} amount of tokens to NetworkAddress {@code _to}, and MUST fire the
     * {@code HubTransfer} event.
     * This function SHOULD throw if the caller account balance does not have enough tokens to spend.
     *
     * The format of {@code _to} if it is NetworkAddress:
     * "<Network Id>.<Network System>/<Account Identifier>"
     * Examples:
     * "0x1.icon/hxc0007b426f8880f9afbab72fd8c7817f0d3fd5c0",
     * "0x5.moonbeam/0x5425F5d4ba2B7dcb277C369cCbCb5f0E7185FB41"
     */
    @External
    void hubTransfer(String _to, BigInteger _value, @Optional byte[] _data);

    /* cross chain methods */

    /**
     * This method is callable only via XCall service on ICON. XCall triggers the handleCallMessage of the spoke token
     * contract and the data from the transaction is decoded by the XCall processor. The first value decoded from data
     * is always the method name. If the method name is `XHubTransfer` then the data is decoded based on the
     * method signature and the method is called.
     *
     * @param from sender NetworkAddress
     * @param _to receiving address, can be account or contract address
     * @param _value amount to transfer
     * @param _data call data and can be empty
     *
     * Transfers {@code _value} amount of tokens to address {@code _to}, and MUST fire the {@code HubTransfer} event.
     * This function SHOULD throw if the caller account balance does not have enough tokens to spend.
     * If {@code _to} is a contract, this function MUST invoke the function {@code xTokenFallback(String, int, bytes)}
     * in {@code _to}.
     * If the {@code xTokenFallback} function is not implemented in {@code _to} (receiver contract),
     * then the transaction must fail and the transfer of tokens should not occur.
     * If {@code _to} is an externally owned address, then the transaction must be sent without trying to execute
     * {@code XTokenFallback} in {@code _to}.
     */
    void xHubTransfer(String from, String _to, BigInteger _value, byte[] _data);

    /**
     * (EventLog) Must trigger on any successful hub token transfers.
     */
    @EventLog
    void HubTransfer(String _from, String _to, BigInteger _value, byte[] _data);
}
