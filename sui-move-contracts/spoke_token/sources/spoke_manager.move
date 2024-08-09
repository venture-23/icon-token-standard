/// Module: spoke_token
module spoke_token::spoke_manager {
    use sui::math::{Self};
    use std::string::{Self, String};
    use std::type_name::{Self};
    use sui::coin::{Self, Coin};
    use sui::balance::{Self, Balance};
    use sui::package::UpgradeCap;
    use sui::sui::SUI;

    use spoke_token::spoke_token_utils::{address_to_hex_string, address_from_hex_string, get_token_type};
    use spoke_token::deposit::{Self};
    use spoke_token::deposit_revert::{Self};
    use spoke_token::withdraw_to::{Self};
    use spoke_token::test_coin::{TEST_COIN};

    use xcall::{main as xcall};
    use xcall::execute_ticket::{Self};
    use xcall::envelope::{Self};
    use xcall::rollback_ticket::{Self};
    use xcall::network_address::{Self};
    use xcall::xcall_state::{Self, Storage, IDCap};


    public struct REGISTER_WITNESS has drop, store {}

    public struct WitnessCarrier has key { id: UID, witness: REGISTER_WITNESS }

    // === Errors ===

    const EAmountLessThanZero: u64 = 1;

    const EWrongVersion: u64 = 2;

    const ENotUpgrade: u64 = 3;

    const EBalanceExceeded: u64 = 4;

    const UnknownMessageType: u64 = 5;

    const ETypeArgumentMismatch: u64 = 6;

    /// Constants
    const CURRENT_VERSION: u64 = 1;

    const DEPOSIT_NAME: vector<u8> = b"Deposit";

    const WITHDRAW_TO_NAME: vector<u8> = b"WithdrawTo";

    const DEPOSIT_REVERT_NAME: vector<u8> = b"DepositRevert";
    
    const WITHDRAW_NATIVE_TO_NAME: vector<u8> = b"WithdrawNativeTo";

    public struct AdminCap has key{
        id: UID 
    }

    public struct ContractHolding has key, store{
        id: UID,
        contract_holding: Balance<TEST_COIN>,
    }

    public struct Config has key, store {
        id: UID,
        icon_hub: String,
        version: u64,
        holding: ContractHolding,
        id_cap: IDCap,
        xcall_id: ID,
        sources: vector<String>,
        destinations: vector<String>,
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

    // ====== Entrypoints =======

    // === Public Actions ===

    entry fun configure(
        _: &AdminCap,
        storage: &Storage, 
        witness_carrier: WitnessCarrier, 
        version: u64,
        icon_hub: String,
        sources: vector<String>,
        destinations: vector<String>,
        ctx: &mut TxContext 
    ){
        let w = get_witness(witness_carrier);
        let id_cap =   xcall::register_dapp(storage, w, ctx);
        let xcall_id = xcall_state::get_id_cap_xcall(&id_cap);

        let contract_holding = ContractHolding {
            id: object::new(ctx),
            contract_holding: balance::zero<TEST_COIN>()
        };

        let config = Config{
            id: object::new(ctx),
            version,
            holding: contract_holding,
            icon_hub,
            id_cap,
            xcall_id,
            sources,
            destinations,
        };
        transfer::share_object(config);
    }

    public entry fun cross_transfer(
        config: &mut Config,
        x_ctx:&mut Storage,
        fee: Coin<SUI>,
        token: Coin<TEST_COIN>,
        to: String,
        data: Option<vector<u8>>,
        holding: &mut ContractHolding,
        ctx: &mut TxContext,
    ){
        validate_version(config);
        let message_data = option::get_with_default(&data, b"");
        let amount = coin::value(&token);
        assert!(amount > 0, EAmountLessThanZero);
        let sender = ctx.sender();
        let balance = coin::into_balance(token);
        balance::join(&mut holding.contract_holding, balance);
        let from_address = address_to_hex_string(&sender);
        let token_address = string::from_ascii(*type_name::borrow_string(&type_name::get<TEST_COIN>()));
        let x_message = deposit::wrap_deposit(
            token_address,
            from_address,
            to,
            amount,
            message_data
        );
        let x_rollback  = deposit_revert::wrap_deposit_revert(token_address, sender, amount);
        let x_encoded_msg = deposit::encode(&x_message, DEPOSIT_NAME);
        let rollback = deposit_revert::encode(&x_rollback, DEPOSIT_REVERT_NAME);
        let envelope = envelope::wrap_call_message_rollback(x_encoded_msg, rollback, config.sources, config.destinations);
        xcall::send_call(x_ctx, fee, get_idcap(config), config.icon_hub, envelope::encode(&envelope), ctx);
    }

