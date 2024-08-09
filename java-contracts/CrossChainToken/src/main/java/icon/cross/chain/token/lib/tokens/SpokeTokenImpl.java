package icon.cross.chain.token.lib.tokens;

import foundation.icon.xcall.NetworkAddress;
import icon.cross.chain.token.lib.interfaces.tokens.SpokeToken;
import icon.cross.chain.token.lib.utils.NetworkAddressDictDB;
import icon.cross.chain.token.lib.utils.ProtocolConfig;
import icon.cross.chain.token.lib.utils.SpokeTokenXCall;
import score.Address;
import score.Context;
import score.DictDB;
import score.VarDB;
import score.annotation.EventLog;
import score.annotation.External;
import score.annotation.Optional;

import java.math.BigInteger;

import static icon.cross.chain.token.lib.utils.Check.*;
import static icon.cross.chain.token.lib.utils.XCallUtils.hasSource;

public class SpokeTokenImpl implements SpokeToken {
    private final static String NAME = "name";
    private final static String SYMBOL = "symbol";
    private final static String DECIMALS = "decimals";
    private final static String TOTAL_SUPPLY = "total_supply";
    protected final static String BALANCES = "balances";
    private final static String X_CALL = "x_call";
    public static final String PROTOCOLS = "protocols";
    private final static String TOKEN_NATIVE_NID = "token_native_nid";

    public static String NATIVE_NID;

    static final Address ZERO_ADDRESS = new Address(new byte[Address.LENGTH]);

    private final VarDB<String> name = Context.newVarDB(NAME, String.class);
    private final VarDB<String> symbol = Context.newVarDB(SYMBOL, String.class);
    private final VarDB<String> tokenNativeNid = Context.newVarDB(TOKEN_NATIVE_NID, String.class);
    private final VarDB<BigInteger> decimals = Context.newVarDB(DECIMALS, BigInteger.class);
    private final VarDB<BigInteger> totalSupply = Context.newVarDB(TOTAL_SUPPLY, BigInteger.class);
    protected final NetworkAddressDictDB<BigInteger> balances = new NetworkAddressDictDB<>(BALANCES, BigInteger.class);
    protected static final VarDB<Address> xCall = Context.newVarDB(X_CALL, Address.class);
    DictDB<String, ProtocolConfig> protocols = Context.newDictDB(PROTOCOLS, ProtocolConfig.class);


    public SpokeTokenImpl(Address _xCall, String nid, String _tokenName, String _symbolName, String _tokenNativeNid, @Optional BigInteger _decimals) {
        xCall.set(_xCall);
        NATIVE_NID = nid;
        this.tokenNativeNid.set(_tokenNativeNid);
        if (this.name.get() == null) {
            _decimals = _decimals == null ? BigInteger.valueOf(18L) : _decimals;
            Context.require(_decimals.compareTo(BigInteger.ZERO) >= 0, "Decimals cannot be less than zero");

            this.name.set(ensureNotEmpty(_tokenName));
            this.symbol.set(ensureNotEmpty(_symbolName));
            this.decimals.set(_decimals);
        }
    }

    @EventLog(indexed = 3)
    public void Transfer(Address _from, Address _to, BigInteger _value, byte[] _data) {
    }

    @EventLog(indexed = 3)
    public void HubTransfer(String _from, String _to, BigInteger _value, byte[] _data) {
    }

    private String ensureNotEmpty(String str) {
        Context.require(str != null && !str.trim().isEmpty(), "str is null or empty");
        assert str != null;
        return str.trim();
    }

    @External(readonly = true)
    public String nid() {
        return NATIVE_NID;
    }

    @External(readonly = true)
    public String name() {
        return name.get();
    }

    @External(readonly = true)
    public String symbol() {
        return symbol.get();
    }

    @External(readonly = true)
    public BigInteger decimals() {
        return decimals.get();
    }

    @External(readonly = true)
    public String tokenNativeNid() {
        return tokenNativeNid.get();
    }

    @External(readonly = true)
    public BigInteger totalSupply() {
        return totalSupply.getOrDefault(BigInteger.ZERO);
    }

    @External(readonly = true)
    public Address getXCall() {
        return xCall.get();
    }

    @External(readonly = true)
    public ProtocolConfig getProtocols(String id) {
        return protocols.get(id);
    }

    @External(readonly = true)
    public BigInteger balanceOf(Address _owner) {
        NetworkAddress address =  new NetworkAddress(NATIVE_NID, _owner);
        return balances.getOrDefault(address, BigInteger.ZERO);
    }

    @External(readonly = true)
    public BigInteger xBalanceOf(String _owner) {
        NetworkAddress address = NetworkAddress.valueOf(_owner);
        return balances.getOrDefault(address, BigInteger.ZERO);
    }

    @External
    public void configureProtocols(String nid, String[] sources, String[] destinations) {
        onlyOwner();
        ProtocolConfig cfg = new ProtocolConfig(sources, destinations);
        protocols.set(nid, cfg);
    }

    @External
    public void transfer(Address _to, BigInteger _value, @Optional byte[] _data) {
        _transfer(
                new NetworkAddress(NATIVE_NID, Context.getCaller()),
                new NetworkAddress(NATIVE_NID, _to),
                _value,
                _data);
    }

