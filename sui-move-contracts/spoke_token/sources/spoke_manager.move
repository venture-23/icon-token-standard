/// Module: spoke_token
module spoke_token::spoke_manager {
    use sui::math::{Self};
    use std::string::String;
    use sui::coin::{Self, Coin};
    use sui::balance::{Self, Balance};
    use sui::package::UpgradeCap;
    use sui::sui::SUI;

    use spoke_token::spoke_token_utils::{address_to_hex_string, address_from_hex_string};
    use spoke_token::cross_transfer::{Self, wrap_hub_transfer, XCrossTransfer};
    use spoke_token::cross_transfer_revert::{Self, XCrossTransferRevert};

    use xcall::{main as xcall};
    use xcall::execute_ticket::{Self};
    use xcall::envelope::{Self};
    use xcall::rollback_ticket::{Self};
    use xcall::network_address::{Self};
    use xcall::xcall_state::{Storage, IDCap};


    public struct REGISTER_WITNESS has drop, store {}

    public struct WitnessCarrier has key { id: UID, witness: REGISTER_WITNESS }

    // === Errors ===

    const EAmountLessThanZero: u64 = 1;

    const EWrongVersion: u64 = 2;

    const ENotUpgrade: u64 = 3;

    const EBalanceExceeded: u64 = 4;

    const UnknownMessageType: u64 = 5;

    /// Constants
    const CURRENT_VERSION: u64 = 1;

    const CROSS_TRANSFER: vector<u8> = b"xCrossTransfer";
    const CROSS_TRANSFER_REVERT: vector<u8> = b"xCrossTransferTevert";

    public struct AdminCap has key{
        id: UID 
    }

    public struct ContractHoldings<phantom T> has key {
        id: UID,
        contract_holdings: Balance<T>,
    }

    public struct Config has key, store {
        id: UID,
        version: u64,
        sui_token: String,
        id_cap: IDCap,
        xcall_id: ID,
        sources: vector<String>,
        destinations: vector<String>,
    }

    fun init(ctx: &mut TxContext){
        transfer::transfer(AdminCap{
            id: object::new(ctx),
        }, ctx.sender())
    }

    // ====== Entrypoints =======

    // === Public Actions ===
    public fun cross_transfer<T>(
        config: &mut Config,
        x_ctx:&mut Storage,
        fee: Coin<SUI>,
        token: Coin<T>,
        to: String,
        data: Option<vector<u8>>,
        holdings: &mut ContractHoldings<T>,
        ctx: &mut TxContext,
    ){
        validate_version(config);
        let message_data = option::get_with_default(&data, b"");
        let amount = coin::value(&token);
        assert!(amount > 0, EAmountLessThanZero);
        let sender = ctx.sender();
        let balance = coin::into_balance(token);
        balance::join(&mut holdings.contract_holdings, balance);
        let from_address = address_to_hex_string(&sender);
        let x_message = wrap_hub_transfer(
            from_address,
            to,
            translate_outgoing_amount(amount),
            message_data
        );
        let x_rollback  = cross_transfer_revert::wrap_cross_transfer_revert(sender, amount);
        let x_encoded_msg = cross_transfer::encode(&x_message, CROSS_TRANSFER);
        let rollback = cross_transfer_revert::encode(&x_rollback, CROSS_TRANSFER_REVERT);
        let envelope = envelope::wrap_call_message_rollback(x_encoded_msg, rollback, config.sources, config.destinations);
        xcall::send_call(x_ctx, fee, get_idcap(config), config.sui_token, envelope::encode(&envelope), ctx);
    }

