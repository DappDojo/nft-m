# NFT Marketplace Sample Project (Work in progress)

This personal project demonstrates a basic Marketplace functionality. We implement the following contracts:

1. **NFTMainCollection**: This contract is implemented to create main NFT collection. 
2. **NFTCollections**: This contract is implemented to generate multiple collections. It also supports lazy minting (Work in progress).
2. **NFTVoucher**: This contract allows to verify vouchers to redeem a lazy NFT in the generic NFT collection contract. 
3. **Marketplace**: This contract implements the functionality to list and buy NFTs. This is an upgradable contract that implements the UUPS proxy pattern.

> [!NOTE]
> This code is not production ready. More functionality and testing is missing. 


To install the hardhat project just execute:
```
npm install
```

To test the project just
```shell
npx hardhat test
REPORT_GAS=true npx hardhat test
```

To check the project local blockchain run:
```
npx hardhat node
```
