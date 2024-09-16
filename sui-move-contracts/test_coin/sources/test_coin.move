/// This module implements a simple coin (token) system called `TEST_COIN`. For implementation as spoke token
/// and spoke manager there are two implementation case.
/// 
/// Case 1: Deploying a Token as a Spoke Token
///     - Transfer the treasury cap directly to the Spoke token contract. The Spoke token takes over ownership and 
///       handles the burn-and-mint mechanism seamlessly, ensuring smooth cross-chain functionality.
///
/// Case 2: Deploying a Token as a Spoke Manager
///     - No need to transfer the treasury cap. The manager contract locks the tokens during cross-chain transfers and 
///       automatically releases them when transferring back from the foreign chain to the home chain.
module test_coin::test_coin {
    use sui::coin::{Self, Coin, TreasuryCap};
    use sui::url;
    
    ///  Struct representing the TEST_COIN token.
    /// `TEST_COIN` will be used as a base structure to define the coin and its operations.
    ///  NOTE: Developer are requested to update the name of the struct as per your token name
    public struct TEST_COIN has drop {}

    fun init(witness: TEST_COIN, ctx:&mut TxContext){
        let (treasury, metadata) = coin::create_currency(
            witness, 
            9, 
            b"TC", 
            b"TestCoin", 
            b"Our Test Coin", 
            option::some(url::new_unsafe_from_bytes(b"https://coin-test.png")),
            ctx
        );
        transfer::public_freeze_object(metadata);
        transfer::public_transfer(treasury, ctx.sender());
    }

    public entry fun mint(
        treasury_cap: &mut TreasuryCap<TEST_COIN>, 
        amount: u64, 
        recipient: address, 
        ctx: &mut TxContext
    ){
        coin::mint_and_transfer(treasury_cap, amount, recipient, ctx)
    }

    public entry fun burn(treasury_cap: &mut TreasuryCap<TEST_COIN>, token: Coin<TEST_COIN>){
        coin::burn(treasury_cap, token);
    }
}
