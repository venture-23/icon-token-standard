/// Module for managing cross-chain transfers, including locking balances, 
/// handling configuration, and executing cross-chain transfers and rollbacks.
module spoke_token::spoke_token {
    use std::string::String;
    use sui::coin::{Self, Coin, TreasuryCap};
    use sui::package::UpgradeCap;
    use sui::sui::SUI;
    
    use balanced::balanced_utils::{address_to_hex_string, address_from_hex_string, create_execute_params, ExecuteParams};
    use balanced::cross_transfer::{Self, wrap_cross_transfer, XCrossTransfer};
    use balanced::cross_transfer_revert::{Self, XCrossTransferRevert};
    use balanced::xcall_manager::{Self, Config as XcallManagerConfig};
    use test_coin::test_coin::{TEST_COIN};

    use xcall::{main as xcall, xcall_utils};
    use xcall::execute_ticket::{Self};
    use xcall::envelope::{Self};
    use xcall::rollback_ticket::{Self};
    use xcall::network_address::{Self};
    use xcall::xcall_state::{Self, Storage, IDCap};

    // === Errors ===

    /// Error: The amount specified is less than zero.
    const EAmountLessThanZero: u64 = 1;

    /// Error: The configuration version is incorrect.
    const EWrongVersion: u64 = 2;

    /// Error: The current configuration is not eligible for an upgrade.
    const ENotUpgrade: u64 = 3;

    /// Error: The message type is unknown or unrecognized.
    const UnknownMessageType: u64 = 4;

    // === Constants ===
    
    /// The current version of the configuration.
    const CURRENT_VERSION: u64 = 1;

    /// Identifier for cross-transfer messages.
    const CROSS_TRANSFER: vector<u8> = b"xCrossTransfer";
    
    /// Identifier for cross-transfer revert messages.
    const CROSS_TRANSFER_REVERT: vector<u8> = b"xCrossTransferTevert";

    /// A struct representing a witness registration.
    public struct REGISTER_WITNESS has drop, store {}

    /// A struct for carrying a witness registration.
    public struct WitnessCarrier has key { id: UID, witness: REGISTER_WITNESS }

    /// Admin capability required for performing sensitive operations.
    public struct AdminCap has key{
        id: UID 
    }

    /// A struct that represents the configuration of the cross-chain system
    public struct Config has key, store {
        /// Unique identifier for the Config object
        id: UID,
        /// Version number for upgrade validation
        version: u64,
        /// Token representing the icon for cross-chain calls
        icon_token: String,
        /// Capability for interacting with the ID system (xcall)
        id_cap: IDCap,
        /// Identifier for the cross-chain call system
        xcall_manager_id: ID, 
        /// Identifier for the cross-chain call itself
        xcall_id: ID,
        /// Capability to manage treasury for the specific token (TEST_COIN)
        treasury_cap: TreasuryCap<TEST_COIN>,
    }


    /// Initializes the cross-chain admin and witness carrier with default values
    fun init(ctx: &mut TxContext) {
        // Transfer the AdminCap object to the sender
        transfer::transfer(AdminCap{
            id: object::new(ctx),
        }, ctx.sender());

        // Transfer the WitnessCarrier with a default witness to the sender
        transfer::transfer(WitnessCarrier{
            id: object::new(ctx), 
            witness: REGISTER_WITNESS{},
        }, ctx.sender());
    }   

    /// Configures the cross-chain system by setting key parameters like version, witness, etc.
    /// 
    /// -`AdminCap`: Admin capability to authorize configuration
    /// -`storage`: Storage reference for registering the dApp
    /// -`witness_carrier`: Witness carrier object to get witness
    /// -`version`: Version number of the configuration
    /// -`icon_token`: Icon token representing cross-chain configuration
    /// -`xcall_manager_config`: Manager configuration for cross-chain call
    /// -`treasury_cap`: Treasury capability for the token
    entry fun configure(
        _: &AdminCap,
        storage: &Storage, 
        witness_carrier: WitnessCarrier, 
        version: u64,
        icon_token: String,
        xcall_manager_config: &XcallManagerConfig,
        treasury_cap: TreasuryCap<TEST_COIN>,
        ctx: &mut TxContext,
    ){
        let w = get_witness(witness_carrier);
        let id_cap =   xcall::register_dapp(storage, w, ctx);
        let xcall_id = xcall_state::get_id_cap_xcall(&id_cap);
        let xcall_manager_id = xcall_manager::get_id(xcall_manager_config);
        
        transfer::share_object(Config{
            id: object::new(ctx),
            version,
            icon_token,
            id_cap,
            xcall_id,
            xcall_manager_id,
            treasury_cap,
        });
    }

