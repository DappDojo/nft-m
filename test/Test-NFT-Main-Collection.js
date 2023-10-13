const {
  time,
  loadFixture,
} = require("@nomicfoundation/hardhat-toolbox/network-helpers");
const { anyValue } = require("@nomicfoundation/hardhat-chai-matchers/withArgs");
const { expect } = require("chai");


const URI = "sample URI";
const ROYALTY_FEES = 300; // Represents 3%
const FEE_DENOMINATOR = 10000;
const PRICE = 100;

describe("NFT Collection", function () {
  // We define a fixture to reuse the same setup in every test.
  // We use loadFixture to run this setup once, snapshot that state,
  // and reset Hardhat Network to that snapshot in every test.
  async function deployNFTCollection() {
    const [owner, minter, buyer, notOwner] = await ethers.getSigners();

    const nft = await ethers.deployContract("NFTMainCollection", ["NFT Main Collection", "NTC", owner]);
    
    return { nft, owner, minter, buyer, notOwner};
  }

  describe("NFT Minting", function () {
    it("Should set the right owner", async function () {
      const { nft, owner, minter, buyer, notOwner } = await loadFixture(deployNFTCollection);
      expect(await nft.owner()).to.be.equal(owner.address);
    });

    it("Should allow to mint a new NFT", async () => {
      const { nft, owner, minter, buyer, notOwner } = await loadFixture(deployNFTCollection);

      expect(await nft.connect(minter).mint(URI, ROYALTY_FEES)).not.to.be.reverted;
      expect(await nft.tokenCount()).to.be.equal(1);
      expect(await nft.ownerOf(1)).to.be.equal(minter.address);
    });

    it("Should not allow to mint a new NFT when paused", async () => {
      const { nft, owner, minter, buyer, notOwner } = await loadFixture(deployNFTCollection);
      await nft.pause();

      await expect(
          nft.connect(minter).mint(URI, ROYALTY_FEES))
          .to.be.revertedWithCustomError(nft, "EnforcedPause");

      await nft.unpause();
      expect(
          await nft.connect(minter).mint(URI, ROYALTY_FEES))
          .not.to.be.reverted;
    });

    it("Should allow only owner to pause the contract", async () => {
      const { nft, owner, minter, buyer, notOwner } = await loadFixture(deployNFTCollection);
      await expect(
          nft.connect(notOwner).pause())
          .to.be.revertedWithCustomError(nft, "OwnableUnauthorizedAccount")
          .withArgs(notOwner.address);
    });

    it("Should emit an event when minting", async () => {
      const { nft, owner, minter, buyer, notOwner } = await loadFixture(deployNFTCollection);
      await expect(nft.connect(minter).mint(URI, ROYALTY_FEES))
          .to.emit(nft, "LogNewNFTMinted")
          .withArgs(1, minter.address, URI, ROYALTY_FEES);
    });

    it("Should validate the creator's royalties", async () => {
      const { nft, owner, minter, buyer, notOwner } = await loadFixture(deployNFTCollection);
      const royaltyAmount = (PRICE * ROYALTY_FEES) / FEE_DENOMINATOR;
      expect(await nft.connect(minter).mint(URI, ROYALTY_FEES)).not.to.be.reverted;

      const [creator, royalties] = await nft.royaltyInfo(1, PRICE);
      expect(creator).to.be.equal(minter.address);
      expect(royalties).to.be.equal(royaltyAmount);
    });

    it("Should be possible to burn an NFT", async () => {
      const { nft, owner, minter, buyer, notOwner } = await loadFixture(deployNFTCollection);

      expect(await nft.connect(minter).mint(URI, ROYALTY_FEES)).not.to.be.reverted;
      expect(await nft.tokenCount()).to.be.equal(1);
      
      await nft.connect(minter).burn(1);
      await expect(nft.ownerOf(1))
        .to.be.revertedWithCustomError(nft, "ERC721NonexistentToken")
        .withArgs(1);

    });

  });

});
