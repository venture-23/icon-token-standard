
## Simple Summary
A standard interface for native implementation and management of a token across multiple chains using ICON's [GMP](https://github.com/icon-project/IIPs/blob/master/IIPS/iip-52.md).

## Abstract
This document describes the standard token interface required for interoperability across multiple chains connected via ICON's GMP. It enables cross chain transfers between native implementations of the token and management of total supply across all connected chains.

The standard is abstracted from the first such implementation, [bnUSD](https://github.com/balancednetwork/balanced-java-contracts/tree/main/token-contracts/BalancedDollar), where minter contracts are deployed across connected chains to provide a native user experience. This setup ensures seamless operation and accessibility of tokens on multiple blockchains.

## Motivation
The ICON network's focus on cross-chain interoperability depends on creating low friction paths for developers to take advantage of its General Message Passing protocol. This token standard specifies how to implement token contracts that can access unified and concentrated liquidity pools on Balanced regardless of what chain they are starting from. By enabling the straightforward migration of tokens from single chain to multi-chain implementations, ICON aims to attract builders who want to deliver smooth token experiences to their end users and leverage novel technologies that exist across multiple chains.

## Specification

### IRC2

#### Methods

##### name
Returns the name of the token. e.g. `CrossChainToken`.
```java
@External(readonly=true)
public String name();
```

##### symbol
Returns the symbol of the token. e.g. `CCT`.
```java
@External(readonly=true)
public String symbol();
```

##### decimals
Returns the number of decimals the token uses. e.g. `18`.
```java
@External(readonly=true)
public BigInteger decimals();
```
##### totalSupply
Returns the total token supply.
```java
@External(readonly=true)
public BigInteger totalSupply();
```

##### balanceOf
Returns the account balance of another account with address `_owner`.
```java
@External(readonly=true)
public BigInteger balanceOf(Address _owner);
```

##### transfer
Transfers `_value` amount of tokens to address `_to`, and MUST fire the `Transfer` event.
```java
@External
void transfer(Address _to, BigInteger _value, @Optional byte[] _data);
```

#### Eventlogs

##### Transfer
Must trigger on any successful token transfers.
```java
@EventLog
void Transfer(Address _from, Address _to, BigInteger _value, byte[] _data);
```

### SpokeToken

#### Methods

##### xBalanceOf
Returns the account balance of another account with string address {@code _owner}, which can be both ICON and BTP Address format.
```java
@External(readonly = true)
BigInteger xBalanceOf(String _owner);
```

##### hubTransfer
If ```_to``` is a ICON address, use IRC2 transfer Transfers ```_value``` amount of tokens to BTP address ```_to```, and MUST fire the ``` HubTransfer``` event. This function SHOULD throw if the caller account balance does not have enough tokens to spend.

The format of ```_to``` if it is XCallAddress:
```"<Network Id>.<Network System>/<Account Identifier>"```
>Examples:
```"0x1.icon/hxc0007b426f8880f9afbab72fd8c7817f0d3fd5c0"```,
```0x5.moonbeam/0x5425F5d4ba2B7dcb277C369cCbCb5f0E7185FB41```
```java
@External
void hubTransfer(String _to, BigInteger _value, @Optional byte[] _data);
```

###### xHubTransfer
This function is callable only via XCall service on ICON. Transfers ```_value``` amount of tokens to address ```_to```, and MUST fire the ```HubTransfer``` event. This function SHOULD throw if the caller account balance does not have enough tokens to spend. If ```_to``` is a contract, this function MUST invoke the function ```xTokenFallback(String, int, bytes)``` in ```_to```. If the ```xTokenFallback``` function is not implemented in ```_to``` (receiver contract), then the transaction must fail and the transfer of tokens should not occur. If ```_to``` is an externally owned address, then the transaction must be sent without trying to execute ```XTokenFallback``` in ```_to```. ```_data``` can be attached to this token transaction. ```_data``` can be empty.
```java
@XCall
void xHubTransfer(String from, String _to, BigInteger _value, byte[] _data);
```

#### Eventlogs

##### HubTransfer
Must trigger on any successful hub token transfers.
```java
@EventLog
void HubTransfer(String _from, String _to, BigInteger _value, byte[] _data);
```

### HupToken

#### Methods

##### xTotalSupply
Returns the total token supply across all connected chains.
```java
@External(readonly = true)
BigInteger xTotalSupply();
```

##### xSupply
Returns the total token supply on a connected chains.
```java
@External(readonly = true)
BigInteger xSupply(String net);
```

##### getConnectedChains
Returns a list of all contracts across all connected chains.
```java
@External(readonly = true)
String[] getConnectedChains();
```

##### crossTransfer
Here ```_to``` is NetworkAddress to send to, ```_value``` is amount to send, ```_data``` is used in tokenFallbacks.
If ```_to``` is a ICON address, use IRC2 transfer
If ``` _to``` is a NetworkAddress, then the transaction must trigger xTransfer via XCall on corresponding spoke chain and MUST fire the ```XTransfer``` event. ```_data``` can be attached to this token transaction. ```_data``` can be empty. XCall rollback message is specified to match [xCrossTransferRevert](#xcrosstransferrevert).

The format of ```_to``` if it is XCallAddress:
```"<Network Id>.<Network System>/<Account Identifier>"```
>Examples:
```"0x1.icon/hxc0007b426f8880f9afbab72fd8c7817f0d3fd5c0"```,
```0x5.moonbeam/0x5425F5d4ba2B7dcb277C369cCbCb5f0E7185FB41```
```java
@External
@Payable
void crossTransfer(String _to, BigInteger _value, byte[] _data);
```

###### xCrossTransfer
This is a method for processing cross chain transfers from spokes.
Here ```_from``` is from NetworkAddress, ```_to``` is NetworkAddress to send to, ```_value``` is amount to send, ```_data``` is used in tokenFallbacks.
If ```_to``` is a contract trigger xTokenFallback(String, int, byte[]) instead of regular tokenFallback.
Internal behavior same as [xTransfer](#xtransfer) but from parameters is specified by XCall rather than the blockchain.
```java
@XCall
void xCrossTransfer(String from, String _from, String _to, BigInteger _value, byte[] _data);
```

##### xCrossTransferRevert
```java
@XCall
void xCrossTransferRevert(String from, String _to, BigInteger _value);
```

##### xTransfer
Method for transferring hub balances to a spoke chain, ```from``` is a EOA address of a connected chain. Uses ```from``` to xTransfer the balance on ICON to native address on a calling chain.
```java
@XCall
void xTransfer(String from, String _to, BigInteger _value, byte[] _data);
```

#### Eventlogs

##### XTransfer
Must trigger on any successful token transfers from cross-chain addresses.
```java
@EventLog(indexed = 1)
void XTransfer(String _from, String _to, BigInteger _value, byte[] _data);
```

### XTokenReceiver

#### Methods

##### xTokenFallback
Receives tokens cross chain enabled tokens where the ```_from``` is in a String Address format, pointing to an address on a XCall connected chain.
```java
void xTokenFallback(String _from, BigInteger _value, byte[] _data);
```
