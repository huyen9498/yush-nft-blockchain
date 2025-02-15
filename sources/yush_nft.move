/// How to interact with this module:
/// 1. Create and configure an admin account (in addition to the source account and nft-receiver account that we created in the earlier parts).
/// - 1.a run `aptos init --profile admin` to create an admin account
/// - 1.b go to `Move.toml` and replace `admin_addr = "0xcafe"` with the actual admin address we just created
///
/// 2. Publish the module under a resource account.
/// - 2.a Make sure you're in the right directory.
/// Run the following command in directory `aptos-core/aptos-move/move-examples/mint_nft/3-Adding-Admin`.
/// - 2.b Run the following CLI command to publish the module under a resource account.
/// aptos move create-resource-account-and-publish-package --seed [seed] --address-name mint_nft --profile default --named-addresses source_addr=[default account's address]
///
/// 3. Go over how we're using the admin account in the code below.
/// - 3.a In struct `ModuleData`, we added two additional fields: `expiration_timestamp` and `minting_enabled`. This will allow us to set and update
/// when this collection will expire, and also enable / disable minting ad-hoc.
/// - 3.b We added two admin functions `set_minting_enabled()` and `set_timestamp()` to update the `expiration_timestamp` and `minting_enabled` fields.
/// In the admin functions, we check if the caller is calling from the valid admin's address. If not, we abort because the caller does not have permission to
/// update the config of this module.
/// - 3.c In `mint_event_ticket()`, we added two assert statements to make sure that the user can only mint token from this collection if minting is enabled and
/// the collection is not expired.
///
/// 4. Mint an NFT to the nft-receiver account.
/// - 4.a Run the following command to mint an NFT (failure expected).
/// aptos move run --function-id [resource account's address]::create_nft_with_resource_and_admin_accounts::mint_event_ticket --profile nft-receiver
/// example output:
/// Running this command fails because minting is disabled in `init_module()`. We will use the admin account to update the flag `minting_enabled` to true and try again.
/// - 4.b Running the following command from the admin account to update field `minting_enabled` to true.
/// aptos move run --function-id [resource account's address]::create_nft_with_resource_and_admin_accounts::set_minting_enabled --args bool:true --profile admin
/// example output:
/// - 4.c Mint the NFT again (should be successful this time).
/// aptos move run --function-id [resource account's address]::create_nft_with_resource_and_admin_accounts::mint_event_ticket --profile nft-receiver
module yushchenko_foundation::ykl_nft {
    use std::error;
    use std::string;
    use std::vector;

    use aptos_token::token;
    use std::signer;
    use std::string::String;
    use aptos_framework::account::SignerCapability;
    use aptos_framework::resource_account;
    use aptos_framework::account;
    use aptos_framework::block::get_current_block_height;

    // This struct stores an NFT collection's relevant information
    struct ModuleData has key {
        // Storing the signer capability here, so the module can programmatically sign for transactions
        signer_cap: SignerCapability,
        collection_name: String,
        minting_enabled: bool,
        available_media_uris: vector<vector<u8>>
    }

    /// Action not authorized because the signer is not the admin of this module
    const ENOT_AUTHORIZED: u64 = 1;
    /// The collection minting is disabled
    const EMINTING_DISABLED: u64 = 2;
    /// No available uris left. All NFTs were minted.
    const ENO_AVAILABLE_URIS: u64 = 3;

    /// `init_module` is automatically called when publishing the module.
    /// In this function, we create an example NFT collection and an example token.
    fun init_module(resource_signer: &signer) {
        let collection_name = string::utf8(b"Kateryna Yushchenko NFTs");
        let description = string::utf8(b"Charity NFTs for support of Ukrainian women in STEM");
        let collection_uri = string::utf8(b"yushchenko-nft.com");

        // This means that the supply of the token will not be tracked.
        let maximum_supply = 0;
        // This variable sets if we want to allow mutation for collection description, uri, and maximum.
        // Here, we are setting all of them to false, which means that we don't allow mutations to any CollectionData fields.
        let mutate_setting = vector<bool>[ false, false, false ];

        // Create the nft collection.
        token::create_collection(resource_signer, collection_name, description, collection_uri, maximum_supply, mutate_setting);

        let resource_signer_cap = resource_account::retrieve_resource_account_cap(resource_signer, @source_addr);
        move_to(resource_signer, ModuleData {
            signer_cap: resource_signer_cap,
            collection_name,
            minting_enabled: false,
            available_media_uris: vector[]
        });
    }

