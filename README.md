# NFT Marketplace Sample Project (Work in progress)

This personal project demonstrates a basic Marketplace functionality. In this project, we implemented the following contracts:

1. **NFTMainCollection**: This contract is implemented to create an NFT collection. 
2. **NFTCollections**: This contract is implemented to generate multiple collections. It also supports lazy minting (Work in progress).
2. **NFTVoucher**: This contract allows to verify vouchers to redeem a lazy NFT in the generic NFT collection contract.
3. **Marketplace**: This contract implements the functionality to list and buy NFTs. This is an upgradable contract that implements the UUPS proxy pattern. 

> [!NOTE]
> This code is not production ready. Some functionality and testing are missing. 


To install the hardhat project just execute:
```
npm install
```

To compile the project:
```
npx hardhat compile
```

To test the project just type the following command:
```shell
npx hardhat test

or

REPORT_GAS=true npx hardhat test
```