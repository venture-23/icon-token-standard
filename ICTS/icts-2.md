
## Simple Summary
A standard interface for cross chain tokens on ICON network.

## Abstract
This draft ICTS describes a cross chain token standard interface to provide basic functionality to migrate tokens among different chains.

The standard will mirror the operational framework of bnUSD, where minter contracts are deployed across various chains to provide a native user experience. This setup ensures seamless operation and accessibility of our tokens on multiple blockchains.

## Motivation
The ICON network's focus on cross-chain interoperability depends on creating low friction paths for developers to take advantage of unified and concentrated liquidity pools on Balanced regardless of what chain they are starting from. By enabling the straightforward migration of tokens, ICON can attract builders who want to deliver smooth token experiences to their end users.

## Specification

### Methods

#### name
Returns the name of the token. e.g. `CrosssChainToken`.
```java
@External(readonly=true)
public String name();
```

#### symbol
Returns the symbol of the token. e.g. `CCTT`.
```java
@External(readonly=true)
public String symbol();
```

#### decimals
Returns the number of decimals the token uses. e.g. `18`.
```java
@External(readonly=true)
public BigInteger decimals();
```
#### totalSupply
Returns the total token supply.
```java
@External(readonly=true)
public BigInteger totalSupply();
```

#### xTotalSupply
Returns the total token supply across all connected chains.
```java
@External(readonly = true)
BigInteger xTotalSupply();
```

#### xSupply
Returns the total token supply on a connected chains.
```java
@External(readonly = true)
BigInteger xSupply(String net);
```

#### getConnectedChains
Returns a list of all contracts across all connected chains.
```java
@External(readonly = true)
String[] getConnectedChains();
```

#### balanceOf
Returns the account balance of another account with address `_owner`.
```java
@External(readonly=true)
public BigInteger balanceOf(Address _owner);
```

#### xBalanceOf
Returns the account balance of another account with string address {@code _owner}, which can be both ICON and BTP Address format.
```java
@External(readonly = true)
BigInteger xBalanceOf(String _owner);
```

#### hubTransfer
If ```_to``` is a ICON address, use IRC2 transfer Transfers ```_value``` amount of tokens to BTP address ```_to```, and MUST fire the ``` HubTransfer``` event. This function SHOULD throw if the caller account balance does not have enough tokens to spend.
```java
@External
void hubTransfer(String _to, BigInteger _value, @Optional byte[] _data);
```

#### xHubTransfer
Callable only via XCall service on ICON. Transfers ```_value``` amount of tokens to address ```_to```, and MUST fire the ```HubTransfer``` event. This function SHOULD throw if the caller account balance does not have enough tokens to spend. If ```_to``` is a contract, this function MUST invoke the function ```xTokenFallback(String, int, bytes)``` in ```_to```. If the ```xTokenFallback``` function is not implemented in ```_to``` (receiver contract), then the transaction must fail and the transfer of tokens should not occur. If ```_to``` is an externally owned address, then the transaction must be sent without trying to execute ```XTokenFallback``` in ```_to```. ```_data``` can be attached to this token transaction. ```_data``` can be empty.
```java
@XCall
void xHubTransfer(String from, String _to, BigInteger _value, byte[] _data);
```