    public(package) fun execute_call<T>(
        config: &Config,
        x_ctx:&mut Storage,
        fee: Coin<SUI>,
        request_id:u128,
        data: vector<u8>,
        holdings: &mut ContractHoldings<T>,
        ctx: &mut TxContext,
    ){
        validate_version(config);
        let ticket = xcall::execute_call(x_ctx, get_idcap(config), request_id, data, ctx);
        let msg = execute_ticket::message(&ticket);
        let from = execute_ticket::from(&ticket);
        let protocols = execute_ticket::protocols(&ticket);

        let verified = verify_protocols(config, protocols);
        let method: vector<u8> = cross_transfer::get_method(&msg);

        if( verified && method == CROSS_TRANSFER && from == network_address::from_string(config.sui_token)){
            let message: XCrossTransfer = cross_transfer::decode(&msg);
            let string_to = cross_transfer::to(&message);
            let to  = network_address::addr(&network_address::from_string(string_to));
            let amount = translate_incoming_amount(cross_transfer::value(&message));
            let val =    balance::value(&holdings.contract_holdings);
            assert!(amount <= val, EBalanceExceeded);
            let balance = balance::split(&mut holdings.contract_holdings, amount);
            transfer::public_transfer(coin::from_balance(balance, ctx), address_from_hex_string(&to));
            xcall::execute_call_result(x_ctx, ticket, true, fee, ctx);
        }else {
            xcall::execute_call_result(x_ctx, ticket, false, fee, ctx);
        }
    }

    entry fun configure(
        _: &AdminCap,
        storage: &Storage, 
        witness_carrier: WitnessCarrier, 
        version: u64,
        sui_token: String,
        sources: vector<String>,
        destinations: vector<String>,
        xcall_id: ID,
        ctx: &mut TxContext 
    ){
        let w = get_witness(witness_carrier);
        let id_cap =   xcall::register_dapp(storage, w, ctx);
        
        transfer::share_object(Config{
            id: object::new(ctx),
            version,
            sui_token,
            id_cap,
            xcall_id,
            sources,
            destinations,
        });
    }

    fun get_witness(carrier: WitnessCarrier): REGISTER_WITNESS {
        let WitnessCarrier { id, witness } = carrier;
        id.delete();
        witness
    }

    entry fun execute_force_rollback(config: &Config, _: &AdminCap, xcall:&mut Storage, fee:Coin<SUI>, request_id:u128, data:vector<u8>, ctx:&mut TxContext){
        validate_version(config);
        let ticket = xcall::execute_call(xcall, get_idcap(config), request_id, data, ctx);
        xcall::execute_call_result(xcall,ticket,false,fee,ctx);
    }

    entry fun execute_rollback<T>(config: &Config, xcall: &mut Storage,holdings: &mut ContractHoldings<T>, sn: u128, ctx:&mut TxContext){
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
        let val =    balance::value(&holdings.contract_holdings);
        assert!(amount <= val, EBalanceExceeded);
        let balance = balance::split(&mut holdings.contract_holdings, amount);
        transfer::public_transfer(coin::from_balance(balance, ctx), to);
        xcall::execute_rollback_result(xcall,ticket,true)
    }

    fun translate_outgoing_amount(amount: u64): u128 {
        let multiplier = math::pow(10, 9) as u128;
        (amount as u128) * multiplier 
    }

    fun translate_incoming_amount(amount: u128): u64{
        (amount / (math::pow(10,9) as u128)) as u64
    }

    fun validate_version(self: &Config){
        assert!(self.version == CURRENT_VERSION, EWrongVersion);
    }


    entry fun migrate(self: &mut Config, _: &UpgradeCap){
        assert!(get_version(self) < CURRENT_VERSION, ENotUpgrade);
        set_version(self, CURRENT_VERSION);
    }

    fun set_version(config: &mut Config, version: u64){
        config.version = version
    }

    /// Getters
    public fun get_idcap(config: &Config): &IDCap{
        validate_version(config);
        &config.id_cap
    }

    // public fun get_xcall_manager_id<T>(config: &Config): ID{
    //     validate_version<T>(config);
    //     config.xcall_manager_id
    // }

    public fun get_xcall_id(config: &Config): ID{
        validate_version(config);
        config.xcall_id
    }

    public fun get_version(config: &Config): u64{
        config.version
    }

        public fun verify_protocols(config: &Config, protocols: vector<String>): bool{
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