    /// Handles a cross-chain transfer, locking the transferred amount and sending a wrapped message.
    ///
    /// - `config`: The configuration object containing the state.
    /// - `xcall_manager_config`: The configuration object containing the state of xcall manager.
    /// - `x_ctx`: The storage object used for managing state.
    /// - `fee`: The fee to be paid for the transfer.
    /// - `token`: The token being transferred.
    /// - `to`: The destination address.
    /// - `data`: Optional data to be included with the transfer 
    entry fun cross_transfer(
        config: &mut Config,
        x_ctx: &mut Storage,
        xcall_manager_config: &XcallManagerConfig,
        fee: Coin<SUI>,
        token: Coin<TEST_COIN>,
        to: String,
        data: Option<vector<u8>>,
        ctx: &mut TxContext,
    ){
        validate_version(config);
        let message_data = option::get_with_default(&data, b"");
        let amount = coin::value(&token);
        // Ensures that the provided `amount` is greater than zero before proceeding.
        assert!(amount > 0, EAmountLessThanZero);
        coin::burn(get_treasury_cap_mut(config), token);

        let sender = ctx.sender();
        let from_address = address_to_hex_string(&sender);

        let x_message = wrap_cross_transfer(
            from_address,
            to,
            translate_outgoing_amount(amount),
            message_data
        );
        let (sources, destinations) = xcall_manager::get_protocals(xcall_manager_config);

        let x_rollback  = cross_transfer_revert::wrap_cross_transfer_revert(sender, amount);
        let x_encoded_msg = cross_transfer::encode(&x_message, CROSS_TRANSFER);
        let rollback = cross_transfer_revert::encode(&x_rollback, CROSS_TRANSFER_REVERT);
        let envelope = envelope::wrap_call_message_rollback(x_encoded_msg, rollback, sources, destinations);
        xcall::send_call(x_ctx, fee, get_idcap(config), config.icon_token, envelope::encode(&envelope), ctx);
    }

    /// Executes a call message, verifying the protocols and releasing locked balances if valid.
    ///
    /// - `config`: The configuration object containing the state.
    /// - `xcall_manager_config`: The configuration object containing the state of xcall manager.
    /// - `x_ctx`: The storage object used for managing state.
    /// - `fee`: The fee to be paid for executing the call.
    /// - `request_id`: The ID of the request being executed.
    /// - `data`: The data associated with the call.
    entry fun execute_call(
        config: &mut Config,
        xcall_manager_config: &XcallManagerConfig,
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

        let verified = xcall_manager::verify_protocols(xcall_manager_config, &protocols);
        let method: vector<u8> = cross_transfer::get_method(&msg);

        if( verified && method == CROSS_TRANSFER && from == network_address::from_string(config.icon_token)){
            let message: XCrossTransfer = cross_transfer::decode(&msg);
            let string_to = cross_transfer::to(&message);
            let to  = network_address::addr(&network_address::from_string(string_to));
            let amount = translate_incoming_amount(cross_transfer::value(&message));
            let coins = coin::mint(get_treasury_cap_mut(config), amount, ctx);
            transfer::public_transfer(coins, address_from_hex_string(&to),);
            xcall::execute_call_result(x_ctx, ticket, true, fee, ctx);
        }else {
            xcall::execute_call_result(x_ctx, ticket, false, fee, ctx);
        }
    }

    /// Executes a rollback of a cross-chain transfer, releasing locked balances back to the sender.
    ///
    /// - `config`: The configuration object containing the state.
    /// - `xcall`: The storage object used for managing state.
    /// - `sn`: The sequence number of the rollback request.
    entry fun execute_rollback(
        config: &mut Config, 
        xcall: &mut Storage,
        sn: u128, 
        ctx:&mut TxContext
    ){
        validate_version(config);
        let ticket = xcall::execute_rollback(xcall, get_idcap(config), sn, ctx);
        let msg = rollback_ticket::rollback(&ticket);
        let method: vector<u8> = cross_transfer::get_method(&msg);
        
        // Ensures that the provided `method` is the expected cross-transfer revert method.
        assert!(method == CROSS_TRANSFER_REVERT, UnknownMessageType);

        let message: XCrossTransferRevert = cross_transfer_revert::decode(&msg);
        let to = cross_transfer_revert::to(&message);
        let amount: u64 = cross_transfer_revert::value(&message);
        let coins = coin::mint(get_treasury_cap_mut(config), amount, ctx);
        transfer::public_transfer(coins, to);
        xcall::execute_rollback_result(xcall,ticket,true)
    }

    /// Forces a rollback execution without releasing locked balances. 
    ///
    /// Typically used in error recovery scenarios.
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

