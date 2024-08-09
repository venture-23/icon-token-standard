/// Module: spoke_token
module spoke_token::spoke_token {
    use sui::math::{Self};
    use std::string::String;
    use sui::coin::{Self, Coin, TreasuryCap};
    use sui::package::UpgradeCap;
    use sui::sui::SUI;
    
    use spoke_token::spoke_token_utils::{address_to_hex_string, address_from_hex_string};
    use spoke_token::cross_transfer::{Self, wrap_hub_transfer, XCrossTransfer};
    use spoke_token::cross_transfer_revert::{Self, XCrossTransferRevert};
    use spoke_token::test_coin::{Self, TEST_COIN};

    use xcall::{main as xcall};
    use xcall::execute_ticket::{Self};
    use xcall::envelope::{Self};
    use xcall::rollback_ticket::{Self};
    use xcall::network_address::{Self};
    use xcall::xcall_state::{Self, Storage, IDCap};


    // === Errors ===

    const EAmountLessThanZero: u64 = 1;

    const EWrongVersion: u64 = 2;

    const ENotUpgrade: u64 = 3;

    const UnknownMessageType: u64 = 4;

    /// Constants
    const CURRENT_VERSION: u64 = 1;

    const CROSS_TRANSFER: vector<u8> = b"xCrossTransfer";
    
    const CROSS_TRANSFER_REVERT: vector<u8> = b"xCrossTransferTevert";

    public struct REGISTER_WITNESS has drop, store {}

    public struct WitnessCarrier has key { id: UID, witness: REGISTER_WITNESS }

    public struct AdminCap has key{
        id: UID 
    }

    public struct Config has key, store {
        id: UID,
        version: u64,
        icon_token: String,
        id_cap: IDCap,
        xcall_id: ID,
        sources: vector<String>,
        destinations: vector<String>,
        treasury_cap: TreasuryCap<TEST_COIN>,
    }

    fun init(ctx: &mut TxContext){
        transfer::transfer(AdminCap{
            id: object::new(ctx),
        }, ctx.sender());

        transfer::transfer(WitnessCarrier{
            id: object::new(ctx), 
            witness: REGISTER_WITNESS{},
        }, ctx.sender());
    }    

    /// Protected function
    /// Set sources  chain ids in config
    /// Set destinations chain ids in config
    public fun set_protocol(
        _: &mut AdminCap, 
        config: &mut Config, 
        sources: vector<String>, 
        destinations: vector<String>,
    ){
        vector::append(&mut config.sources, sources);
        vector::append(&mut config.destinations, destinations);
    }

    entry fun configure(
        _: &AdminCap,
        storage: &Storage, 
        witness_carrier: WitnessCarrier, 
        version: u64,
        icon_token: String, 
        sources: vector<String>,
        destinations: vector<String>,
        treasury_cap: TreasuryCap<TEST_COIN>,
        ctx: &mut TxContext,
    ){
        let w = get_witness(witness_carrier);
        let id_cap =   xcall::register_dapp(storage, w, ctx);
        let xcall_id = xcall_state::get_id_cap_xcall(&id_cap);
        
        transfer::share_object(Config{
            id: object::new(ctx),
            version,
            icon_token,
            id_cap,
            xcall_id,
            sources,
            destinations,
            treasury_cap,
        });
    }

    public entry fun cross_transfer(
        config: &mut Config,
        x_ctx: &mut Storage,
        fee: Coin<SUI>,
        token: Coin<TEST_COIN>,
        to: String,
        data: Option<vector<u8>>,
        ctx: &mut TxContext,
    ){
        validate_version(config);
        let message_data = option::get_with_default(&data, b"");
        let amount = coin::value(&token);
        assert!(amount > 0, EAmountLessThanZero);
        coin::burn(get_treasury_cap_mut(config), token);

        let sender = ctx.sender();
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
        xcall::send_call(x_ctx, fee, get_idcap(config), config.icon_token, envelope::encode(&envelope), ctx);
    }


    public entry fun execute_call(
        config: &mut Config,
        x_ctx: &mut Storage,
        fee: Coin<SUI>,
        request_id:u128,
        data: vector<u8>,
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
            test_coin::mint(get_treasury_cap_mut(config), amount, address_from_hex_string(&to),ctx);
            xcall::execute_call_result(x_ctx, ticket, true, fee, ctx);
        }else {
            xcall::execute_call_result(x_ctx, ticket, false, fee, ctx);
        }
    }

    public entry fun execute_rollback(
        config: &Config, 
        xcall: &mut Storage, 
        cap: &mut TreasuryCap<TEST_COIN>,
        sn: u128, 
        ctx:&mut TxContext
    ){
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
        test_coin::mint(cap, amount, to, ctx);
        xcall::execute_rollback_result(xcall,ticket,true)
    }

    public entry fun execute_force_rollback(
        config: &Config, 
        _: &AdminCap,  
        xcall:&mut Storage, 
        fee:Coin<SUI>, 
        request_id:u128, 
        data:vector<u8>, 
        ctx:&mut TxContext
    ){
        validate_version(config);
        let ticket = xcall::execute_call(xcall, get_idcap(config), request_id, data, ctx);
        xcall::execute_call_result(xcall,ticket,false,fee,ctx);
    }

    entry fun migrate(self: &mut Config, _: &UpgradeCap){
        assert!(get_version(self) < CURRENT_VERSION, ENotUpgrade);
        set_version(self, CURRENT_VERSION);
    }

    entry fun set_token(_:&AdminCap, config: &mut Config, icon_token: String){
        validate_version(config);
        config.icon_token = icon_token;
    }

    /// Getters
    public fun get_idcap(config: &Config): &IDCap{
        validate_version(config);
        &config.id_cap
    }

    public fun get_xcall_id(config: &Config): ID{
        validate_version(config);
        config.xcall_id
    }

    public fun get_version(config: &Config): u64{
        config.version
    }

    // Private actions
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

    fun get_treasury_cap_mut(config: &mut Config): &mut TreasuryCap<TEST_COIN>{
        &mut config.treasury_cap
    }
    fun get_witness(carrier: WitnessCarrier): REGISTER_WITNESS {
        let WitnessCarrier { id, witness } = carrier;
        id.delete();
        witness
    }

    fun set_version(config: &mut Config, version: u64){
        config.version = version
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
}