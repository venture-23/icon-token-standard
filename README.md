# icon-token-standard

The cross chain token standard interfaces are documented below and is under discussion in icon-project repo.

ICON IIP: https://github.com/venture-23/iip-cross-chain-token/blob/development/IIPS/iip-cross-chain-token.md 

Link to discussion: https://github.com/icon-project/IIPs/discussions/74 

The Cross Chain Token Standard aims to enable interoperability across multiple chains connected via ICON's GMP. This standard will facilitate seamless migration of existing tokens on ICON and chains connected by ICON GMP to a new cross-chain token standard designed for compatibility and easy integration with Balanced. This repo contains the implemenatation library with some use case examples on ICON, SUI and EVM chains.

The exists three different scenarios for the cross cahin token standard implementation, which are listed below:

1. Deploy New Cross Chain Token
   
   If a user wants to deploy a fresh new cross chain token, he/she can just extend the Hub/Spoke Token Standard Implementation library based on their requirement. If the chain is ICON, Hub Token is supposed to be deployed and if it is any other foreign chains then Spoke Token is supposed to be deployed. This way of implementation helps to deploy a native token in any other foreign chains. For example, if a token issuer wants to issue a new cross chain token on ICON, he/she will extend the HubToken Implementation library (and add some custom functionality if necessary) into the token contract and deploy it on ICON, and deploy a SpokeToken Implementaion contract on all other foreign chains.

    * [Hub Token Implementaion on ICON](https://github.com/venture-23/icon-token-standard/blob/development/java-contracts/CrossChainToken/src/main/java/icon/cross/chain/token/lib/tokens/HubTokenImpl.java)
  
    Example for deploying a new cross chain token on:
   * [ICON](https://github.com/venture-23/icon-token-standard/blob/development/java-contracts/token-examples/NewCrossTokenDeploy/src/main/java/icon/cross/chain/token/examples/NewCrossTokenImpl.java)

   * [SUI](https://github.com/venture-23/icon-token-standard/blob/development/sui-move-contracts/spoke_token/sources/impl/test_coin.move)

    * [EVM](https://github.com/venture-23/icon-token-standard/blob/development/solidity-contracts/icon-cross-chain-token/src/implementation/NewCrossToken.sol)

2. Upgrade Existing Token to Cross Chain Token
   
   If a token issuer wants to upgrade the already existing token to a cross chain token then he/she can upgrade their existing token contract by extending the Cross Token Standard library based on token type if it is ICON extend Hub Token, if any other foreign chains extend Spoke Token. This way of implementation helps to deploy a native token in any other foreign chains. For example, if there exists a token ABC on SUI chain and the issuer wants to upgrade it to cross chain standard then, the issuer will upgrade the ABC token by extending the Spoke Token library on SUI.

   * [Spoke Token Implementation on SUI](https://github.com/venture-23/icon-token-standard/blob/development/sui-move-contracts/spoke_token/sources/spoke_token.move)

   * [Spoke Token Implementation on EVM](https://github.com/venture-23/icon-token-standard/blob/development/solidity-contracts/icon-cross-chain-token/src/tokens/SpokeToken.sol)

3. Deploy Spoke Manager for Existing Token
   
    If a token issuer wants to upgrade the already existing token to a cross chain token then he/she can do so without upgrading their existing token contract. The token issue can deploy a Spoke Token Manager in order to lock their cross transferred token and release it on withdrawal of the token. This way of implementation will deploy a wrapped version of the token in any other foreign chains. For example, if there exists a XYZ token on EVM chain and the issuer wants to upgrade it to cross token standard then, the issuer will deploy a Spoke Token Manager on EVM chain. The cross transfer function is called from the manager contract which locks the XYZ token and the token is minted through Spoke Token on the destination chain. And if the XYZ token is withdrawn back to native chain, the manager contract releases the fund to destination address.

   * [Spoke Manager Implementation on SUI](https://github.com/venture-23/icon-token-standard/blob/development/sui-move-contracts/spoke_manager/sources/spoke_manager.move)
    
   * [Spoke Manager Implemantation on EVM](https://github.com/venture-23/icon-token-standard/blob/development/solidity-contracts/icon-cross-chain-token/src/tokens/SpokeTokenManager.sol)
