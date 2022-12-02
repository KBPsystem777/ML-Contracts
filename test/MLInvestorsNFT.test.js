const { ethers } = require("hardhat")
const { assert, expect } = require("chai")

describe(" >>> ML NFTi test Items >>>", function () {
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
})
