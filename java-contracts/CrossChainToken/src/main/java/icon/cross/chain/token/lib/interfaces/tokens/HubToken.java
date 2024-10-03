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

import score.annotation.EventLog;
import score.annotation.External;
import score.annotation.Payable;

import java.math.BigInteger;

import foundation.icon.score.client.ScoreClient;
import foundation.icon.score.client.ScoreInterface;

@ScoreInterface
@ScoreClient
public interface HubToken extends SpokeToken {
    /**
     * Returns the total token supply across all connected chains.
     */
    @External(readonly = true)
    BigInteger xTotalSupply();

    /**
     * Returns the total token supply on a connected chain.
     */
    @External(readonly = true)
    BigInteger xSupply(String net);

    /**
     * Returns a list of all contracts across all connected chains
     */
    @External(readonly = true)
    String[] getConnectedChains();

    /**
     * Method to transfer hub token.
     *
     * @param _to NetworkAddress to send to
     * @param _value amount to send
     * @param _data used in tokenFallbacks
     *
     * If {@code _to} is a ICON address, use IRC2 transfer
     * If {@code _to} is a NetworkAddress, then the transaction must trigger xTransfer via XCall
     * on corresponding spoke chain and MUST fire the {@code XTransfer} event.
     * {@code _data} can be attached to this token transaction.
     * {@code _data} can be empty.
     * XCall rollback message is specified to match [xTransferRevert](#xcrosstransferrevert).
     *
     * The format of {@code _to} if it is NetworkAddress:
     * "<Network Id>.<Network System>/<Account Identifier>"```
     * Examples:
     * "0x1.icon/hxc0007b426f8880f9afbab72fd8c7817f0d3fd5c0",
     * "0x5.moonbeam/0x5425F5d4ba2B7dcb277C369cCbCb5f0E7185FB41"
     */
    @External
    @Payable
    void crossTransfer(String _to, BigInteger _value, byte[] _data);

    /* cross chain methods */

    /**
     * This is a method for processing cross chain transfers from spokes. It is callable via XCall only.
     * The XCall processor decodes the transaction data and if the method name in the decoded data is `xCrossTransfer`
     * then it calls this function.
     *
     * @param _from from NetworkAddress
     * @param _to NetworkAddress to send to
     * @param _value amount to send
     * @param _data used in tokenFallbacks
     *
     * If {@code _to} is a contract trigger xTokenFallback(String, int, byte[]) instead of regular tokenFallback.
     * Internal behavior same as [xTransfer](#xtransfer) but the {@code from} parameter is specified by XCall
     * rather than the blockchain.
     */
    void xCrossTransfer(String from, String _from, String _to, BigInteger _value, byte[] _data);

    /**
     * This method is callable via XCall only, and is called when the cross transfer transaction is reverted.
     * XCall processor decodes the transaction data and if the method name in decoded data is `xCrossTransferRevert`
     * then this function is called.
     */
    void xCrossTransferRevert(String from, String _to, BigInteger _value);

    /**
     * Method for transferring hub balances to a spoke chain. It is callable via XCall only.
     * The XCall processor decodes the transaction data and if the method name in decoded data is `xTransfer`
     * then it calls this function.
     *
     * @param from EOA address of a connected chain
     * @param _to native address on calling chain
     * @param _value amount to send
     * @param _data used in tokenFallbacks
     *
     * Uses {@code from} to xTransfer the balance on ICON to native address on a calling chain.
     */
    void xTransfer(String from, String _to, BigInteger _value, byte[] _data);

    /**
     * (EventLog) Must trigger on any successful token transfers from cross-chain addresses.
     */
    @EventLog(indexed = 1)
    void XTransfer(String _from, String _to, BigInteger _value, byte[] _data);
}
