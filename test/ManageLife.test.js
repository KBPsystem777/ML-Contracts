const { ethers } = require("hardhat")
const { assert, expect } = require("chai")

describe(" >>> ManageLife NFT test Items >>>", function () {
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
    // console.log(await token.owner(), signerAddress)
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

  it("Should display the correct NFT symbol", async () => {
    const symbol = await nft.symbol()
    assert.equal(symbol, "MLIFE")
  })
  it("Should display the correct NFT name", async () => {
    const symbol = await nft.name()
    assert.equal(symbol, "ManageLife")
  })

  it("Should allow token(s) transfers", async () => {
    await nft.mint(ethers.utils.parseEther("1"), "1000000000000000000")

    await nft["safeTransferFrom(address,address,uint256)"](
      await nft.owner(),
      "0xD10E6200590067b1De5240795F762B43C8e4Cc08",
      ethers.utils.parseEther("1")
    )

    const accountBalance = await nft.balanceOf(
      "0xD10E6200590067b1De5240795F762B43C8e4Cc08"
    )

    expect(ethers.utils.formatEther(accountBalance)).to.be.not.null
    expect(ethers.utils.formatEther(accountBalance)).to.be.not.equals(0)
    assert.equal(accountBalance.toString(), "1")
  })

  it("Should return the correct token issuanceRate", async () => {
    const tokenRate = await nft.lifeTokenIssuanceRate(
      ethers.utils.parseEther("1")
    )
    assert.equal(tokenRate.toString(), "1000000000000000000")
  })

  it("Should test the markFullyPayed function", async () => {
    // Mark tokenId #1 as paid
    await nft.markFullyPayed(ethers.utils.parseEther("1"))

    // Expect the tokenId #1 to be paid
    expect(await nft.fullyPayed(ethers.utils.parseEther("1"))).to.be.true
    assert.equal(await nft.fullyPayed(ethers.utils.parseEther("1")), true)
  })

  it("Should return the correct owner of an NFT", async () => {
    // Mint a new NFT
    await nft.mint(ethers.utils.parseEther("777"), "1000000000000000000")

    const recipientAddress = "0x1fcb2d8E0420fd4DA92979446AB247bbaA5a958a"

    // Transfer the NFT to an address
    await nft["safeTransferFrom(address,address,uint256)"](
      await nft.owner(),
      recipientAddress,
      ethers.utils.parseEther("777")
    )

    const owner = await nft.ownerOf(ethers.utils.parseEther("777"))

    // Expect that the owner of tokenId #777 is 0x1fcb2d8E0420fd4DA92979446AB247bbaA5a958a
    assert.equal(owner, recipientAddress)
    expect(owner).to.be.not.null
    expect(owner).to.be.not.undefined
    expect(owner).to.be.equals("0x1fcb2d8E0420fd4DA92979446AB247bbaA5a958a")
  })

  it("Should return the correct URI of an NFT", async () => {
    // Mint a new NFT
    await nft.mint("1017", ethers.utils.parseEther("0.001"))

    const tokenUri = await nft.getBaseURI()

    const getTokenUri = await nft.tokenURI("1017")

    assert.equal(getTokenUri, `${tokenUri}1017`)
    expect(getTokenUri).to.be.string
    expect(getTokenUri).to.be.not.undefined
  })

  it("Should burn an NFT", async () => {
    // Mint a new NFT
    await nft.mint("11", "1000000000000000000")

    // Burn the NFT
    const tx = await nft.burn("11")

    // On success, the contract should return a JSON
    expect(tx).to.contains({})
    expect(tx).to.not.to.throw
  })

  it("Should update the property custodian", async () => {
    await nft.updatePropertyCustodian(
      "0x1fcb2d8E0420fd4DA92979446AB247bbaA5a958a"
    )

    assert.equal(
      await nft.PROPERTY_CUSTODIAN(),
      "0x1fcb2d8E0420fd4DA92979446AB247bbaA5a958a"
    )
  })
})
