use starknet::class_hash::ClassHash;

#[starknet::interface]
trait IEthereumMinter<TContractState> {
    fn get_l1_minter_address(self: @TContractState) -> felt252;
    fn set_l1_minter_address(ref self: TContractState, l1_address: felt252);
    fn mint_value(
        ref self: TContractState,
        from_address: felt252,
        _user_address: u256,
        value: u256,
        amount: u256
    );
    fn claim(ref self: TContractState, user_address: felt252);
    fn upgrade(ref self: TContractState, impl_hash: ClassHash);
}
