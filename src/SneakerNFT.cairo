use starknet::ContractAddress;

#[starknet::interface]
pub trait ISneakerNFT<TContractState> {
    fn mint(
        ref self: TContractState, recipient: ContractAddress, sneaker_type: u8, sneaker_level: u8
    ) -> u256;
    fn set_base_uri(ref self: TContractState, base_uri: ByteArray);
    fn get_sneaker_type_and_level(self: @TContractState, token_id: u256) -> (u8, u8);
    fn add_owner(ref self: TContractState, new_owner: ContractAddress);
}


#[starknet::contract]
mod SneakerNFT {
    use openzeppelin::introspection::src5::SRC5Component;
    use openzeppelin::token::erc721::ERC721Component;
    use starknet::{ContractAddress, get_caller_address};
    use openzeppelin::token::erc721::interface::{IERC721Dispatcher, IERC721DispatcherTrait};
    use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};

    component!(path: ERC721Component, storage: erc721, event: ERC721Event);
    component!(path: SRC5Component, storage: src5, event: SRC5Event);

    // ERC721
    #[abi(embed_v0)]
    impl ERC721Impl = ERC721Component::ERC721Impl<ContractState>;
    #[abi(embed_v0)]
    impl ERC721MetadataImpl = ERC721Component::ERC721MetadataImpl<ContractState>;
    #[abi(embed_v0)]
    impl ERC721CamelOnly = ERC721Component::ERC721CamelOnlyImpl<ContractState>;
    #[abi(embed_v0)]
    impl ERC721MetadataCamelOnly =
        ERC721Component::ERC721MetadataCamelOnlyImpl<ContractState>;
    impl ERC721InternalImpl = ERC721Component::InternalImpl<ContractState>;

    // SRC5
    #[abi(embed_v0)]
    impl SRC5Impl = SRC5Component::SRC5Impl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        erc721: ERC721Component::Storage,
        #[substorage(v0)]
        src5: SRC5Component::Storage,
        total_count: u32,
        owners: LegacyMap::<ContractAddress, bool>,
        sneaker_type: LegacyMap::<u256, u8>,
        sneaker_level: LegacyMap::<u256, u8>
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        ERC721Event: ERC721Component::Event,
        #[flat]
        SRC5Event: SRC5Component::Event
    }

    mod Errors {
        pub const ONLY_OWNER: felt252 = 'Only owner can do operation';
    }

    #[constructor]
    fn constructor(ref self: ContractState, owner: ContractAddress) {
        let name = "Fitrace Sneaker";
        let symbol = "FRTSNEAKER";
        let base_uri = "https://fitrace.xyz/api?id=";
        let token_id = 1;

        self.erc721.initializer(name, symbol, base_uri);
        self.owners.write(owner, true);
        self.erc721._mint(owner, token_id);
        self.total_count.write(1);
    }


    #[abi(embed_v0)]
    impl ISneakerNFTImpl of super::ISneakerNFT<ContractState> {
        fn mint(
            ref self: ContractState, recipient: ContractAddress, sneaker_type: u8, sneaker_level: u8
        ) -> u256 {
            assert(self.owners.read(get_caller_address()) == true, Errors::ONLY_OWNER);
            let token_id = self.total_count.read() + 1;
            self.total_count.write(token_id);
            self.erc721._mint(recipient, token_id.into());
            self.sneaker_type.write(token_id.into(), sneaker_type);
            self.sneaker_level.write(token_id.into(), sneaker_level);
            token_id.into()
        }

        fn set_base_uri(ref self: ContractState, base_uri: ByteArray) {
            assert(self.owners.read(get_caller_address()) == true, Errors::ONLY_OWNER);
            self.erc721._set_base_uri(base_uri);
        }

        fn get_sneaker_type_and_level(self: @ContractState, token_id: u256) -> (u8, u8) {
            (self.sneaker_type.read(token_id), self.sneaker_level.read(token_id))
        }
        fn add_owner(ref self: ContractState, new_owner: ContractAddress) {
            assert(self.owners.read(get_caller_address()) == true, Errors::ONLY_OWNER);
            self.owners.write(new_owner, true);
        }
    }
}