    @External
    public void hubTransfer(String _to, BigInteger _value, @Optional byte[] _data) {
        _transfer(
                new NetworkAddress(NATIVE_NID, Context.getCaller()),
                NetworkAddress.valueOf(_to.toString(), NATIVE_NID),
                _value,
                _data);
    }

    public void xHubTransfer(String from, String _to, BigInteger _value, byte[] _data) {
        _transfer(
                NetworkAddress.valueOf(from),
                NetworkAddress.valueOf(_to.toString()),
                _value,
                _data);
    }

    @External
    public void handleCallMessage(String _from, byte[] _data, @Optional String[] _protocols) {
        only(xCall.get());
        verifyProtocols(_from, _protocols);
        SpokeTokenXCall.process(this, _from, _data);
    }

    protected void _transfer(NetworkAddress _from, NetworkAddress _to, BigInteger _value, byte[] _data) {
        Context.require(_value.compareTo(BigInteger.ZERO) >= 0, this.name.get() + ": _value needs to be positive");
        BigInteger fromBalance = balances.getOrDefault(_from, BigInteger.ZERO);

        Context.require(fromBalance.compareTo(_value) >= 0, this.name.get() + ": Insufficient balance");

        this.balances.set(_from, fromBalance.subtract(_value));
        this.balances.set(_to, balances.getOrDefault(_to, BigInteger.ZERO).add(_value));

        byte[] dataBytes = (_data == null) ? "None".getBytes() : _data;
        if (isNative(_to) && isNative(_from)) {
            Transfer(Address.fromString(_from.account()), Address.fromString(_to.account()), _value, dataBytes);
        } else {
            if (isNative(_to)) {
                Transfer(ZERO_ADDRESS, Address.fromString(_to.account()), _value, "mint".getBytes());
            } else if (isNative(_from)) {
                Transfer(Address.fromString(_from.account()), ZERO_ADDRESS, _value, "burn".getBytes());
            }

            HubTransfer(_from.toString(), _to.toString(), _value, dataBytes);
        }

        if (!_to.net().equals(NATIVE_NID)) {
            return;
        }


        Address contractAddress = Address.fromString(_to.account());
        if (!contractAddress.isContract()) {
            return;
        }

        if (isNative(_from)) {
            Context.call(contractAddress, "tokenFallback", Address.fromString(_from.account()), _value, dataBytes);
        } else {
            Context.call(contractAddress, "xTokenFallback", _from.toString(), _value, dataBytes);
        }
    }

    protected void mint(NetworkAddress minter, BigInteger amount) {
        _mint(minter, amount);
        if (isNative(minter)) {
            Transfer(ZERO_ADDRESS, Address.fromString(minter.account()), amount, "mint".getBytes());
        } else {
            HubTransfer(ZERO_ADDRESS.toString(), minter.toString(), amount, "mint".getBytes());
        }
    }

    protected void _mint(NetworkAddress minter, BigInteger amount) {
        Context.require(!ZERO_ADDRESS.toString().equals(minter.account()), this.name.get() + ": Owner address cannot be zero address");
        Context.require(amount.compareTo(BigInteger.ZERO) >= 0, this.name.get() + ": Amount needs to be positive");

        totalSupply.set(totalSupply().add(amount));
        balances.set(minter, balances.getOrDefault(minter, BigInteger.ZERO).add(amount));
    }

    protected void burn(NetworkAddress owner, BigInteger amount) {
        _burn(owner, amount);
        if (isNative(owner)) {
            Transfer(Address.fromString(owner.account()), ZERO_ADDRESS, amount, "burn".getBytes());
        } else {
            HubTransfer(owner.toString(), ZERO_ADDRESS.toString(), amount, "burn".getBytes());
        }
    }

    protected void _burn(NetworkAddress owner, BigInteger amount) {
        Context.require(!ZERO_ADDRESS.toString().equals(owner.account()), this.name.get() + ": Owner address cannot be zero address");
        Context.require(amount.compareTo(BigInteger.ZERO) >= 0, this.name.get() + ": Amount needs to be positive");
        BigInteger balance = balances.getOrDefault(owner, BigInteger.ZERO);
        Context.require(balance.compareTo(amount) >= 0, this.name.get() + ": Insufficient Balance");

        balances.set(owner, balance.subtract(amount));
        totalSupply.set(totalSupply().subtract(amount));
    }

    protected boolean isNative(NetworkAddress address) {
        return address.net().equals(NATIVE_NID);
    }

    protected void verifyProtocols(String _from, @Optional String[] protocols) {
        NetworkAddress from = NetworkAddress.valueOf(_from);
        String nid = from.net();

        if (nid.equals(NATIVE_NID)) {
            // Is a rollback
            return;
        }

        ProtocolConfig cfg = this.protocols.get(nid);
        Context.require(cfg != null,  this.name.get() + ": Network is not configured");
        if (cfg.sources.length == 0) {
            Context.require(protocols == null || protocols.length == 0, this.name.get() + ": Invalid protocols used to deliver message");
            return;
        }

        for (String source : cfg.sources) {
            Context.require(hasSource(source, protocols),  this.name.get() + ": Invalid protocols used to deliver message");
        }
    }
}
