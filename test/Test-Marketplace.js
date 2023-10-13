const {
  time,
  loadFixture,
} = require("@nomicfoundation/hardhat-toolbox/network-helpers");
const { anyValue } = require("@nomicfoundation/hardhat-chai-matchers/withArgs");
const { expect } = require("chai");


const URI = "sample URI";
const ROYALTY_FEES = 300; // Represents 3%
const MARKETPLACE_FEES = 500; // Represents 5%
const FEE_DENOMINATOR = 10000;
const PRICE = 100;

describe("NFT Collection", function () {
  // We define a fixture to reuse the same setup in every test.
  // We use loadFixture to run this setup once, snapshot that state,
  // and reset Hardhat Network to that snapshot in every test.
  async function deployNFTCollection() {
    const [owner, minter, buyer, newBuyer, notOwner] = await ethers.getSigners();

    const nft = await ethers.deployContract("NFTMainCollection", ["NFT Main Collection", "NTC", owner]);
    const marketplace = await ethers.deployContract("Marketplace");
    
    await marketplace.initialize(MARKETPLACE_FEES, owner);
    await nft.connect(minter).mint(URI, ROYALTY_FEES);

    return { nft, marketplace, owner, minter, buyer, newBuyer, notOwner};
  }

  async function itemListed() {
    const { nft, owner, marketplace, minter, buyer, newBuyer, notOwner } = await loadFixture(deployNFTCollection);
    
    await nft.connect(minter).approve(marketplace.target, 1);
    await marketplace.connect(minter).listItem(nft.target, 1, PRICE);

    return { nft, marketplace, owner, minter, buyer, newBuyer, notOwner};
  }

  describe("Marketplace setup", function () {
    it("Should set the right owner", async function () {
      const { nft, owner, marketplace, minter, buyer, newBuyer, notOwner } = await loadFixture(deployNFTCollection);

      expect(await marketplace.owner()).to.be.equal(owner.address);

    });

    it("Should not be possible to initialize more than once", async () => {
      const { nft, owner, marketplace, minter, buyer, newBuyer, notOwner } = await loadFixture(deployNFTCollection);
      await expect(marketplace.initialize(MARKETPLACE_FEES, owner))
        .to.be.revertedWithCustomError(marketplace, "InvalidInitialization");
    });

    it("Should be able to list a new minted NFT", async () => {
        const { nft, owner, marketplace, minter, buyer, newBuyer, notOwner } = await loadFixture(deployNFTCollection);

        expect(await nft.connect(minter).approve(marketplace.target, 1))
          .not.to.be.reverted;

        expect(await marketplace.connect(minter).listItem(nft.target, 1, PRICE))
          .not.to.be.reverted;
    });

    it("Should be able to buy a listed NFT", async () => {
        const { nft, owner, marketplace, minter, buyer, newBuyer, notOwner } = await loadFixture(itemListed);

        
        expect(await marketplace.connect(buyer).buyItem(1, {value: PRICE}))
          .not.to.be.reverted;

        expect(await nft.ownerOf(1)).to.be.equal(buyer.address);
    });

    it("should validate royalties and marketfees", async () => {
        const { nft, owner, marketplace, minter, buyer, newBuyer, notOwner } = await loadFixture(itemListed);

        await expect(
            marketplace.connect(buyer).buyItem(1, {value: PRICE})
        ).to.changeEtherBalance(minter.address, 95);
        
        expect(await marketplace.getContractBalance()).to.be.equal(5);

        await nft.connect(buyer).approve(marketplace.target, 1);
        await marketplace.connect(buyer).listItem(nft.target, 1, PRICE)

        await expect(
            marketplace.connect(newBuyer).buyItem(2, {value: PRICE})
        ).to.changeEtherBalances([minter.address, buyer.address], [3, 92]);

        await expect(
          marketplace.withdraw()
        ).to.changeEtherBalance(owner, 10);
    });
  });

});
