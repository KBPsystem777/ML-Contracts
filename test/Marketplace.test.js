const { ethers } = require("hardhat")
const { assert, expect } = require("chai")

describe(" >>> ML Marketplace test Items >>>", function () {
  let token, signerAddress

  before("Deploy the contract instance first", async () => {
    const Token = await ethers.getContractFactory("Life")
    token = await Token.deploy()
    await token.deployed()

    // ManageLife NFT initialization
    const NFT = await ethers.getContractFactory("ManageLife")
    nft = await NFT.deploy()
    await nft.deployed()

    // NFTi initialization
    const ML_NFTI = await ethers.getContractFactory("ManageLifeInvestorsNFT")
    mlNfti = await ML_NFTI.deploy()
    await mlNfti.deployed()

    // Marketplace initialization
    const Marketplace = await ethers.getContractFactory("Marketplace")
    market = await Marketplace.deploy()
    await market.deployed()
    signer = ethers.provider.getSigner(0)

    const nftiAddress = mlNfti.address
    const nftAddress = nft.address
    const tokenAddress = token.address
    const marketplaceAddress = market.address

    // Get signer address
    console.log(
      `
      Pre-deployed contracts:
      > $LIFE Contract Address: ${tokenAddress}
      > MLIFE NFT Contract Address: ${nftAddress}
      > NFTi Contract Address: ${nftiAddress}
      > ML Marketplace Address: ${marketplaceAddress}
      `
    )

    // Get signer address
    ;[signerAddress] = await ethers.provider.listAccounts()
  })

  it("Should set the contract owner to equal the deployer address", async () => {
    assert.equal(await token.owner(), signerAddress)
  })

  it("Should build the integration among contracts", async () => {
    // Life token
    await token.setNftiToken(mlNfti.address)
    await token.setManageLifeToken(nft.address)
    expect(await token.manageLifeToken()).to.be.not.null
    expect(await token.manageLifeInvestorsNft()).to.be.not.null
    assert.equal(await token.manageLifeToken(), nft.address)
    assert.equal(await token.manageLifeInvestorsNft(), mlNfti.address)

    // MangeLife NFT
    await nft.setLifeToken(token.address)
    await nft.setMarketplace(market.address)
    expect(await nft.lifeToken()).to.be.not.null
    expect(await nft.marketplace()).to.be.not.null
    assert.equal(await nft.lifeToken(), token.address)
    assert.equal(await nft.marketplace(), market.address)

    // Marketplace
    await market.setNftContract(nft.address)
    expect(await market.mlifeAddress()).to.be.not.null
    assert.equal(await market.mlifeAddress(), nft.address)

    // NFTi
    await mlNfti.setLifeToken(token.address)
    expect(await mlNfti.setLifeToken(token.address)).to.be.not.null
    assert.equal(await mlNfti.lifeToken(), token.address)
  })

  it("Should display the correct Percents Divider", async () => {
    // Get current Percents divider
    const divider = await market.PERCENTS_DIVIDER()

    // Run tests
    assert.equal(divider.toString(), "10000")
    expect(divider.toString()).to.not.throw
    expect(divider.toString()).to.be.string
    expect(divider.toString()).to.not.be.null
    expect(divider.toString()).to.not.undefined
  })
  it("Should display the correct Admin Percent", async () => {
    // Get the current admin percent
    const adminPercent = await market.adminPercent()

    // Run tests
    assert.equal(adminPercent, "200")
    expect(adminPercent.toString()).to.not.throw
    expect(adminPercent.toString()).to.be.string
    expect(adminPercent.toString()).to.not.be.null
    expect(adminPercent.toString()).to.not.undefined

    // New test: Update the admin percent
    // Update the admin percent to 333
    const newAdminPercent = await market.setAdminPercent("333")

    // Get the value of the updated admin percent
    const updatedAdminPercent = await market.adminPercent()

    // Run tests
    assert.equal(updatedAdminPercent, "333")
    expect(updatedAdminPercent.toString()).to.not.throw
    expect(updatedAdminPercent.toString()).to.be.string
    expect(updatedAdminPercent.toString()).to.not.be.null
    expect(updatedAdminPercent.toString()).to.not.undefined
  })
  it("Should perform sale offerings", async () => {
    // Pre-mint the NFTs to be put into bid
    await nft.mint(ethers.utils.parseEther("1"), "1000000000000000000")

    // Setting the trading to false to allow the admins to trade on behalf of the owner
    await market.setTrading(false)

    // Transfer the NFT to an address
    // On success, NFT #1 will be created
    await nft["safeTransferFrom(address,address,uint256)"](
      await nft.owner(),
      "0xD10E6200590067b1De5240795F762B43C8e4Cc08",
      ethers.utils.parseEther("1")
    )

    // Offer the NFT#1 for sale
    await market.offerForSale(
      ethers.utils.parseEther("1"),
      ethers.utils.parseEther("0.0101714")
    )

    // Run tests
    // Making sure that the Offers struct will be updated with the new offer
    const offers = await market.offers(ethers.utils.parseEther("1"))

    // Making sure that offer #1 is forSale
    assert.equal(offers[0], true)

    // Making sure that the seller of offer #1 is correct
    assert.equal(offers[2], "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266")
  })

  it("Should perform bid", async () => {
    // Pre-mint the NFTs to be put into bid
    await nft.mint(ethers.utils.parseEther("1017"), "1000000000000000000")

    // Setting the trading to false to allow the admins to trade on behalf of the owner
    await market.setTrading(false)

    // Transfer the NFT to an address
    // On success, NFT #12 will be created
    await nft["safeTransferFrom(address,address,uint256)"](
      await nft.owner(),
      "0xD10E6200590067b1De5240795F762B43C8e4Cc08",
      ethers.utils.parseEther("1017")
    )

    // Offer the NFT #12 for sale
    await market.placeBid(ethers.utils.parseEther("1017"), {
      value: ethers.utils.parseEther("0.002"),
    })

    // Submit mock bid for NFT #1
    const bid = await market.bids(ethers.utils.parseEther("1017"))

    // Run tests -- Making sure that the Bids struct will be updated with the new bid
    // Making sure the bid variable contains the correct bidder address
    assert.equal(bid[1], await market.owner())
    expect(bid).to.contains(bid[1])
  })

  it("Should be able to change the trading status", async () => {
    // Get the current trading status
    // Should return false
    const isAllowedTrading = await market.allowTrading()

    // Change the trading status to true
    await market.setTrading(true)

    // Run tests to make sure trading status has been changed
    assert.notEqual(isAllowedTrading, market.allowTrading())
    assert.equal(await market.allowTrading(), true)
  })

  it("Should be able to change the ML Admin", async () => {
    // Get the current market admin
    const currentAdmin = await market.mlAdmin()

    // Change the market admin
    await market.setMLAdmin("0x1fcb2d8E0420fd4DA92979446AB247bbaA5a958a")

    // Test to make sure market admin has been changed
    assert.notEqual(currentAdmin, await market.mlAdmin())
    assert.equal(
      await market.mlAdmin(),
      "0x1fcb2d8E0420fd4DA92979446AB247bbaA5a958a"
    )
  })
})
