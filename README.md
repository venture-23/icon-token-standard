# icon-token-standard

The cross chain token standard interface is documented below and is under discussion in icon-project repo.

ICON IIP: https://github.com/venture-23/iip-cross-chain-token/blob/development/IIPS/iip-cross-chain-token.md 

Link to discussion: https://github.com/icon-project/IIPs/discussions/74 

The Cross Chain Token Standard aims to enable interoperability across multiple chains connected via ICON's GMP. This standard will facilitate seamless migration of existing tokens on ICON and chains connected by ICON GMP to a new cross-chain token standard designed for compatibility and easy integration with Balanced. This repo contains the implementation library with some use case examples on ICON, SUI and EVM chains.

## Implementation

Follow the below links to implement it on any specific chains:
1. [ICON](#icon)
2. [EVM](#evm)
3. [SUI](#sui)


The exists three different scenarios for the cross chain token standard implementation, which are listed below:

1. Deploy New Cross Chain Token
   
   If a user wants to deploy a fresh new cross chain token, he/she can just extend the Hub/Spoke Token Standard Implementation library based on their requirement. If the chain is ICON, Hub Token is supposed to be deployed and if it is any other foreign chains then Spoke Token is supposed to be deployed. This way of implementation helps to deploy a native token in any other foreign chains. For example, if a token issuer wants to issue a new cross chain token on ICON, he/she will extend the HubToken Implementation library (and add some custom functionality if necessary) into the token contract and deploy it on ICON, and deploy a SpokeToken Implementation contract on all other foreign chains.

    * [Hub Token Implementaion on ICON](https://github.com/venture-23/icon-token-standard/blob/development/java-contracts/CrossChainToken/src/main/java/icon/cross/chain/token/lib/tokens/HubTokenImpl.java)
  
    Example for deploying a new cross chain token on:
   * [ICON](https://github.com/venture-23/icon-token-standard/blob/development/java-contracts/token-examples/NewCrossTokenDeploy/src/main/java/icon/cross/chain/token/examples/NewCrossTokenImpl.java)

   * [SUI](https://github.com/venture-23/icon-token-standard/blob/development/sui-move-contracts/test_coin/sources/test_coin.move)

    * [EVM](https://github.com/venture-23/icon-token-standard/blob/development/solidity-contracts/icon-cross-chain-token/src/implementation/NewCrossToken.sol)

2. Upgrade Existing Token to Cross Chain Token
   
   If a token issuer wants to upgrade the already existing token to a cross chain token then he/she can upgrade their existing token contract by extending the Cross Token Standard library based on token type if it is ICON extend Hub Token, if any other foreign chains extend Spoke Token. This way of implementation helps to deploy a native token in any other foreign chains. For example, if there exists a token ABC on SUI chain and the issuer wants to upgrade it to cross chain standard then, the issuer will upgrade the ABC token by extending the Spoke Token library on SUI.

   * [Spoke Token Implementation on SUI](https://github.com/venture-23/icon-token-standard/blob/development/sui-move-contracts/spoke_token/sources/spoke_token.move)

   * [Spoke Token Implementation on EVM](https://github.com/venture-23/icon-token-standard/blob/development/solidity-contracts/icon-cross-chain-token/src/tokens/SpokeToken.sol)

3. Deploy Spoke Manager for Existing Token
   
   If a token issuer wants to upgrade the already existing token to a cross chain token then he/she can do so without upgrading their existing token contract. The token issue can deploy a Spoke Token Manager in order to lock their cross transferred token and release it on withdrawal of the token. This way of implementation will deploy a wrapped version of the token in any other foreign chains. For example, if there exists a XYZ token on EVM chain and the issuer wants to upgrade it to cross token standard then, the issuer will deploy a Spoke Token Manager on EVM chain. The cross transfer function is called from the manager contract which locks the XYZ token and the token is minted through Spoke Token on the destination chain. And if the XYZ token is withdrawn back to native chain, the manager contract releases the fund to the destination address.

   * [Spoke Manager Implementation on SUI](https://github.com/venture-23/icon-token-standard/blob/development/sui-move-contracts/spoke_manager/sources/spoke_manager.move)
    
   * [Spoke Manager Implemantation on EVM](https://github.com/venture-23/icon-token-standard/blob/development/solidity-contracts/icon-cross-chain-token/src/tokens/SpokeTokenManager.sol)


## ICON

ICON is the only Hub chain in this cross chain standard. All the message passing goes through the ICON chain so, for all cross chain tokens, a Hub Token contract is deployed on ICON. For a token from SUI/EVM a Spoke Token is deployed on its native and other Spoke chains whereas a Hub Token is deployed on the ICON chain. For a token from ICON a Hub Token is deployed on its native i.e ICON and on other Spoke chains, Spoke Token is deployed.

If you want to deploy a new cross chain token on ICON then you must extend HubTokenImpl in your token contract along with your custom functionality and deploy it. The implementation example for this is shown [here](https://github.com/venture-23/icon-token-standard/blob/development/java-contracts/token-examples/NewCrossTokenDeploy/src/main/java/icon/cross/chain/token/examples/NewCrossTokenImpl.java).

Also, if you want to upgrade an existing token to a cross chain token, in this case also you need to extend HubTokenImpl in your existing token contract and upgrade the contract. The implementation example is the same as above where instead of deploying a new contact you update an existing contract.

### Scripts

Go to the directory.
``` 
cd java-contracts
```

#### Requirements
Install the dependencies to deploy a contract on ICON. Follow the steps provided on the link below:

https://github.com/icon-project/java-score-examples?tab=readme-ov-file#requirements


#### 1. Build the project
To build overall project
```
$ ./gradlew build
```

To build NewCrossTokenDeploy example
```
$ ./gradlew NewCrossTokenDeploy:build
```

The compiled jar bundle will be generated at `./token-examples/NewCrossTokenDeploy/build/libs/NewCrossTokenDeploy-0.1.0.jar`.

#### 2. Optimize the jar
You need to optimize your jar bundle before you deploy it to local or ICON networks.
This involves some pre-processing to ensure the actual deployment successful.
Run the `optimizedJar` task to generate the optimized jar bundle.

```
$ ./gradlew NewCrossTokenDeploy:optimizedJar
```
The output jar will be located at `./token-examples/NewCrossTokenDeploy/build/libs/NewCrossTokenDeploy-0.1.0-optimized.jar`.

#### 3. Deploy the optimized jar
Using `goloop` CLI command
Now you can deploy the optimized jar to ICON networks that support the Java SCORE execution environment.
You can create a deploy transaction with the optimized jar and deploy it to the testnet (Lisbon testnet is used in this example) network as follows.

```
$ goloop rpc sendtx deploy ./token-examples/NewCrossTokenDeploy/build/libs/NewCrossTokenDeploy-0.1.0-optimized.jar \
    --uri https://lisbon.net.solidwallet.io/api/v3 \
    --key_store <your_wallet_json> --key_password <password> \
    --nid 2 \
    --step_limit=1000000 \
    --content_type application/java \
    --param _xCall=cx15a339fa60bd86225050b22ea8cd4a9d7cd8bb83 \
    --param _xCallManager=cx5040180f7b0cd742658cb9050a289eca03083b70 \
    --param _nid=0x2.icon \
    --param _tokenName=Cross Chain Demo Token \
    --param _symbolName=CDM \
    --param _tokenNativeNid=0xa869.fuji \
    --param _decimals=18
```

#### 4. Verify the execution

Check the deployed SCORE address first using the txresult command.
```
$ goloop rpc txresult <tx_hash> --uri https://lisbon.net.solidwallet.io/api/v3
{
  ...
  "scoreAddress": "cxaa736426a9caed44c59520e94da2d64888d9241b",
  ...
}
```

For more details visit the below link:

https://github.com/icon-project/java-score-examples?tab=readme-ov-file#java-score-examples


## EVM

EVM is one of the Spoke chains connected via ICON's GMP. Spoke Token contrats are deployed on EVM for the tokens from EVM as well as other foreign chains. 

### Installation
We used Foundry as a smart contract development toolchain. You need to install Foundry before using it.

Foundry installation docs:

https://book.getfoundry.sh/getting-started/installation 

### Getting Started 
Cloning the cross token standard git repo by running the following command.

``` 
git clone https://github.com/venture-23/icon-token-standard.git 
```

You can find the Spoke Token and Spoke Manager implementation in the below directory.
```
cd solidity-contracts/icon-cross-chain-token/src/tokens
```

There are two ways you can implement cross token standard on EVM, that are listed below:

1. Deploy Spoke Token
   
   If you want to deploy a Spoke Contract for a token from foreign chain on EVM then you can deploy a ```src/tokens/SpokeToken.sol``` contract. For example, if you want to migrate a token($XYZ) from ICON to EVM then, you need to deploy a Spoke Token contract for the token XYZ on EVM. For that, ```SpokeToken.sol``` is deployed on EVM. 

2. Deploy Spoke Manager
   
   If you want to make an existing token on EVM a cross chain token then you need to deploy ```src/tokens/SpokeTokenManager.sol``` contract. For example, if you have an existing token($ABC) on EVM and you want to make it a cross chain token then, you can just deploy a Spoke Manager contract for that token without upgrading your existing token contract. For that, ```SpokeTokenManager.sol``` is deployed on EVM. 


### Scripts

Follow the below steps to deploy a cross chain token on EVM.

#### 1. Setup Configs
Got to the home directory.
``` 
cd solidity-contracts/icon-cross-chain-token
```

Create a ```.env``` file in home the directory and update the configs as shown in below example. 

Following command will create a ```.env``` file from the ```.env.sample```.

```
cp .env.sample .env 
```

Example of configs inside .env file.
```shell
FUJI_RPC_URL=
FUJI_NID=
SNOWSCAN_API_KEY=
PRIVATE_KEY=
OWNER=
```

Here is a description of the fields:
```FUJI_RPC_URL``` is the rpc url for Fuji Testnet.

```FUJI_NID``` is Fuji Testnet nid.

```SNOWSCAN_API_KEY``` is a Snowscan API key.

```PRIVATE_KEY``` is the private key of the wallet that is used to deploy the contract.

```OWNER``` is the address of the wallet that is used to deploy the contract.

#### 2. Build the project
Run below command to build the contract.

```
forge build
```

#### 3. Deploy contracts
Then, run the following command to deploy a cross chain token based on the token type you are trying to deploy.

Deploy Spoke Token
```shell
forge script scripts/DeployCrossToken.s.sol:DeployCrossToken  -s "deploySpokeToken(string memory name, string memory symbol, address xCall, string memory iconTokenAddress, address xCallManager) " <name> <symbol> <xCall> <iconToken> <xCallManager> --fork-url <rpc_url> --broadcast --sender DEPLOYER_WALLET_ADDRESS --verify src/implementation/NewCrossToken.sol --etherscan-api-key  <api-key> --ffi
```

Deploy Spoke Manager
```shell
forge script scripts/DeployCrossToken.s.sol:DeployCrossToken  -s "deploySpokeTokenManager(address token, address xCall, string memory iconTokenAddress, address xCallManager)" <token> <xCall> <iconToken> <xCallManager> --fork-url <rpc_url> --broadcast --sender DEPLOYER_WALLET_ADDRESS --verify src/tokens/SpokeTokenManager.sol --etherscan-api-key  <api-key> --ffi
```

This will deploy a new cross chain token on EVM.


## SUI

SUI is one of the Spoke chains connected via ICON's GMP. Spoke Token contrats are deployed on SUI for the tokens from SUI as well as other foreign chains. 

### Installation
First make sure you have ts-node installed globally on your machine.

```
npm install -g ts-node
```

### Getting Started

Cloning the cross token standard git repo by running the following command.

``` 
git clone https://github.com/venture-23/icon-token-standard.git 
```

If you wish to deploy a new cross chain token then,
change into the directory.

``` 
cd sui-move-contracts/spoke_token 
```

OR

If you want to deploy Spoke Manager Contract for an existing token then, change into the directory
``` 
cd sui-move-contracts/spoke_manager 
```


There are two ways you can implement cross token standard on SUI, that are listed below:

1. Deploy Spoke Token
   
   If you are planning to deploy a Spoke Contract for a token from foreign chain on SUI then you can deploy a ```spoke_token/sources/spoke_token.move``` contract. 

   First, in ```spoke_token/sources/impl/test_coin.move``` contract you must change the token module name and WITNESS. This contract implements the SUI coin standard [0x2::coin](https://github.com/MystenLabs/sui/blob/main/crates/sui-framework/packages/sui-framework/sources/coin.move). 
   
   Next, you must change coin type on ```spoke_token/sources/spoke_token.move``` to the coin type that you deployed in above step. For example, replace [COIN_TYPE](https://github.com/venture-23/icon-token-standard/blob/7c1ab7c9e0923e57713e94f23f2b6b321b6b13d8/sui-move-contracts/spoke_token/sources/spoke_token.move#L12) with your "COIN_TYPE" from above step, everywhere you find "TEST_COIN" on ```spoke_token.move``` contract.

   If you run the [Scripts](#scripts) provided below from ```spoke_token/scripts/main.ts``` then, it will deploy a "YOUR_COIN_TYPE" contract and a Spoke Token contract for the given coin type.

2. Deploy Spoke Manager
   
   If you want to deploy a spoke manager for an existing token then, you need to deploy ```spoke_manager/sources/spoke_manager.move``` contract by updating the [COIN_TYPE](https://github.com/venture-23/icon-token-standard/blob/ff32ed9e2ac34501dc614b81796dfc101a0aa847/sui-move-contracts/spoke_manager/sources/spoke_manager.move#L14) to "YOUR_COIN_TYPE". 
   
   If you run the [Scripts](#scripts) provided below from ```spoke_manager/scripts/main.ts``` then, it will deploy a Spoke Manager contract for the given coin type.

### Note:
It is recommended that, if you are deploying a new cross chain token on SUI (i.e. on native chain) then the best way to implement cross token standard is using the spoke manager approach. For this, you need to first deploy a token following the SUI coin standard as shown in the ```test_coin/sources/test_coin.move``` example then, deploy a Spoke Manager for that token. 

If you wish to deploy a new token using the Spoke Token implementation approach then you must add admin controlled mint/burn functionality in ```spoke_token.move``` contract before deploying it. This is because, while configuring the spoke token contract you need to transfer TreasuryCap<> to the Spoke Token contract so the deployer won't have TreasuryCap<> to call mint/burn function later. So if you want that functionality in future, you must add it in a spoke token contract where you can get the cap from the Config shared object.


### Scripts
Follow the below steps to deploy a cross chain token on SUI.

#### 1. Setup Configs
Install package dependency for deployment script.
``` 
yarn install 
```

Create a ```.env``` file and update the configs as shown in below example. 

Following command will create a ```.env``` file from the ```.env.sample```.

```
cp .env.sample .env 
```

Example of configs inside .env file.
```shell 
MNEMONICS=""
NETWORK="testnet"
X_STORAGE="0xc6c58d63863b7a1fdc8e10fa70dc9d8153543e1185f609d05c3af549615dec3f"
SOURCE="centralized-1"
DESTINATION="cx07300971594d7160a9ec62e4ec68d8fa10b9d9dc"
ICON_TOKEN= "0x2.icon/cx38cfd5689c7951606d049c04b0a4a549c2910b6b"

```
Here is a description of the fields:

```MNEMONICS``` is the mnemonics of the wallet that will be used to deploy the package.

```NETWORK``` is the network on which a contract is deployed.

```X_STORAGE``` is an object id of x-call state.

```SOURCE``` is the connection address of source chain i.e SUI. To get this address you need to contact the x-call team and deploy your own connection address for your Dapp.

```DESTINATION``` is the connection address of the destination chain i.e ICON. You need to deploy your own connection address on ICON.

```ICON_TOKEN``` is the hub token address for the token on the ICON chain.


#### 2. Deploy and configure package
Now all the setup is done, we are ready to deploy a new cross chain token on SUI. For that run below commands from ```spoke_token```  or ```spoke_manager``` directory.

```
ts-node scripts/main.ts
```

This command will deploy a new Spoke Token if the command is run from ```spoke_token``` dir (and Spoke Manager Contract if command is run from ```spoke_manager``` dir). It will also run the configuration setups for the deployed token package.

Now, you can call the ```cross_transfer```  function on the deployed spoke token or spoke manager package. This will transfer the token from source chain to the destination chain.