    public entry fun execute_call(
        config: &Config,
        x_ctx:&mut Storage,
        fee: Coin<SUI>,
        request_id:u128,
        data: vector<u8>,
        holding: &mut ContractHolding,
        ctx: &mut TxContext,
    ){
        validate_version(config);
        let ticket = xcall::execute_call(x_ctx, get_idcap(config), request_id, data, ctx);
        let msg = execute_ticket::message(&ticket);
        let from = execute_ticket::from(&ticket);
        let protocols = execute_ticket::protocols(&ticket);

        let verified = verify_protocols(config, protocols);
        let method: vector<u8> = deposit::get_method(&msg);

        let token_type = string::from_ascii(*type_name::borrow_string(&type_name::get<TEST_COIN>()));
        let message_token_type = get_token_type(&msg);

        assert!(
            token_type == message_token_type,
            ETypeArgumentMismatch
        );

        if(verified && (method == WITHDRAW_TO_NAME || method == WITHDRAW_NATIVE_TO_NAME) && from == network_address::from_string(config.icon_hub)){
            let message = withdraw_to::decode(&msg);
            let string_to = withdraw_to::to(&message);
            let to  = network_address::addr(&network_address::from_string(string_to));
            let amount = translate_incoming_amount(withdraw_to::amount(&message) as u128);
            let val =    balance::value(&holding.contract_holding);
            assert!(amount <= val, EBalanceExceeded);
            let balance = balance::split(&mut holding.contract_holding, amount);
            transfer::public_transfer(coin::from_balance(balance, ctx), address_from_hex_string(&to));
            xcall::execute_call_result(x_ctx, ticket, true, fee, ctx);
        }else {
            xcall::execute_call_result(x_ctx, ticket, false, fee, ctx);
        }
    }

    entry fun execute_force_rollback(config: &Config, _: &AdminCap, xcall:&mut Storage, fee:Coin<SUI>, request_id:u128, data:vector<u8>, ctx:&mut TxContext){
        validate_version(config);
        let ticket = xcall::execute_call(xcall, get_idcap(config), request_id, data, ctx);
        xcall::execute_call_result(xcall,ticket,false,fee,ctx);
    }

    entry fun execute_rollback(config: &Config, xcall: &mut Storage, holding: &mut ContractHolding, sn: u128, ctx:&mut TxContext){
        validate_version(config);
        let ticket = xcall::execute_rollback(xcall, get_idcap(config), sn, ctx);
        let msg = rollback_ticket::rollback(&ticket);
        let method: vector<u8> = deposit::get_method(&msg);
        assert!(
            method == DEPOSIT_REVERT_NAME,
            UnknownMessageType
        );

        let token_type = string::from_ascii(*type_name::borrow_string(&type_name::get<TEST_COIN>()));
        let message_token_type = deposit::get_token_type(&msg);
        if(token_type == message_token_type){
            let total_balance = balance::value(&holding.contract_holding);
            let message = deposit_revert::decode(&msg);
            let to = deposit_revert::to(&message);
            let amount = deposit_revert::amount(&message);
            assert!(amount <= total_balance, EBalanceExceeded);
            let transfer_value = balance::split(&mut holding.contract_holding, amount);
            transfer::public_transfer(coin::from_balance(transfer_value, ctx), to);
        };
        xcall::execute_rollback_result(xcall,ticket,true)
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

    // ======== Private actions ========
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

    fun get_witness(carrier: WitnessCarrier): REGISTER_WITNESS {
        let WitnessCarrier { id, witness } = carrier;
        id.delete();
        witness
    }

    fun translate_incoming_amount(amount: u128): u64{
        (amount / (math::pow(10,9) as u128)) as u64
    }

    fun validate_version(self: &Config){
        assert!(self.version == CURRENT_VERSION, EWrongVersion);
    }
}


// home_spoke :-  spoke_manager