
## Simple Summary
A standard interface for native implementation and management of a token across multiple chains using ICON's [GMP](https://github.com/icon-project/IIPs/blob/master/IIPS/iip-52.md).

## Abstract
This document describes the standard token interface required for interoperability across multiple chains connected via ICON's GMP. It enables cross chain transfers between native implementations of the token and management of total supply across all connected chains.

The standard is abstracted from the first such implementation, [bnUSD](https://github.com/balancednetwork/balanced-java-contracts/tree/main/token-contracts/BalancedDollar), where minter contracts are deployed across connected chains to provide a native user experience. This setup ensures seamless operation and accessibility of tokens on multiple blockchains.

## Motivation
The ICON network's focus on cross-chain interoperability depends on creating low friction paths for developers to take advantage of its General Message Passing protocol. This token standard specifies how to implement token contracts that can access unified and concentrated liquidity pools on Balanced regardless of what chain they are starting from. By enabling the straightforward migration of tokens from single chain to multi-chain implementations, ICON aims to attract builders who want to deliver smooth token experiences to their end users and leverage novel technologies that exist across multiple chains.

## Specification
The cross chain token standard consists of two main libraries: HubToken and SpokeToken, and two extended libraries: IRC2 and XTokenReceiver. 
1. [HubToken](#hubtoken)

   HubToken is a token from the base chain. It controls token minting in the base chain. It also tracks the total supply of the token across all chains where the tokens are deployed. For example, bnUSD is a token that originates in the ICON chain through Balanced. So it is deployed as a hub token in the ICON  chain and, if we want to migrate bnUSD to other chains (say SUI chain), we will deploy it as a spoke token in SUI chain. Simliarly, if we want to make any token from SUI say PumpUp(PUP), a cross chain token then it is deployed as hub token in SUI chain and as spoke token in ICON chain.  HubToken library extends [SpokeToken](#spoketoken) library.

2. [SpokeToken](#spoketoken)

   SpokeToken is a token from a foreign chain. In ICON, it extends the basic [IRC2](https://github.com/icon-project/IIPs/blob/master/IIPS/iip-2.md) token and has a cross chain transfer function and a function to get balance of a user across the chains. If we want to move a token from a base chain to some foreign chains, the token is depolyed as a spoke token in all other foreign chains. For example, if we want to migrate SUI token to ICON, we will deploy a spoke token contract for SUI token in the ICON chain.

3. [IRC2](https://github.com/icon-project/IIPs/blob/master/IIPS/iip-2.md)
   
   This is a library of token standard interface that provides basic functionality to transfer tokens in ICON. The SpokeToken library extends this library.

3. [XTokenReceiver](#xtokenreceiver)

    This library is implemanted by both the HubToken and SpokeToken on ICON chain. It extends the TokenFallback method of ICON. The function [xTokenFallback](#xtokenfallback) is only callable via XCall services on ICON. It is called when transfer is called from the foreign chain and the receiving address is a contract in ICON. The receiving contract must have implemented [xTokenFallback](#xtokenfallback) inorder to get a successful transfer of tokens.

So, for a token to be a cross chain token, it needs to implement the cross chain token standard in their respective chain. A token is deployed as a HubToken in it's base chain and as a SpokeToken in other foreign chains.

### SpokeToken
SpokeToken library extends the basic token standard of that chain. In ICON, it extends basic IRC2 token and has a cross chain transfer function.

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

##### xBalanceOf
Returns the account balance of another account with string address ```_owner```, which can be both ICON and BTP Address format.
```java
@External(readonly = true)
BigInteger xBalanceOf(String _owner);
```

##### hubTransfer
If ```_to``` is a ICON address, use IRC2 transfer, Transfers ```_value``` amount of tokens to BTP address ```_to```, and MUST fire the ``` HubTransfer``` event. This function SHOULD throw if the caller account balance does not have enough tokens to spend.

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
This function is callable only via XCall service on ICON. It transfers ```_value``` amount of tokens to address ```_to```, and MUST fire the ```HubTransfer``` event. This function SHOULD throw if the caller account balance does not have enough tokens to spend. If ```_to``` is a contract, this function MUST invoke the function ```xTokenFallback(String, int, bytes)``` in ```_to```. If the ```xTokenFallback``` function is not implemented in ```_to``` (receiver contract), then the transaction must fail and the transfer of tokens should not occur. If ```_to``` is an externally owned address, then the transaction must be sent without trying to execute ```XTokenFallback``` in ```_to```. ```_data``` can be attached to this token transaction. ```_data``` can be empty.
```java
@XCall
void xHubTransfer(String from, String _to, BigInteger _value, byte[] _data);
```

#### Eventlogs

##### Transfer
Must trigger on any successful token transfers.
```java
@EventLog
void Transfer(Address _from, Address _to, BigInteger _value, byte[] _data);
```

##### HubTransfer
Must trigger on any successful hub token transfers.
```java
@EventLog
void HubTransfer(String _from, String _to, BigInteger _value, byte[] _data);
```

### HubToken
Hub token extends the [SpokeToken](#spoketoken) library. It inclides functions to track total supply across all connected chains

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
Here ```_to``` is NetworkAddress to send to, ```_value``` is amount to send, ```_data``` is used in tokenFallbacks. If ```_to``` is a ICON address, use IRC2 transfer, if it is a NetworkAddress, then the transaction must trigger xTransfer via XCall on corresponding spoke chain and MUST fire the ```XTransfer``` event. ```_data``` can be attached to this token transaction. ```_data``` can be empty. XCall rollback message is specified to match [xCrossTransferRevert](#xcrosstransferrevert).

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
This is a method for processing cross chain transfers from spokes. Here ```_from``` is from NetworkAddress, ```_to``` is NetworkAddress to send to, ```_value``` is amount to send, ```_data``` is used in tokenFallbacks.
If ```_to``` is a contract, trigger xTokenFallback(String, int, byte[]) instead of regular tokenFallback.
Internal behavior is same as [xTransfer](#xtransfer) but from parameters is specified by XCall rather than the blockchain.
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
This is a method for transferring hub balances to a spoke chain, ```from``` is a EOA address of a connected chain. Uses ```from``` to xTransfer the balance on ICON to native address on a calling chain.
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
This library is used to handle the cross chain token transfer to the contracts in ICON chain. It extends the TokenFallback method of ICON. The function [xTokenFallback](#xtokenfallback) is only callable via XCall services on ICON. It is called when transfer is called from the foreign chain and the receiving address is a contract in ICON. The receiving contract must have implemented ```xTokenFallback``` inorder to get a successful transfer of tokens.

#### Methods

##### xTokenFallback
Receives cross chain enabled tokens where the ```_from``` is in a String Address format, pointing to an address on a XCall connected chain.
```java
void xTokenFallback(String _from, BigInteger _value, byte[] _data);
```