    /// Mint an NFT to the receiver. Note that different from the tutorial in 1-Create-NFT, here we only ask for the receiver's
    /// signer. This is because we used resource account to publish this module and stored the resource account's signer
    /// within the `ModuleData`, so we can programmatically sign for transactions instead of manually signing transactions.
    /// See https://aptos.dev/concepts/accounts/#resource-accounts for more details.
    public entry fun mint_nft(receiver: &signer) acquires ModuleData {
        let module_data = borrow_global_mut<ModuleData>(@yushchenko_foundation);

        // Check the config of this module to see if we enable minting tokens from this collection
        assert!(module_data.minting_enabled, error::permission_denied(EMINTING_DISABLED));
        // Check that there are available media to tie to a new token
        assert!(vector::length(&module_data.available_media_uris) > 0, error::invalid_state(ENO_AVAILABLE_URIS));

        let resource_signer = account::create_signer_with_capability(&module_data.signer_cap);
        let token_uri_and_token_name_index = get_current_block_height() % vector::length(&module_data.available_media_uris);
        let media_uri = vector::remove(&mut module_data.available_media_uris, token_uri_and_token_name_index);
        let token_name = string::utf8(media_uri);

        let token_data_id = token::create_tokendata(
            &resource_signer,
            module_data.collection_name,
            token_name,
            string::utf8(b""),
            1,
            string::utf8(b"https://todo.com"),
            signer::address_of(&resource_signer),
            1,
            1,
            // This variable sets if we want to allow mutation for token maximum, uri, royalty, description, and properties.
            // Disallow mutability for any of these parameters.
            token::create_token_mutability_config(
                &vector<bool>[ false, false, false, false, false ]
            ),
            // store the associated media in token properties
            vector<String>[string::utf8(b"media_uri")],
            vector<vector<u8>>[media_uri],
            vector<String>[ string::utf8(b"vector<u8>") ],
        );

        let token_id = token::mint_token(&resource_signer, token_data_id, 1);
        token::direct_transfer(&resource_signer, receiver, token_id, 1);

    }

    public entry fun add_available_media(caller: &signer, media_uri: String) acquires ModuleData {
        let module_data = borrow_global_mut<ModuleData>(@yushchenko_foundation);
        assert!(signer::address_of(caller) == @admin_addr, error::permission_denied(ENOT_AUTHORIZED));

        let media_uri_as_utf8 = *string::bytes(&media_uri);
        vector::push_back(&mut module_data.available_media_uris, media_uri_as_utf8)
    }

    public entry fun batch_add_available_media(caller: &signer, media_uris: vector<vector<u8>>) acquires ModuleData {
        let module_data = borrow_global_mut<ModuleData>(@yushchenko_foundation);
        assert!(signer::address_of(caller) == @admin_addr, error::permission_denied(ENOT_AUTHORIZED));

        vector::append(&mut module_data.available_media_uris, media_uris)
    }

    /// Set if minting is enabled for this minting contract.
    public entry fun set_minting_enabled(caller: &signer, minting_enabled: bool) acquires ModuleData {
        let caller_address = signer::address_of(caller);
        // Abort if the caller is not the admin of this module.
        assert!(caller_address == @admin_addr, error::permission_denied(ENOT_AUTHORIZED));
        let module_data = borrow_global_mut<ModuleData>(@yushchenko_foundation);
        module_data.minting_enabled = minting_enabled;
    }

}

