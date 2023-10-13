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

contract NFTMainCollection is 
        ERC721, 
        ERC2981,
        ReentrancyGuard, 
        ERC721Enumerable, 
        ERC721URIStorage,
        ERC721Burnable, 
        ERC721Pausable,
        Ownable
    {

    mapping(bytes32 => bool) private signatures;

    uint256 public tokenCount;
    uint256 public constant MAX_CREATOR_ROYALTIES = 1000;
    
    event LogNewNFTMinted( uint _nftId, address _owner, string _nftURI, uint _royalties);
    event LogSetMaxCreatorRoyalties(uint newMaxCreatorRoyalties);
        
    constructor(string memory _name, string memory _symbol, address initialOwner) 
        ERC721(_name, _symbol)
        Ownable(initialOwner)
    {}

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
            _royaltiesPercentage <= MAX_CREATOR_ROYALTIES, 
            "Royalties percentage exceeds the maximum value!"
        );

        tokenCount++;
        uint tokenId = tokenCount;

        _setTokenRoyalty(tokenId, _newOwner, _royaltiesPercentage);
        _setTokenURI(tokenId, _tokenURI);
        _safeMint(_newOwner, tokenId);

        return (true, tokenId);
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