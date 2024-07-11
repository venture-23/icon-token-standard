/// Module: spoke_token
module spoke_token::spoke_token {
    use sui::math::{Self};
    use std::string::String;
    use sui::url::Url;
    use sui::coin::{Self, Coin, TreasuryCap, CoinMetadata};
    use sui::balance::{Self, Balance};
    use sui::package::UpgradeCap;
    use sui::sui::SUI;
    use sui::event;

    use spoke_token::spoke_token_utils::{address_to_hex_string, address_from_hex_string};
    use spoke_token::cross_transfer::{Self, wrap_hub_transfer, XCrossTransfer};
    use spoke_token::cross_transfer_revert::{Self};
    use spoke_token::manager::{Self, Config as ManagerConfig};

    use xcall::{main as xcall};
    use xcall::execute_ticket::{Self};
    use xcall::envelope::{Self};
    use xcall::network_address::{Self};
    use xcall::xcall_state::{Storage, IDCap};


    // === Errors ===

    const EAmountLessThanZero: u64 = 1;

    const EBalanceTooLow: u64 = 2;

    const ENotZero: u64 = 3;

    const EWrongVersion: u64 = 4;

    const ENotUpgrade: u64 = 5;

    /// Constants
    const CURRENT_VERSION: u64 = 1;

    const CROSS_TRANSFER: vector<u8> = b"xCrossTransfer";
    const CROSS_TRANSFER_REVERT: vector<u8> = b"xCrossTransferTevert";

    public struct SpokeToken<phantom T> has key, store {
        id: UID,
        // Balance of Spoke token
        balance: Balance<T>
    }

    public struct Config<phantom T> has key {
        id: UID,
        version: u64,
        icon_token: String,
        id_cap:IDCap,
        xcall_manager_id: ID,
        xcall_id: ID,
        balance_treasury_cap: TreasuryCap<T>
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

    public fun mint_and_transfer<T>(
        cap: &mut TreasuryCap<T>, amount: u64, receipent: address, ctx: &mut TxContext
    ){
        transfer::transfer(mint(cap, amount, ctx), receipent);
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

    // public fun hub_transfer<T>(
    //     cap: &mut TreasuryCap<T>,
    //     to: String, 
    //     token:Coin<T>,
    //     data: Option<vector<u8>>,
    //     ctx: &mut TxContext
    // ) {
    //     let messageData = option::get_with_default(&data, b"");
    //     let amount = coin::value(&token);
    //     assert!(amount > 0, EAmountLessThanZero);
    //     coin::burn(cap, token);

    //     let from = ctx.sender();

    //     let fromAddress = address_to_hex_string(&from);

    //     wrap_hub_transfer(
    //         fromAddress,
    //         to,
    //         translate_outgoing_amount(amount),
    //         messageData
    //     );
    // }

    public fun cross_transfer<T>(
        config: &mut Config<T>,
        x_ctx:&mut Storage,
        x_manager_conf: &ManagerConfig,
        fee: Coin<SUI>,
        token: Coin<T>,
        to: String,
        data: Option<vector<u8>>,
        cap: &mut TreasuryCap<T>,
        ctx: &mut TxContext,
    ){
        validate_version(config);
        let message_data = option::get_with_default(&data, b"");
        let amount = coin::value(&token);
        assert!(amount > 0, EAmountLessThanZero);
        coin::burn(cap, token);

        let sender = ctx.sender();
        let from_address = address_to_hex_string(&sender);
        let x_message = wrap_hub_transfer(
            from_address,
            to,
            translate_outgoing_amount(amount),
            message_data
        );
        let x_rollback  = cross_transfer_revert::wrap_cross_transfer_revert(sender, amount);

        let (source, destination) = manager::get_protocals(x_manager_conf);

        let x_encoded_msg = cross_transfer::encode(&x_message, CROSS_TRANSFER);
        let rollback = cross_transfer_revert::encode(&x_rollback, CROSS_TRANSFER_REVERT);
        let envelope = envelope::wrap_call_message_rollback(x_encoded_msg, rollback, source, destination);
        xcall::send_call(x_ctx, fee, get_idcap(config), config.icon_token, envelope::encode(&envelope), ctx);
    }

    public (package) fun execute_call<T>(
        config: &Config<T>,
        x_ctx:&mut Storage,
        x_manager_conf: &ManagerConfig,
        fee: Coin<SUI>,
        request_id:u128,
        data: vector<u8>,
        cap: &mut TreasuryCap<T>,
        ctx: &mut TxContext,
    ){
        validate_version(config);
        let ticket = xcall::execute_call(x_ctx, get_idcap(config), request_id, data, ctx);
        let msg = execute_ticket::message(&ticket);
        let from = execute_ticket::from(&ticket);
        let protocols = execute_ticket::protocols(&ticket);

        let verified = manager::verify_protocols(x_manager_conf, protocols);
        let method: vector<u8> = cross_transfer::get_method(&msg);

        if( verified && method == CROSS_TRANSFER && from == network_address::from_string(config.icon_token)){
            let message: XCrossTransfer = cross_transfer::decode(&msg);
            let string_to = cross_transfer::to(&message);
            let to  = network_address::addr(&network_address::from_string(string_to));
            let amount = translate_incoming_amount(cross_transfer::value(&message));
            // TODO: mint here
            mint_and_transfer(cap, amount, address_from_hex_string(&to),ctx);
            xcall::execute_call_result(x_ctx, ticket, true, fee, ctx);
        }else {
            xcall::execute_call_result(x_ctx, ticket, false, fee, ctx);
        }

    }

    fun translate_outgoing_amount(amount: u64): u128 {
        let multiplier = math::pow(10, 9) as u128;
        (amount as u128) * multiplier 
    }

    fun translate_incoming_amount(amount: u128): u64{
        (amount / (math::pow(10,9) as u128)) as u64
    }

    fun validate_version<T>(self: &Config<T>){
        assert!(self.version == CURRENT_VERSION, EWrongVersion);
    }


    entry fun migrate<T>(self: &mut Config<T>, _: &UpgradeCap){
        assert!(get_version(self) < CURRENT_VERSION, ENotUpgrade);
        set_version(self, CURRENT_VERSION);
    }

    fun set_version<T>(config: &mut Config<T>, version: u64){
        config.version = version
    }

    /// Getters
    public fun get_idcap<T>(config: &Config<T>): &IDCap{
        validate_version<T>(config);
        &config.id_cap
    }

    public fun get_xcall_manager_id<T>(config: &Config<T>): ID{
        validate_version<T>(config);
        config.xcall_manager_id
    }

    public fun get_xcall_id<T>(config: &Config<T>): ID{
        validate_version<T>(config);
        config.xcall_id
    }

    public fun get_version<T>(config: &Config<T>): u64{
        config.version
    }
}
