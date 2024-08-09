module spoke_manager::spoke_manager_utils {

    use std::string::{Self, String};
    use sui::bcs::{Self};
    use sui::hex::{Self};
    use sui_rlp::decoder;

    public fun address_to_hex_string(address:&address): String {
        let bytes = bcs::to_bytes(address);
        let hex_bytes = hex::encode(bytes);
        string::utf8(hex_bytes)
    }

    public fun address_from_hex_string(str: &String): address {
        let mut modified_str = str;
        if(string::length(str) == 66 ){
            modified_str = &str.substring(2, 66);
        };
        let bytes = modified_str.as_bytes();
        let hex_bytes = hex::decode(*bytes);
        bcs::peel_address(&mut bcs::new(hex_bytes))
    }

    public fun get_token_type(bytes:&vector<u8>): String{
        let decoded=decoder::decode_list(bytes);
        let token_address = decoder::decode_string(vector::borrow(&decoded, 1));
        token_address
    }

    #[test]
    fun test_address_conversion(){
        let a = @0xef9d29652f9b26481bfb76dd918905769fab14f1ec3cb8c04d8847fd5b223d3b;
        let a_string = address_to_hex_string(&a);
        let result1 = address_from_hex_string(&b"ef9d29652f9b26481bfb76dd918905769fab14f1ec3cb8c04d8847fd5b223d3b".to_string());
        let result = address_from_hex_string(&b"0xef9d29652f9b26481bfb76dd918905769fab14f1ec3cb8c04d8847fd5b223d3b".to_string());
        assert!(a == result, 0x01);
        assert!(a == result1, 0x01);
    }
} 
