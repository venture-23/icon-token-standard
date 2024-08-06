/*
 * Copyright (c) 2022-2023 Balanced.network.
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

package icon.cross.chain.token.lib.utils;

import score.Address;
import score.Context;
import score.VarDB;
import foundation.icon.xcall.NetworkAddress;

import java.math.BigInteger;

public class XCallUtils {
    private static final String TAG = "XCallUtils";
    private static final VarDB<String> nativeNid = Context.newVarDB(TAG + "NativeNetworkId", String.class);

    public static void sendCall(BigInteger fee, Address xCall, NetworkAddress to, byte[] data, byte[] rollback, ProtocolConfig protocols) {
        Context.call(fee, xCall, "sendCallMessage", to.toString(), data, rollback, protocols.sources, protocols.destinations);
    }


    public static boolean hasSource(String source, String[] protocols) {
        for (String protocol : protocols) {
            if (protocol.equals(source)) {
                return true;
            }
        }
        return false;
    }
}
