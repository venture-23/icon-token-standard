#[test_only]
module spoke_token::spoke_token_tests {
    use std::string::{Self, String};
    use sui::test_scenario::{Self, next_tx, ctx, Scenario};
    use sui::coin::{Self};
    use sui::sui::SUI;
    use sui::math;
    use sui::hex;

    use xcall::xcall_state::{Self, Storage as XCallState, ConnCap};
    use xcall::main::{Self as xcall, init_xcall_state};
    use xcall::cs_message::{Self};
    use xcall::message_request::{Self};
    use xcall::network_address::{Self};
    use xcall::message_result::{Self};
    

    use spoke_token::spoke_token::{Self, Config, AdminCap, WitnessCarrier, get_treasury_cap_for_testing, cross_transfer};
    use balanced::cross_transfer::{wrap_cross_transfer, encode};
    use balanced::xcall_manager::{Self, Config as XcallManagerConfig, WitnessCarrier as XcallManagerWitnessCarrier};
    

    const ADMIN: address = @0xBABE;

    const TO: vector<u8> = b"sui/address";
    
    const ICON_BnUSD: vector<u8> = b"icon/hx734";

    const TO_ADDRESS: vector<u8>  = b"sui-test/0000000000000000000000000000000000000000000000000000000000001234";

    const FROM_ADDRESS: vector<u8>  = b"000000000000000000000000000000000000000000000000000000000000123d";


    const ENotImplemented: u64 = 0;

    #[test_only]
    // #[test]
    public fun setup(admin: address) : Scenario {
        let mut scenario = test_scenario::begin(admin);
        spoke_token::init_test(scenario.ctx());
        scenario.next_tx(admin);
        let admin_cap = scenario.take_from_sender<AdminCap>();
        let carrier = scenario.take_from_sender<WitnessCarrier>();
        scenario = init_xcall_state(admin, scenario);
        scenario.next_tx(admin);

        xcall_manager::init_test(scenario.ctx());
        scenario.next_tx(admin);

        let manager_admin_cap = scenario.take_from_sender<xcall_manager::AdminCap>();
        let sources = vector[string::utf8(b"centralized-1")];
        let destinations = vector[string::utf8(b"icon/hx234"), string::utf8(b"icon/hx334")];
        let xm_carrier = scenario.take_from_sender<XcallManagerWitnessCarrier>();
        let xcall_state= scenario.take_shared<XCallState>();
        xcall_manager::configure(&manager_admin_cap, &xcall_state, xm_carrier, string::utf8(ICON_BnUSD),  sources, destinations, 2, scenario.ctx());
        scenario.next_tx(admin);
        let xcall_manager_config: XcallManagerConfig = scenario.take_shared<XcallManagerConfig>();
        let treasury_cap = coin::create_treasury_cap_for_testing(scenario.ctx());
        spoke_token::configure(&admin_cap, &xcall_state, carrier, 1, string::utf8(ICON_BnUSD), &xcall_manager_config, treasury_cap, scenario.ctx());
        scenario.next_tx(admin);
        test_scenario::return_shared<XCallState>(xcall_state);
        scenario.return_to_sender(admin_cap);
        test_scenario::return_shared<XcallManagerConfig>(xcall_manager_config);
        scenario.return_to_sender(manager_admin_cap);
        scenario
    }

    #[test_only]
    fun setup_connection(mut scenario: Scenario, admin:address): Scenario {
        let mut storage = scenario.take_shared<XCallState>();
        let admin_cap = scenario.take_from_sender<xcall_state::AdminCap>();
        xcall::register_connection_admin(&mut storage, &admin_cap, string::utf8(b"centralized-1"), admin, scenario.ctx());
        test_scenario::return_shared(storage);
        test_scenario::return_to_sender(&scenario, admin_cap);
        scenario.next_tx(admin);
        scenario
    }

    #[test_only]
    fun id_to_hex_string(id:&ID): String {
        let bytes = object::id_to_bytes(id);
        let hex_bytes = hex::encode(bytes);
        let mut prefix = string::utf8(b"0x");
        prefix.append(string::utf8(hex_bytes));
        prefix
    }

