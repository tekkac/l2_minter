use core::traits::TryInto;
#[starknet::contract]
mod EthereumMinter {
    // Library Imports
    use starknet::class_hash::ClassHash;
    use zeroable::Zeroable;
    use starknet::ContractAddress;
    use starknet::get_block_timestamp;
    use core::option::OptionTrait;
    use result::ResultTrait;
    use traits::{Into, TryInto};

    use ethereum_minter::helpers::booking_storage::StorageAccessBooking;
    use ethereum_minter::interfaces::l1_minter::IEthereumMinter;
    use ethereum_minter::interfaces::erc3525::{IERC3525Dispatcher, IERC3525DispatcherTrait};

    #[derive(starknet::StorageAccess, Drop, Copy, Serde)]
    struct Booking {
        value: u256,
        amount: u256,
        status: u8,
    }

    #[derive(starknet::StorageAccess, Drop, Copy, Serde)]
    enum MintStatus {
        Failed: (),
        Minted: (),
    }

    #[storage]
    struct Storage {
        _l1_minter_address: felt252,
        _l1_mint_counts: LegacyMap::<felt252, u32>,
        // booked_values: (user_address, user_mint_index) -> (value, amount, status)
        _booked_values: LegacyMap::<(felt252, u32), u8>,
        _projects_contract: IERC3525Dispatcher,
        _slot: u256,
        _unit_price: u256,
        _max_supply: u256,
        _max_value_per_tx: u256,
        _min_value_per_tx: u256,
        _current_max_supply: u256,
    }

    // Events
    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        Upgraded: Upgraded,
        Buy: Buy,
    }

    #[derive(Drop, starknet::Event)]
    struct Upgraded {
        implementation: ClassHash
    }

    #[derive(Drop, starknet::Event)]
    struct Buy {
        address: ContractAddress,
        value: u256,
        time: u64,
    }


    // Methods
    #[constructor]
    fn init(
        ref self: ContractState,
        projects_contract: ContractAddress,
        slot: u256,
        unit_price: u256,
        max_supply: u256,
        max_value_per_tx: u256,
        min_value_per_tx: u256,
    ) {
        assert(!projects_contract.is_zero(), 'Projects contract cannot be 0');
        assert(unit_price > 0, 'Unit price must be positive');
        assert(max_supply > 0, 'Max supply must be positive');
        assert(max_value_per_tx > 0, 'Max value per tx <= 0');
        assert(min_value_per_tx > 0, 'Min value per tx <= 0');
        assert(max_value_per_tx >= min_value_per_tx, 'Max < min per tx');
        assert(max_supply >= max_value_per_tx, 'Max supply < max value per tx');

        assert(slot != 0, 'Slot cannot be zero');

        self._projects_contract.write(IERC3525Dispatcher { contract_address: projects_contract });
        self._slot.write(slot);
        self._unit_price.write(unit_price);
        self._max_supply.write(max_supply);
        self._max_value_per_tx.write(max_value_per_tx);
        self._min_value_per_tx.write(min_value_per_tx);
        self._current_max_supply.write(max_supply);
    }


    #[external(v0)]
    impl CounterContract of IEthereumMinter<ContractState> {
        fn get_l1_minter_address(self: @ContractState) -> felt252 {
            self._l1_minter_address.read()
        }

        //#[l1_handler]
        fn mint_value(
            ref self: ContractState,
            from_address: felt252,
            _user_address: u256,
            value: u256,
            amount: u256
        ) {
            assert(from_address == self._l1_minter_address.read(), 'Only L1 minter can mint value');
            assert(_user_address != 0, 'User address cannot be zero');
            let user_address = _user_address.try_into().unwrap();
            let new_user_mint_id = self._l1_mint_counts.read(user_address) + 1_u32;
            self._l1_mint_counts.write(user_address, new_user_mint_id);
            let unit_price = self._unit_price.read();
            let current_max_supply = self._current_max_supply.read();
            let max_value_per_tx = self._max_value_per_tx.read();
            let min_value_per_tx = self._min_value_per_tx.read();

            //let mut status: MintStatus = MintStatus::Failed(());
            let mut status = 0_u8;

            if (value <= max_value_per_tx && value >= min_value_per_tx && amount == unit_price
                * value && value <= current_max_supply) {
                let projects_contract = self._projects_contract.read();
                let slot = self._slot.read();

                // [Interaction] Mint
                let token_id = self._projects_contract.read().mintNew(user_address, slot, value);

                // [Effect] Emit event
                let time = get_block_timestamp();

                let user_address: ContractAddress = user_address.try_into().unwrap();
                self.emit(Event::Buy(Buy { address: user_address, value, time }));
                // status = MintStatus::Minted(());
                self._current_max_supply.write(current_max_supply - value);
            }

            let booking = Booking { value, amount, status };

            self._booked_values.write((user_address, new_user_mint_id), booking.status);
        }

        fn claim(ref self: ContractState, user_address: felt252) {}

        fn set_l1_minter_address(ref self: ContractState, l1_address: felt252) {
            assert(!l1_address.is_zero(), 'L1 address cannot be zero');
            let _l1_address = self._l1_minter_address.read();
            assert(_l1_address.is_zero(), 'L1 address already set');
            self._l1_minter_address.write(l1_address);
        }

        fn upgrade(ref self: ContractState, impl_hash: ClassHash) {
            assert(!impl_hash.is_zero(), 'Class hash cannot be zero');
            starknet::replace_class_syscall(impl_hash).unwrap_syscall();
            self.emit(Event::Upgraded(Upgraded { implementation: impl_hash }));
        }
    }
}


#[cfg(test)]
mod tests {
    use array::ArrayTrait;
    use core::result::ResultTrait;
    use core::traits::Into;
    use option::OptionTrait;
    use starknet::syscalls::deploy_syscall;
    use traits::TryInto;

    use test::test_utils::assert_eq;

    use super::EthereumMinter;
    use ethereum_minter::interfaces::l1_minter::{
        IEthereumMinterDispatcher, IEthereumMinterDispatcherTrait
    };

    #[test]
    #[available_gas(30000000)]
    fn test_init() {
        let mut calldata = Default::default();
        // Projects contract
        calldata.append(1);
        // Slot
        calldata.append(2);
        calldata.append(0);
        // Unit price
        calldata.append(3);
        calldata.append(0);
        // Max supply
        calldata.append(10);
        calldata.append(0);
        // Max value per tx
        calldata.append(6);
        calldata.append(0);
        // Min value per tx
        calldata.append(1);
        calldata.append(0);

        let (address0, _) = deploy_syscall(
            EthereumMinter::TEST_CLASS_HASH.try_into().unwrap(), 0, calldata.span(), false
        )
            .unwrap();
        let mut contract = IEthereumMinterDispatcher { contract_address: address0 };

        assert(contract.get_l1_minter_address() == 0, 'l1_minter_address == 0');
    }
}
