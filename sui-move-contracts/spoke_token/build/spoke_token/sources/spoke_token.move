/// Module: spoke_token
module spoke_token::spoke_token {
    use sui::math::{Self};
    use std::string::String;
    use sui::url::{Self, Url};
    use sui::coin::{Self, Coin, TreasuryCap, CoinMetadata};
    use sui::balance::{Self, Balance};
    use sui::event;

    use spoke_token::spoke_token_utils::{address_to_hex_string, address_from_hex_string};
    use spoke_token::hub_transfer::{Self, wrap_hub_transfer, XHubTransfer};


    // === Errors ===

    const EAmountLessThanZero: u64 = 1;

    const EBalanceTooLow: u64 = 2;

    const ENotZero: u64 = 3;

    public struct SpokeToken<phantom T> has key, store {
        id: UID,
        // Balance of Spoke token
        balance: Balance<T>
    }

    /// Create new currency of type 'T'
    public fun create_spoke_currency<T: drop>(
        witness: T,
        decimals: u8,
        symbol: vector<u8>,
        name: vector<u8>,
        description: vector<u8>,
        icon_url: Option<Url>,
        ctx: &mut TxContext
    ): (TreasuryCap<T>, CoinMetadata<T>){
        coin::create_currency<T>(witness, decimals, symbol, name, description, icon_url, ctx)
    }

    /// Mint a `SpokeToken` with a given `amount` using the `TreasuryCap`.
    public fun mint<T>(
        cap: &mut TreasuryCap<T>, amount: u64, ctx: &mut TxContext
    ): SpokeToken<T> {
        let balance = cap.supply_mut().increase_supply(amount);
        SpokeToken { id: object::new(ctx), balance }
    }


    /// Burn a `SpokeToken` using the `TreasuryCap`.
    public fun burn<T>(cap: &mut TreasuryCap<T>, token: SpokeToken<T>) {
        let SpokeToken { id, balance } = token;
        cap.supply_mut().decrease_supply(balance);
        id.delete();
    }

    // === Public Actions ===

    /// Join two `SpokeToken`s into one, always available.
    public fun join<T>(token: &mut SpokeToken<T>, another: SpokeToken<T>) {
        let SpokeToken { id, balance } = another;
        token.balance.join(balance);
        id.delete();
    }

    /// Split a `SpokeToken` with `amount`.
    /// Aborts if the `SpokeToken.balance` is lower than `amount`.
    public fun split<T>(
        token: &mut SpokeToken<T>, amount: u64, ctx: &mut TxContext
    ): SpokeToken<T> {
        assert!(token.balance.value() >= amount, EBalanceTooLow);
        SpokeToken {
            id: object::new(ctx),
            balance: token.balance.split(amount),
        }
    }

    /// Create a zero `SpokeToken`.
    public fun zero<T>(ctx: &mut TxContext): SpokeToken<T> {
        SpokeToken {
            id: object::new(ctx),
            balance: balance::zero(),
        }
    }

    /// Destroy an empty `SpokeToken`, fails if the balance is non-zero.
    /// Aborts if the `SpokeToken.balance` is not zero.
    public fun destroy_zero<T>(token: SpokeToken<T>) {
        let SpokeToken { id, balance } = token;
        assert!(balance.value() == 0, ENotZero);
        balance.destroy_zero();
        id.delete();
    }

    #[allow(lint(custom_state_change, self_transfer))]
    /// Transfer the `SpokeToken` to the transaction sender.
    public fun keep<T>(token: SpokeToken<T>, ctx: &mut TxContext) {
        transfer::transfer(token, ctx.sender())
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

        wrap_hub_transfer(
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

