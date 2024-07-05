/// Module: spoke_token
module spoke_token::spoke_token {
    use sui::sui::{Self, SUI};
    use sui::coin::{Self, Coin, TreasuryCap};
    use sui::balance::{Self, Balance};
    use spoke_token::spoke_token_utils::{address_to_hex_string, address_from_hex_string};

    use spoke_token::hub_transfer::{Self, wrap_hub_transfer, XHubTransfer};


    // === Errors ===

    const EAmountLessThanZero:u64 = 11;

    public struct SpokeToken<phantom T> has key, store {
        id: UID,
        // Balance of Spoke token
        balance: Balance<T>
    }

    public fun hub_transfer<T>(
        cap: &mut TreasuryCap<T>,
        to: String, 
        token:Coin<T>,
        data: Option<vector<u8>>,
        ctx: &mut TxContext
    ) {
        let messageData = option::get_with_default(&data, b"");
        let amount = coin::value(&token);
        assert!(amount > 0, EAmountLessThanZero);
        coin::burn(cap, token);

        let from = ctx.sender();

        let fromAddress = address_to_hex_string(&from);

        let xcallMessageStruct = wrap_hub_transfer(
            fromAddress,
            to,
            translate_outgoing_amount(amount),
            messageData
        );
    }



    fun translate_outgoing_amount(amount: u64): u128 {
        let multiplier = math::pow(10, 9) as u128;
        (amount as u128) * multiplier 
    }

}

