use starknet::ContractAddress;

#[starknet::interface]
pub trait IFRTCoin<TContractState> {
    fn mint(ref self: TContractState, recipient: ContractAddress, amount: u256);
    fn get_sneaker_contract_address(self: @TContractState) -> ContractAddress;
    fn set_sneaker_contract_address(
        ref self: TContractState, sneaker_contract_address: ContractAddress
    );
    fn claim_tokens(ref self: TContractState, steps: u64);
    fn whitelist_user(ref self: TContractState, user_address: ContractAddress);
}


#[starknet::contract]
mod FRTCoin {
    use openzeppelin::token::erc20::ERC20Component;
    use starknet::{ContractAddress, get_caller_address};
    use openzeppelin::token::erc20::interface;

    component!(path: ERC20Component, storage: erc20, event: ERC20Event);

    #[abi(embed_v0)]
    impl ERC20Impl = ERC20Component::ERC20Impl<ContractState>;
    #[abi(embed_v0)]
    impl ERC20CamelOnlyImpl = ERC20Component::ERC20CamelOnlyImpl<ContractState>;
    impl ERC20InternalImpl = ERC20Component::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        erc20: ERC20Component::Storage,
        decimals: u8,
        owner: ContractAddress,
        sneaker_contract: ContractAddress,
        whitelisted_addresses: LegacyMap::<ContractAddress, bool>
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        ERC20Event: ERC20Component::Event
    }

    mod Errors {
        pub const ONLY_OWNER: felt252 = 'Only owner can do operation';
        pub const ONLY_SNEAKER_OWNER: felt252 = 'Only Sneaker owner can do op';
        pub const ONLY_WHITELISTED_ADDRESSES: felt252 = 'Only Whitelisted addr can claim';
    }

    #[constructor]
    fn constructor(
        ref self: ContractState, owner: ContractAddress, sneaker_contract: ContractAddress,
    ) {
        // Call the internal function that writes decimals to storage
        self._set_decimals(1);

        let name = "FitraceCoin";
        let symbol = "FRT";
        self.erc20.initializer(name, symbol);
        self.erc20._mint(owner, 1000_000_00);
        self.owner.write(owner);
        self.sneaker_contract.write(sneaker_contract);
    }
    #[abi(embed_v0)]
    impl IFRTCoinImpl of super::IFRTCoin<ContractState> {
        fn mint(ref self: ContractState, recipient: ContractAddress, amount: u256) {
            assert(get_caller_address() == self.owner.read(), Errors::ONLY_OWNER);
            assert(amount < 10000, 'mint amount exceeds limit');
            assert(get_caller_address() == self.owner.read(), Errors::ONLY_OWNER);
            self.erc20._mint(recipient, amount);
        }

        fn set_sneaker_contract_address(
            ref self: ContractState, sneaker_contract_address: ContractAddress
        ) {
            assert(get_caller_address() == self.owner.read(), Errors::ONLY_OWNER);
            self.sneaker_contract.write(sneaker_contract_address);
        }
        fn get_sneaker_contract_address(self: @ContractState) -> ContractAddress {
            self.sneaker_contract.read()
        }

        fn claim_tokens(ref self: ContractState, steps: u64) {
            let is_whitelisted = self.whitelisted_addresses.read(get_caller_address());
            assert(is_whitelisted, Errors::ONLY_WHITELISTED_ADDRESSES);
            self.erc20._mint(get_caller_address(), steps.into());
        }
        
        fn whitelist_user(ref self: ContractState, user_address: ContractAddress) {
            assert(get_caller_address() == self.owner.read(), Errors::ONLY_OWNER);
            self.whitelisted_addresses.write(user_address, true);
        }
    }

    #[abi(embed_v0)]
    impl ERC20MetadataImpl of interface::IERC20Metadata<ContractState> {
        fn name(self: @ContractState) -> ByteArray {
            self.erc20.name()
        }

        fn symbol(self: @ContractState) -> ByteArray {
            self.erc20.symbol()
        }

        fn decimals(self: @ContractState) -> u8 {
            self.decimals.read()
        }
    }

    #[generate_trait]
    impl InternalImpl of InternalTrait {
        fn _set_decimals(ref self: ContractState, decimals: u8) {
            self.decimals.write(decimals);
        }
    }
}