    #[test]
    fun cross_transfer_test() {
        let mut scenario = setup(ADMIN);
        scenario.next_tx(ADMIN);
        scenario = setup_connection(scenario, ADMIN);
       
        let mut config = scenario.take_shared<Config>();
        let fee_amount = math::pow(10, 9 + 4);
        let token_amount = math::pow(10, 18);
        let fee = coin::mint_for_testing<SUI>(fee_amount, scenario.ctx());
        let treasury_cap = get_treasury_cap_for_testing(&mut config);
        let deposited = coin::mint(treasury_cap, token_amount, scenario.ctx());

        let mut xcall_state= scenario.take_shared<XCallState>();
        let xcall_manager_config: xcall_manager::Config  = scenario.take_shared<xcall_manager::Config>();
        cross_transfer(&mut config, &mut xcall_state, &xcall_manager_config, fee, deposited, TO.to_string(), option::none(), scenario.ctx());
        test_scenario::return_shared(config);
        test_scenario::return_shared(xcall_state);
        test_scenario::return_shared(xcall_manager_config);
        scenario.end();
    }

    #[test]
    fun execute_call_test() {
        let mut scenario = setup(ADMIN);
        scenario.next_tx(ADMIN);

        let token_amount = math::pow(10, 18) as u128;
        let message = wrap_cross_transfer(string::utf8(FROM_ADDRESS),  string::utf8(TO_ADDRESS), token_amount, b"");
        let data = encode(&message, b"xCrossTransfer");
        
        scenario = setup_connection( scenario, ADMIN);
        scenario.next_tx(ADMIN);
        let mut xcall_state = scenario.take_shared<XCallState>();
        let conn_cap = test_scenario::take_from_sender<ConnCap>(&scenario);

        let mut config = scenario.take_shared<Config>();

        let sources = vector[string::utf8(b"centralized-1")];
        let sui_dapp = id_to_hex_string(&xcall_state::get_id_cap_id(spoke_token::get_idcap(&config)));
        let icon_dapp = network_address::create(string::utf8(b"icon"), string::utf8(b"hx534"));
        let from_nid = string::utf8(b"icon");
        let request = message_request::create(icon_dapp, sui_dapp, 1, 1, data, sources);
        let message = cs_message::encode(&cs_message::new(cs_message::request_code(), message_request::encode(&request)));
        xcall::handle_message(&mut xcall_state, &conn_cap, from_nid, message, scenario.ctx());

        scenario.next_tx(ADMIN);
        
        let fee_amount = math::pow(10, 9 + 4);
        let fee = coin::mint_for_testing<SUI>(fee_amount, scenario.ctx());
        let xcall_manager_config: xcall_manager::Config  = scenario.take_shared<xcall_manager::Config>();
        spoke_token::execute_call(&mut config, &xcall_manager_config, &mut xcall_state, fee, 1, data, scenario.ctx());

        test_scenario::return_shared(config);
        test_scenario::return_shared(xcall_state);
        test_scenario::return_shared(xcall_manager_config);
        scenario.return_to_sender(conn_cap);
        
        scenario.end();
    }

    #[test]
    fun execute_rollback_test() {
        let mut scenario = setup(ADMIN);
        scenario.next_tx(ADMIN);

        let token_amount = math::pow(10, 18);
        scenario = setup_connection( scenario, ADMIN);
        let mut xcall_state = scenario.take_shared<XCallState>();
        let conn_cap = test_scenario::take_from_sender<ConnCap>(&scenario);
        let mut config = scenario.take_shared<Config>();

        let from_nid = string::utf8(b"icon");
        let response = message_result::create(1, message_result::failure(),b"");
        let message = cs_message::encode(&cs_message::new(cs_message::result_code(), message_result::encode(&response)));
        scenario.next_tx(ADMIN);
        
        let fee_amount = math::pow(10, 9 + 4);
        let fee = coin::mint_for_testing<SUI>(fee_amount, scenario.ctx());
        let treasury_cap = get_treasury_cap_for_testing(&mut config);
        let deposited = coin::mint(treasury_cap, token_amount, scenario.ctx());
        let xcall_manager_config: xcall_manager::Config  = scenario.take_shared<xcall_manager::Config>();
        cross_transfer(&mut config, &mut xcall_state,  &xcall_manager_config, fee, deposited, TO.to_string(), option::none(), scenario.ctx());
        xcall::handle_message(&mut xcall_state, &conn_cap, from_nid, message, scenario.ctx());       
        spoke_token::execute_rollback(&mut config,  &mut xcall_state, 1, scenario.ctx());
        test_scenario::return_shared(config);
        test_scenario::return_shared(xcall_state);
        test_scenario::return_shared(xcall_manager_config);
        scenario.return_to_sender(conn_cap);
        scenario.end();
    }

    #[test]
    fun test_spoke_token() {
        // pass
    }

    #[test, expected_failure(abort_code = ::spoke_token::spoke_token_tests::ENotImplemented)]
    fun test_spoke_token_fail() {
        abort ENotImplemented
    }
}
