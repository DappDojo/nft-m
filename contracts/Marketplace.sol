// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import {ERC721HolderUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC721/utils/ERC721HolderUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC2981} from "@openzeppelin/contracts/interfaces/IERC2981.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

contract Marketplace is 
            Initializable,
            UUPSUpgradeable,
            OwnableUpgradeable,
            PausableUpgradeable,
            ERC721HolderUpgradeable,
            ReentrancyGuardUpgradeable
    {
    uint256 public itemsCount;
    uint256 private itemsSold;

    // Royalties should be received as an integer number
    // i.e., if royalties are 2.5% this contract should receive 25
    uint private constant TO_PERCENTAGE = 10000;
    bytes4 private constant _INTERFACE_ID_ERC2981 = 0x2a55205a;

    // Percentage fee on sales
    uint public feePercentage; 
    uint public listingFeePercentage;
    
    enum item_status
    {
      Not_Listed,
      Listed,
      Sold
    }

    struct Item {
        uint itemId;
        address nftAddress;
        uint tokenId;
        uint price;
        address payable seller;
        address payable creator;
        uint creatorRoyalties;
        item_status status;
    }

    // itemId -> Item
    mapping(uint => Item) public items;

    event LogCreateItem(
        uint _itemId,
        address indexed _nft,
        uint _tokenId,
        uint _price,
        address indexed _seller,
        address _creator
    );

    event LogBuyItem(
        uint _itemId,
        address indexed _nft,
        uint _tokenId,
        uint _price,
        address indexed _seller,
        address indexed _buyer
    );

    event LogChangeStatus(
        uint _itemID, 
        address _seller, 
        item_status _newStatus
    );

    event LogChangePrice(
        uint _itemId, 
        address _sender, 
        uint _newPrice
    );

    event LogSettListingFeesPercentage(
        uint _listingFeePercentage
    );
    
    event LogSetFeePercentage(
        uint _feePercentage
    );

    constructor() {
        //_disableInitializers();
    }

    function initialize(uint _feePercentage, address initialOwner) 
        public
        initializer
    {
        __Ownable_init(initialOwner);
        __UUPSUpgradeable_init();
        __Pausable_init();
        __ERC721Holder_init();
        __ReentrancyGuard_init();
        
        feePercentage = _feePercentage;
        listingFeePercentage = 0;
    }

    function setListingFeesPercentage(uint _listingFeePercentage)
        external
        onlyOwner 
    {
        listingFeePercentage = _listingFeePercentage;
        emit LogSettListingFeesPercentage(_listingFeePercentage);
    }

    function setFeePercentage(uint _feePercentage) 
        external 
        onlyOwner 
    {
        feePercentage = _feePercentage;
        emit LogSetFeePercentage(_feePercentage);
    }

    function getListingFees(uint _price)
        public
        view
        returns(uint)
    {
        return (_price * listingFeePercentage)/TO_PERCENTAGE;
    }

    // Creates a new listing on the marketplace
    function listItem(address _nft, uint _tokenId, uint _price)
        external
        whenNotPaused
        nonReentrant
        payable
        returns(uint)
    {
        require(_nft != address(0), "Zero address is not allowed!");
        require(_tokenId > 0, "Token id should be greater than zero!");
        require(
            IERC721(_nft).ownerOf(_tokenId) == msg.sender, 
            "Only owner can list its NFT!"
        );
        require(
            getListingFees(_price) <= msg.value, 
            "Should pay listing fees!"
        );
        
        // increment itemCount
        itemsCount++;
        uint itemId = itemsCount;
        
        address _creator;

        uint _creatorRoyalties = 0;

        if(checkRoyalties(_nft)){
            (_creator, _creatorRoyalties) = IERC2981(_nft).royaltyInfo(_tokenId, _price);
            require(_creator != address(0), "Creator is zero address!");
        }
        else
            _creator = msg.sender;
        
        // add new item to items mapping
        items[itemId] = Item(
            itemId,
            _nft,
            _tokenId,
            _price,
            payable(msg.sender),
            payable(_creator),
            _creatorRoyalties,
            item_status.Listed
        );
        // emit Offered event
        emit LogCreateItem(
            itemId,
            _nft,
            _tokenId,
            _price,
            msg.sender,
            _creator
        );

        // transfer nft
        IERC721(_nft).safeTransferFrom(msg.sender, address(this), _tokenId);

        return itemsCount;
    }

    function checkRoyalties(address _contract) 
        internal 
        view
        returns (bool) 
    {
        (bool success) = IERC165(_contract).supportsInterface(_INTERFACE_ID_ERC2981);
        return success;
    }
    
    function getListedAgain(uint _itemId, uint _newPrice)
        external
    {
        require(changeItemPrice(_itemId, _newPrice), "Set new price failed!");
        require(changeItemStatus(_itemId, item_status.Listed), "Set new item status failed!");
    }

    function changeItemStatus(uint _itemId, item_status _newStatus)
        public
        returns(bool)
    {
        Item storage item = items[_itemId];
        require(item.seller == msg.sender, "only seller can change status!");
        require(item.status != _newStatus, "status should be new!");
        require(item.status != item_status.Sold, "item already sold!");
        item.status = _newStatus;
        emit LogChangeStatus(_itemId, msg.sender, _newStatus);

        return true;
    }

    function changeItemPrice(uint _itemId, uint _newPrice)
        internal
        returns(bool)
    {
        Item storage item = items[_itemId];
        require(item.seller == msg.sender, "only seller can change status!");
        require(item.status != item_status.Sold, "item already sold!");
        require(item.status == item_status.Not_Listed, "item should not be listed");

        item.price = _newPrice;
        emit LogChangePrice(_itemId, msg.sender, _newPrice);

        return true;
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
   
    function buyItem(uint _itemId) 
        external 
        payable
        nonReentrant
        whenNotPaused
    {
        Item storage item = items[_itemId];
        require(_itemId > 0 && _itemId <= itemsCount, "item does not exist");
        require(msg.value >= item.price, "not enough ether to cover item price and market fee");
        require(item.status == item_status.Listed, "item should be listed");

        uint _creatorRoyalties = 0;
        // transfer nft to buyer
        address nft = item.nftAddress;

        if(checkRoyalties(nft))
            (, _creatorRoyalties) = IERC2981(nft).royaltyInfo(item.tokenId, msg.value);
        
        item.creatorRoyalties = _creatorRoyalties;
        
        uint profits = getProfits(msg.value, item.creatorRoyalties);
        
        // pay seller and feeAccount
        (item.creator).transfer(item.creatorRoyalties);
        (item.seller).transfer(profits);
        
        // update item to sold
        item.status = item_status.Sold;
        
        // increase counter
        itemsSold;

        // emit Bought event
        emit LogBuyItem(
            _itemId,
            address(item.nftAddress),
            item.tokenId,
            item.price,
            item.seller,
            msg.sender
        );
        
        IERC721(nft).safeTransferFrom(address(this), msg.sender, item.tokenId);
    }

    function getItemsSold() 
        external
        view 
        returns (uint) 
    {
        return itemsSold;
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function getItemsCount()
        external
        view
        returns (uint) 
    {
        return itemsCount;
    }

    function getProfits(uint _price, uint _creatorRoyalties)
        internal
        view 
        returns(uint _sellerAmount)
    {
        uint _platformFees;
        
        _platformFees = (_price * feePercentage) / TO_PERCENTAGE;
        _sellerAmount = _price - (_platformFees + _creatorRoyalties);
    }

    // This function is required by the OpenZeppelin module.
    function _authorizeUpgrade(address) internal override onlyOwner {}

}