module spoke_token::new_cross_token{
    use sui::url::Url;
    use sui::sui::{SUI};
    use sui::coin::{TreasuryCap, Coin};
    use std::string::{String};

    use spoke_token::spoke_token::{Self, Config};
    use xcall::xcall_state::{Storage};

    public struct DEMO_FOREIGN has drop {}

    #[allow(lint(self_transfer))]
    public fun create_currency(
        witness: DEMO_FOREIGN, 
        decima: u8, 
        symbol: vector<u8>, 
        name: vector<u8>, 
        description: vector<u8>,
        icon_url: Option<Url>,
        ctx: &mut TxContext
        ){
        let (cap, metadata) = spoke_token::create_spoke_currency(witness, decima, symbol, name, description, icon_url, ctx);
        transfer::public_freeze_object(metadata);
        transfer::public_transfer(cap, ctx.sender());
    }

    public entry fun mint(cap:&mut TreasuryCap<DEMO_FOREIGN> ,  amount: u64, ctx: &mut TxContext){
        spoke_token::mint_and_transfer(cap, amount, ctx.sender(), ctx);
    }

    public fun transfer(
        config: &mut Config,
        x_ctx: &mut Storage,
        fee: Coin<SUI>,
        token: Coin<DEMO_FOREIGN>,
        to: String,
        data: Option<vector<u8>>,
        cap: &mut TreasuryCap<DEMO_FOREIGN>,
        ctx: &mut TxContext,
    ){
        spoke_token::cross_transfer(config, x_ctx, fee, token, to, data, cap, ctx);
    }

}