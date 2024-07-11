module spoke_token::manager{
    use std::string::{String};
    
    use sui::bag::{Bag};
    use sui::package::UpgradeCap;

    use xcall::xcall_state::{Self, Storage, IDCap};

    const CURRENT_VERSION: u64 = 1;

    const EWrongVersion: u64 = 0;
    const ENotUpgrade: u64 = 1;    

    public struct AdminCap has key {
        id: UID
    }

    public struct Config has key, store{
        id: UID,
        version: u64,
        id_cap: IDCap,
        icon_governance: String,
        source: vector<String>,
        destination: vector<String>,
        proposed_protocol_to_remove: String,
        whitelist_actions: Bag
    }

    fun validate_version(self: &Config){
        assert!(self.version == CURRENT_VERSION, EWrongVersion);
    }


    entry fun migrate(_: &UpgradeCap, self: &mut Config){
        assert!(get_version(self) < CURRENT_VERSION, ENotUpgrade);
        set_version(self, CURRENT_VERSION);
    }

    fun set_version(config: &mut Config, version: u64){
        config.version = version
    }

    // ? why are these protocals
    public fun get_protocals(config: &Config):(vector<String>, vector<String>){
        validate_version(config);
        (config.source, config.destination)
    }

    public fun get_version(config: &Config): u64{
        config.version
    }

    public fun verify_protocols(config: &Config, protocols: vector<String>): bool{
        validate_version(config);
        verify_protocols_unordered(config.source, protocols)
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