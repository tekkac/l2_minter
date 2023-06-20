use starknet::ContractAddress;

#[starknet::interface]
trait IERC3525<TContractState> {
    #[view]
    fn name(self: @TContractState) -> felt252;

    #[view]
    fn symbol(self: @TContractState) -> felt252;

    #[external]
    fn mintNew(ref self: TContractState, to: felt252, slot: u256, value: u256) -> u256;
}
