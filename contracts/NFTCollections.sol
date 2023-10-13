// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Pausable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/common/ERC2981.sol";
import "./NFTVoucher.sol";

contract NFTCollections is 
        ERC721, 
        ERC2981,
        ReentrancyGuard, 
        ERC721Enumerable, 
        ERC721URIStorage,
        ERC721Burnable, 
        ERC721Pausable,
        NFTVoucher,
        Ownable
    {

    mapping(bytes32 => bool) private signatures;

    uint256 public tokenCount;
    uint256 private constant TO_PERCENTAGE = 10000;
    uint256 public maxCreatorRoyalties;
    uint8 public lazyMintingFee; 

    event LogNewNFTMinted( uint _nftId, address _owner, string _nftURI, uint _royalties);
    event LogSetMaxCreatorRoyalties(uint newMaxCreatorRoyalties);
    event LogSetLazyMintingFee(uint8 newLazyMintingFee);
    
    constructor(string memory _name, string memory _symbol, address initialOwner) 
        ERC721(_name, _symbol)
        Ownable(initialOwner)
    {
        // Maximun royalties percentage is 5%
        maxCreatorRoyalties = 50;
        // Collection Lazy minting fee percentage is 5%
        lazyMintingFee = 50;
    }

    function setMaxCreatorRoyalties(uint _maxCreatorRoyalties)
        external
        onlyOwner
    {
        require(
                _maxCreatorRoyalties <= TO_PERCENTAGE, 
                "Creator royalties cannot be greater than 100%"
        );
        maxCreatorRoyalties = _maxCreatorRoyalties;
        emit LogSetMaxCreatorRoyalties(_maxCreatorRoyalties);
    }

    // Royalties should be received as an integer number
    // i.e., if royalties are 2.5% this contract should receive 25
    function mint(string memory _tokenURI, uint96 _royaltiesPercentage)
        external
        whenNotPaused
        nonReentrant
        returns(uint) 
    {
      
        (bool success, uint tokenId) = 
            mintNFT(msg.sender, _tokenURI, _royaltiesPercentage);

        require(
            success,
            "Minting failed!"
        );
        
        emit LogNewNFTMinted(tokenId, msg.sender, _tokenURI, _royaltiesPercentage);

        return(tokenId);
    }

    function mintNFT(
            address _newOwner, 
            string memory _tokenURI, 
            uint96 _royaltiesPercentage
        ) 
        private
        returns (bool, uint)
    {
        require(
            _royaltiesPercentage <= maxCreatorRoyalties, 
            "Royalties percentage exceeds the maximum value!"
        );

        tokenCount++;
        uint tokenId = tokenCount;

        _setTokenRoyalty(tokenId, _newOwner, _royaltiesPercentage);
        _setTokenURI(tokenId, _tokenURI);
        _safeMint(_newOwner, tokenId);

        return (true, tokenId);
    }

    // Add Lazy Minting Feature
    function redeem(address redeemer, Voucher calldata voucher)
        external
        payable
        nonReentrant
        returns (uint256) 
    {
        require(
            !signatures[keccak256(voucher.signature)], 
            "The voucher has been redeemed!"
        );

        require(
            redeemer != address(0), 
            "Redeemer is the zero address!"
        );
        
        require(
            voucher.royalties <= maxCreatorRoyalties,
            "Royalties exceed the max creator royalties percentage"
        );

        require(
            voucher.creator != address(0),
            "Creator is the zero address!"
        );

        require(
            voucher.minPrice <= msg.value, 
            "Insufficient funds to redeem"
        );

        address signer = _verify(voucher);
        
        require(
            signer == voucher.creator, 
            "Signature invalid or unauthorized"
        );

        signatures[keccak256(voucher.signature)] = true;
        (bool success, uint tokenId) = 
            mintNFT(signer, voucher.uri, voucher.royalties);

        require(
            success,
            "Lazy minting failed!"
        );
        _safeTransfer(signer, redeemer, tokenId, "");
   
        uint profits = getCreatorProfits(msg.value);
        payable(signer).transfer(profits);
        
        return tokenId;
    }

    function setLazyMintingFee(uint8 _lazyMintingFee) 
        external
        onlyOwner
    {
        // This means that the maximun amount is 100%
        require(
            _lazyMintingFee <= TO_PERCENTAGE, 
            "Lazy Minting Fees cannot be greater than 100%"
        );
        lazyMintingFee = _lazyMintingFee;
        emit LogSetLazyMintingFee(_lazyMintingFee);
    }

    function getCreatorProfits(uint _receivedAmount)
        internal
        view 
        returns(uint)
    {
        uint _platformFees;
        
        _platformFees = (_receivedAmount * lazyMintingFee) / TO_PERCENTAGE;
        return _receivedAmount - _platformFees;
    }

    function getContractBalance()
        external
        view
        onlyOwner
        returns (uint)
    {
        return address(this).balance;
    }

    function withdraw() 
        external
        onlyOwner
        nonReentrant
    {
        payable(owner()).transfer(address(this).balance);
    }

    function _feeDenominator() 
        internal 
        pure 
        override 
        returns (uint96) 
    {
        return 1000;
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    // The following functions are overrides required by Solidity.
    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721, ERC721URIStorage)
        returns (string memory)
    {
        return super.tokenURI(tokenId);
    }

    function _update(address to, uint256 tokenId, address auth)
        internal
        override(ERC721, ERC721Pausable, ERC721Enumerable)
        returns (address)
    {
        return super._update(to, tokenId, auth);
    }

    function _increaseBalance(address account, uint128 value)
        internal
        override(ERC721, ERC721Enumerable)
    {
        super._increaseBalance(account, value);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC2981, ERC721Enumerable, ERC721URIStorage)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

}