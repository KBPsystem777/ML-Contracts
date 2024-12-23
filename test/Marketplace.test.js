const { expect } = require("chai")
const { ethers } = require("hardhat")

describe("Marketplace Smart Contract", function () {
  let marketplace, nft, token, owner, seller, bidder1, bidder2

  before(async function () {
    ;[owner, seller, bidder1, bidder2] = await ethers.getSigners()

    // Deploy mock NFT contract
    const NFTMock = await ethers.getContractFactory("ERC721Mock")
    nft = await NFTMock.deploy("MockNFT", "MNFT")
    await nft.deployed()

    // Mint some NFTs to the seller
    await nft.connect(seller).mint(seller.address, 1)
    await nft.connect(seller).mint(seller.address, 2)

    // Deploy mock ERC20 token
    const ERC20Mock = await ethers.getContractFactory("ERC20Mock")
    token = await ERC20Mock.deploy(
      "MockToken",
      "MTKN",
      ethers.utils.parseEther("1000")
    )
    await token.deployed()

    // Deploy marketplace
    const Marketplace = await ethers.getContractFactory("Marketplace")
    marketplace = await Marketplace.deploy(
      nft.address,
      token.address,
      token.address,
      token.address
    )
    await marketplace.deployed()

    // Approve NFTs for the marketplace
    await nft.connect(seller).setApprovalForAll(marketplace.address, true)
  })

  it("Should create a listing", async function () {
    await marketplace
      .connect(seller)
      .createListing(1, token.address, ethers.utils.parseEther("10"))

    const listing = await marketplace.listings(0)
    expect(listing.seller).to.equal(seller.address)
    expect(listing.tokenId).to.equal(1)
    expect(listing.minPrice).to.equal(ethers.utils.parseEther("10"))
  })

  it("Should place a bid", async function () {
    await token
      .connect(bidder1)
      .approve(marketplace.address, ethers.utils.parseEther("20"))
    await marketplace
      .connect(bidder1)
      .placeBid(0, ethers.utils.parseEther("15"), token.address)

    const bid = await marketplace.currentBids(0)
    expect(bid.bidder).to.equal(bidder1.address)
    expect(bid.amount).to.equal(ethers.utils.parseEther("15"))
  })

  it("Should accept a bid and transfer NFT", async function () {
    await marketplace.connect(seller).acceptBid(0)

    const newOwner = await nft.ownerOf(1)
    expect(newOwner).to.equal(bidder1.address)
  })

  it("Should cancel a listing", async function () {
    await marketplace.connect(seller).createListing(
      2,
      ethers.constants.AddressZero, // ETH
      ethers.utils.parseEther("5")
    )

    await marketplace.connect(seller).cancelListing(2)
    const listing = await marketplace.listings(2)
    expect(listing.active).to.be.false
  })

  it("Should pause and unpause the contract", async function () {
    await marketplace.connect(owner).pause()
    await expect(
      marketplace
        .connect(seller)
        .createListing(1, token.address, ethers.utils.parseEther("10"))
    ).to.be.revertedWith("Pausable: paused")

    await marketplace.connect(owner).unpause()
    await marketplace
      .connect(seller)
      .createListing(1, token.address, ethers.utils.parseEther("10"))
  })

  it("Should update marketplace fee", async function () {
    await marketplace.connect(owner).updateMarketplaceFee(300) // 3%
    const fee = await marketplace.marketplaceFee()
    expect(fee).to.equal(300)
  })

  it("Should handle refunds", async function () {
    await token
      .connect(bidder1)
      .approve(marketplace.address, ethers.utils.parseEther("10"))
    await marketplace
      .connect(bidder1)
      .placeBid(1, ethers.utils.parseEther("10"), token.address)

    await marketplace
      .connect(bidder2)
      .placeBid(1, ethers.utils.parseEther("15"), token.address)

    const refund = await marketplace.tokenRefundsForBidders(
      token.address,
      bidder1.address
    )
    expect(refund).to.equal(ethers.utils.parseEther("10"))
  })
})