    /// Migrates the configuration to a new version, applying any necessary updates.
    ///
    /// - `self`: The configuration object to be migrated.
    /// - `UpgradeCap`: The upgrade capability required to perform this operation.
    entry fun migrate(self: &mut Config, _: &UpgradeCap){
        // Ensures that the version of the current object is lower than the `CURRENT_VERSION`
        assert!(get_version(self) < CURRENT_VERSION, ENotUpgrade);
        set_version(self, CURRENT_VERSION);
    }

    /// Updates the hub token used for cross-chain transactions.
    ///
    /// - `config`: The configuration object to be updated.
    /// - `icon_token`: The new token identifier for the hub.
    entry fun set_token(_:&AdminCap, config: &mut Config, icon_token: String){
        validate_version(config);
        config.icon_token = icon_token;
    }

    entry fun get_execute_params(config: &Config, _msg:vector<u8>): ExecuteParams{
        let type_args:vector<String> = vector::empty();

        let mut result:vector<String> = vector::empty();
        result.push_back(xcall_utils::id_to_hex_string(&get_config_id(config)));
        result.push_back(xcall_utils::id_to_hex_string(&get_xcall_manager_id(config)));
        result.push_back(xcall_utils::id_to_hex_string(&get_xcall_id(config)));
        result.push_back(b"coin".to_string());  
        result.push_back(b"request_id".to_string());
        result.push_back(b"data".to_string());        
        create_execute_params(type_args, result)
    }

    entry fun get_rollback_params(config: &Config, _msg:vector<u8>): ExecuteParams{
        let type_args:vector<String> = vector::empty();

        let mut result:vector<String> = vector::empty();
        result.push_back(xcall_utils::id_to_hex_string(&get_config_id(config)));
        result.push_back(xcall_utils::id_to_hex_string(&get_xcall_id(config)));
        result.push_back(b"sn".to_string());        
        create_execute_params(type_args, result)
    }

    /// Getters

    /// Retrieves the cross-call ID from the configuration. 
    public fun get_xcall_id(config: &Config): ID{
        validate_version(config);
        config.xcall_id
    }

    /// Retrieves the version number from the configuration.
    public fun get_version(config: &Config): u64{
        config.version
    }

    /// Returns the ID of the `xcall_manager` from the given configuration.
    ///
    /// # Arguments:
    /// - `config`: A reference to the `Config` struct, which holds various system configurations.
    ///
    /// # Returns:
    /// - The `ID` of the `xcall_manager` stored in the provided `Config`.
    public fun get_xcall_manager_id(config: &Config): ID {
        config.xcall_manager_id
    }

    /// Returns the ID of the given configuration, after validating its version.
    ///
    /// # Arguments:
    /// - `config`: A reference to the `Config` struct that contains the ID and version information.
    ///
    /// # Returns:
    /// - The `ID` of the provided `Config` after validating its version.
    ///
    /// # Note:
    /// - The function calls `validate_version` to ensure that the configuration is valid before returning the ID.
    public fun get_config_id(config: &Config): ID {
        validate_version(config);
        config.id.to_inner()
    }


    // ==== Private ====

    /// Private method to retrieve the ID capability from the configuration.
    fun get_idcap(config: &Config): &IDCap{
        validate_version(config);
        &config.id_cap
    }

    /// Retrieves a mutable reference to the locked balance within the configuration.
    fun get_treasury_cap_mut(config: &mut Config): &mut TreasuryCap<TEST_COIN>{
        &mut config.treasury_cap
    }

    /// Extracts the witness from the `WitnessCarrier` and deletes the carrier object.
    fun get_witness(carrier: WitnessCarrier): REGISTER_WITNESS {
        let WitnessCarrier { id, witness } = carrier;
        id.delete();
        witness
    }  

    /// Updates the configuration's version number.
    fun set_version(config: &mut Config, version: u64){
        config.version = version
    }
    
    /// Translates an outgoing amount from u64 to u128.
    fun translate_outgoing_amount(amount: u64): u128 {
        let multiplier = std::u64::pow(10, 9) as u128;
        (amount as u128) * multiplier 
    }

    /// Translates an imcoming amount from u128 to u64.
    fun translate_incoming_amount(amount: u128): u64{
        (amount / (std::u64::pow(10,9) as u128)) as u64
    }

    /// Validate tge versioning of Config
    fun validate_version(self: &Config){
        assert!(self.version == CURRENT_VERSION, EWrongVersion);
    }

    /// Validate tge versioning of Config
    #[test_only]
    public fun get_treasury_cap_for_testing(config: &mut Config): &mut TreasuryCap<TEST_COIN>{
        &mut config.treasury_cap
    }

    /// Initialize for test scenario
    #[test_only]
    public fun init_test(ctx: &mut TxContext) {
        init(ctx)
    }
}