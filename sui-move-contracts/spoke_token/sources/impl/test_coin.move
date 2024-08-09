module spoke_token::test_coin{
   use sui::coin::{Self, TreasuryCap};
   use sui::url;

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
  
   public(package) fun mint(
      treasury_cap: &mut TreasuryCap<TEST_COIN>, 
      amount: u64, 
      recipient: address, 
      ctx: &mut TxContext
   ){
      coin::mint_and_transfer(treasury_cap, amount, recipient, ctx)
   }
}