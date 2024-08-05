/// Module: spoke_token
module spoke_token::spoke_token {
    use sui::math::{Self};
    use std::string::String;
    use sui::coin::{Self, Coin};
    use sui::balance::{Self, Balance};
    use sui::package::UpgradeCap;
    use sui::sui::SUI;
    use sui::vec_map::{Self, VecMap};


    use spoke_token::spoke_token_utils::{address_to_hex_string, address_from_hex_string};
    use spoke_token::cross_transfer::{Self, wrap_hub_transfer, XCrossTransfer};
    use spoke_token::cross_transfer_revert::{Self, XCrossTransferRevert};

    use xcall::{main as xcall};
    use xcall::execute_ticket::{Self};
    use xcall::envelope::{Self};
    use xcall::rollback_ticket::{Self};
    use xcall::network_address::{Self};
    use xcall::xcall_state::{Storage, IDCap};


    // === Errors ===

    const EAmountLessThanZero: u64 = 1;

    const EWrongVersion: u64 = 4;

    const ENotUpgrade: u64 = 5;

    const EBalanceExceeded: u64 = 6;

    const UnknownMessageType: u64 = 7;

    /// Constants
    const CURRENT_VERSION: u64 = 1;

    const CROSS_TRANSFER: vector<u8> = b"xCrossTransfer";
    const CROSS_TRANSFER_REVERT: vector<u8> = b"xCrossTransferTevert";

    public struct AdminCap has key{
        id: UID 
    }

    public struct SpokeToken<phantom T> has key, store {
        id: UID,
        // Balance of Spoke token
        balance: Balance<T>,
    }

    public struct TokenTreasury<phantom T> has key {
        id: UID,
        balance: Balance<T>,
        owner: VecMap<address, u64>
    }

    public struct Config<phantom T> has key {
        id: UID,
        version: u64,
        icon_token: String,
        id_cap: IDCap,
        xcall_id: ID,
        sources: vector<String>,
        destinations: vector<String>
    }

    fun init(ctx: &mut TxContext){
        transfer::transfer(AdminCap{
            id: object::new(ctx),
        }, ctx.sender())
    }
    // ====== Entrypoints =======


    // === Public Actions ===
    public fun cross_transfer<T>(
        config: &mut Config<T>,
        x_ctx:&mut Storage,
        // x_manager_conf: &ManagerConfig,
        fee: Coin<SUI>,
        token: Coin<T>,
        to: String,
        data: Option<vector<u8>>,
        treasury: &mut TokenTreasury<T>,
        ctx: &mut TxContext,
    ){
        validate_version(config);
        let message_data = option::get_with_default(&data, b"");
        let amount = coin::value(&token);
        assert!(amount > 0, EAmountLessThanZero);
        // ===
        let balance = coin::into_balance(token);
        balance::join(&mut treasury.balance, balance);
        // ===

        let sender = ctx.sender();
        let from_address = address_to_hex_string(&sender);
        let x_message = wrap_hub_transfer(
            from_address,
            to,
            translate_outgoing_amount(amount),
            message_data
        );
        let x_rollback  = cross_transfer_revert::wrap_cross_transfer_revert(sender, amount);

        // let (source, destination) = manager::get_protocals(x_manager_conf);

        let x_encoded_msg = cross_transfer::encode(&x_message, CROSS_TRANSFER);
        let rollback = cross_transfer_revert::encode(&x_rollback, CROSS_TRANSFER_REVERT);
        let envelope = envelope::wrap_call_message_rollback(x_encoded_msg, rollback, config.sources, config.destinations);
        xcall::send_call(x_ctx, fee, get_idcap(config), config.icon_token, envelope::encode(&envelope), ctx);
    }

    public(package) fun execute_call<T>(
        config: &Config<T>,
        x_ctx:&mut Storage,
        // x_manager_conf: &ManagerConfig,
        fee: Coin<SUI>,
        request_id:u128,
        data: vector<u8>,
        treasury: &mut TokenTreasury<T>,
        ctx: &mut TxContext,
    ){
        validate_version(config);
        let ticket = xcall::execute_call(x_ctx, get_idcap(config), request_id, data, ctx);
        let msg = execute_ticket::message(&ticket);
        let from = execute_ticket::from(&ticket);
        let protocols = execute_ticket::protocols(&ticket);

        let verified = verify_protocols(config, protocols);
        let method: vector<u8> = cross_transfer::get_method(&msg);

        if( verified && method == CROSS_TRANSFER && from == network_address::from_string(config.icon_token)){
            let message: XCrossTransfer = cross_transfer::decode(&msg);
            let string_to = cross_transfer::to(&message);
            let to  = network_address::addr(&network_address::from_string(string_to));
            let amount = translate_incoming_amount(cross_transfer::value(&message));
            let val = vec_map::get(&treasury.owner, &address_from_hex_string(&to));
            assert!(amount <= *val, EBalanceExceeded);
            let balance = balance::split(&mut treasury.balance, amount);
            transfer::public_transfer(coin::from_balance(balance, ctx), address_from_hex_string(&to));
            xcall::execute_call_result(x_ctx, ticket, true, fee, ctx);
        }else {
            xcall::execute_call_result(x_ctx, ticket, false, fee, ctx);
        }
    }

    entry fun execute_force_rollback<T>(config: &Config<T>, _: &AdminCap,  xcall:&mut Storage, fee:Coin<SUI>, request_id:u128, data:vector<u8>, ctx:&mut TxContext){
        validate_version(config);
        let ticket = xcall::execute_call(xcall, get_idcap(config), request_id, data, ctx);
        xcall::execute_call_result(xcall,ticket,false,fee,ctx);
    }

        entry fun execute_rollback<T>(config: &Config<T>, xcall: &mut Storage, sn: u128, ctx:&mut TxContext){
        validate_version(config);
        let ticket = xcall::execute_rollback(xcall, get_idcap(config), sn, ctx);
        let msg = rollback_ticket::rollback(&ticket);
        let method: vector<u8> = cross_transfer::get_method(&msg);
        assert!(
            method == CROSS_TRANSFER_REVERT,
            UnknownMessageType
        );

        let message: XCrossTransferRevert = cross_transfer_revert::decode(&msg);
        let to = cross_transfer_revert::to(&message);
        let amount: u64 = cross_transfer_revert::value(&message);
        // balanced_dollar::mint(get_treasury_cap_mut(config), to, amount,  ctx); TODO: how to solve this
         xcall::execute_rollback_result(xcall,ticket,true)
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

    // public fun get_xcall_manager_id<T>(config: &Config<T>): ID{
    //     validate_version<T>(config);
    //     config.xcall_manager_id
    // }

    public fun get_xcall_id<T>(config: &Config<T>): ID{
        validate_version<T>(config);
        config.xcall_id
    }

    public fun get_version<T>(config: &Config<T>): u64{
        config.version
    }

        public fun verify_protocols<T>(config: &Config<T>, protocols: vector<String>): bool{
        validate_version(config);
        verify_protocols_unordered(config.sources, protocols)
    }

    fun verify_protocols_unordered(array1: vector<String>, array2: vector<String>): bool{
        let len  =  vector::length(&array1);
        if(len != vector::length(&array2)){
            false
        } else{
            let mut matched = true;
            let mut i = 0;
            while(i < len){
                let protocol = vector::borrow(&array2, i);
                if (!vector::contains(&array1, protocol)){
                    matched = false;
                    break
                };
                i = i +1;
            };
            matched
        }
    }
}
