use starknet::StorageAccess;
use starknet::StorageBaseAddress;
use starknet::SyscallResult;
use starknet::storage_access;
use starknet::storage_read_syscall;
use starknet::storage_write_syscall;
use starknet::storage_base_address_from_felt252;
use starknet::storage_address_from_base_and_offset;
use traits::Into;
use traits::TryInto;
use option::OptionTrait;

use ethereum_minter::ethereum_minter::EthereumMinter::Booking;

impl StorageAccessBooking of StorageAccess<Booking> {
    fn read(address_domain: u32, base: StorageBaseAddress) -> SyscallResult::<Booking> {
        StorageAccessBooking::read_at_offset_internal(address_domain, base, 0_u8)
    }
    fn read_at_offset_internal(
        address_domain: u32, base: StorageBaseAddress, offset: u8
    ) -> SyscallResult::<Booking> {
        Result::Ok(
            Booking {
                value: u256 {
                    low: storage_read_syscall(
                        address_domain, storage_address_from_base_and_offset(base, 0_u8 + offset)
                    )?
                        .try_into()
                        .unwrap(),
                    high: storage_read_syscall(
                        address_domain, storage_address_from_base_and_offset(base, 1_u8 + offset)
                    )?
                        .try_into()
                        .unwrap()
                    }, amount: u256 {
                    low: storage_read_syscall(
                        address_domain, storage_address_from_base_and_offset(base, 2_u8 + offset)
                    )?
                        .try_into()
                        .unwrap(),
                    high: storage_read_syscall(
                        address_domain, storage_address_from_base_and_offset(base, 3_u8 + offset)
                    )?
                        .try_into()
                        .unwrap()
                },
                status: storage_read_syscall(
                    address_domain, storage_address_from_base_and_offset(base, 4_u8 + offset)
                )?
                    .try_into()
                    .unwrap(),
            }
        )
    }

    fn write(address_domain: u32, base: StorageBaseAddress, value: Booking) -> SyscallResult::<()> {
        StorageAccessBooking::write_at_offset_internal(address_domain, base, 0_u8, value)
    }

    fn write_at_offset_internal(
        address_domain: u32, base: StorageBaseAddress, offset: u8, value: Booking
    ) -> SyscallResult::<()> {
        storage_write_syscall(
            address_domain,
            storage_address_from_base_and_offset(base, 0_u8 + offset),
            value.value.low.into()
        )?;
        storage_write_syscall(
            address_domain,
            storage_address_from_base_and_offset(base, 1_u8 + offset),
            value.value.high.into()
        )?;
        storage_write_syscall(
            address_domain,
            storage_address_from_base_and_offset(base, 2_u8 + offset),
            value.amount.low.into()
        )?;
        storage_write_syscall(
            address_domain,
            storage_address_from_base_and_offset(base, 3_u8 + offset),
            value.amount.low.into()
        )?;
        storage_write_syscall(
            address_domain,
            storage_address_from_base_and_offset(base, 4_u8 + offset),
            value.status.into()
        )
    }

    fn size_internal(value: Booking) -> u8 {
        5_u8
    }
}
