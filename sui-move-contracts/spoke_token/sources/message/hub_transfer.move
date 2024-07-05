#[allow(unused_field,unused_use,unused_const,unused_mut_parameter,unused_variable,unused_assignment)]
module spoke_token::hub_transfer {
    use std::string::{Self, String};
    use std::option::{some, none};
    use sui_rlp::encoder;
    use sui_rlp::decoder;

    public struct XHubTransfer has drop{
        from: String, 
        to: String,
        value: u128,
        data: vector<u8>
    }

    public fun encode(req:&XHubTransfer, method: vector<u8>):vector<u8>{
        let mut list=vector::empty<vector<u8>>();
        vector::push_back(&mut list, encoder::encode(&method));
        vector::push_back(&mut list,encoder::encode_string(&req.from));
        vector::push_back(&mut list,encoder::encode_string(&req.to));
        vector::push_back(&mut list,encoder::encode_u128(req.value));
        vector::push_back(&mut list,encoder::encode(&req.data));

        let encoded=encoder::encode_list(&list,false);
        encoded
    }

    public fun decode(bytes:&vector<u8>): XHubTransfer {
        let decoded=decoder::decode_list(bytes);
        let from = decoder::decode_string(vector::borrow(&decoded, 1));
        let to = decoder::decode_string(vector::borrow(&decoded, 2));
        let value = decoder::decode_u128(vector::borrow(&decoded, 3));
        let data = *vector::borrow(&decoded, 4);
        let req= XHubTransfer {
            from,
            to,
            value,
            data
        };
        req
    }

     public fun wrap_hub_transfer(from: String, to: String, value: u128, data: vector<u8>): XHubTransfer {
        let hub_transfer = XHubTransfer {
            from: from,
            to: to,
            value: value,
            data: data

        };
        hub_transfer
    }

    public fun get_method(bytes:&vector<u8>): vector<u8> {
        let decoded=decoder::decode_list(bytes);
        *vector::borrow(&decoded, 0)
    }

    public fun from(hub_transfer: &XHubTransfer): String{
        hub_transfer.from
    }

    public fun to(hub_transfer: &XHubTransfer): String{
        hub_transfer.to
    }

    public fun value(hub_transfer: &XHubTransfer): u128{
        hub_transfer.value
    }

    public fun data(hub_transfer: &XHubTransfer): vector<u8>{
        hub_transfer.data
    }


    #[test]
    fun test_xtransfer_encode_decode(){
        let from = string::utf8(b"sui/from");
        let to = string::utf8(b"sui/to");
        let transfer = wrap_hub_transfer(from, to, 90, b"");
        let data: vector<u8> = encode(&transfer, b"test");
        let result = decode(&data);
        
        assert!(result.from == from, 0x01);
        assert!(result.to == to, 0x01);
        assert!(result.value == 90, 0x01);
        assert!(result.data == b"", 0x01);
    }

}