package icon.cross.chain.token.lib.utils;

import score.Address;
import score.Context;
import score.DictDB;
import foundation.icon.xcall.NetworkAddress;

//Class to add btp address support to already existing DictDB address db to support string addresses
public class NetworkAddressDictDB<V> {
    private DictDB<Address, V> legacyAddressDB;
    private DictDB<String, V> addressDB;

    public NetworkAddressDictDB(String id, Class<V> valueClass) {
        this.legacyAddressDB = Context.newDictDB(id, valueClass);
        this.addressDB = Context.newDictDB(id + "_migrated", valueClass);
    }

    public NetworkAddressDictDB(DictDB<Address, V> legacy, DictDB<String, V> current) {
        this.legacyAddressDB = legacy;
        this.addressDB = current;
    }

    public void set(NetworkAddress key, V value) {
        addressDB.set(key.toString(), value);
    };

    public V get(NetworkAddress key) {
        V value = addressDB.get(key.toString());
        if (value != null) {
            return value;
        }
        String address = key.account();
        if (address.startsWith("hx") || address.startsWith("cx")) {
            value = legacyAddressDB.get(Address.fromString(address));
        }


        return value;
    }

    public V getOrDefault(NetworkAddress key, V _default) {
        V value = get(key);
        if (value == null) {
            return _default;
        }

        return value;
    }
}