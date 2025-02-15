# Contracts for YUSH NFT

## Workflow

### Deploy

Deploy just like this:
```bash
aptos move create-resource-account-and-publish-package --seed <your_seed> --address-name yushchenko_foundation --profile default --named-addresses source_addr=[default profile address]
```
Here we create a resource account by the name of `yushchenko_foundation` and store module data within it. The deployer account holds the sources.

### Initialization

To prepare the NFTs, use `add_available_media` or `batch_add_available_media`.

```bash
aptos move run \
--function-id [resource account address]::ykl_nft::add_available_media_and_name \
--args string:'https://preview.redd.it/gotl8lh2m5471.jpg?width=960&crop=smart&auto=webp&v=enabled&s=5cfbaa200285a3a5ed2af2da27e8b1efa4894b62' \
--profile admin
```

When your media is added, enable minting:

```bash
aptos move run \
--function-id [resource account address]::ykl_nft::set_minting_enabled \
--args bool:true \
--profile admin
```

### Minting NFTs

To mint an NFT, run:

```bash
aptos move run --function-id [resource account address]::ykl_nft::mint_nft
```