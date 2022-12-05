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
    signer = ethers.provider.getSigner(3)

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

  it("Should display the correct baseURI", async () => {
    // Get original baseURI
    const originalURI = await mlNfti.baseURI()

    // Update the baseURI
    await mlNfti.updateBaseURI(
      "ipfs://QmeSjSinHpPnmXmspMjwiXyN6zS4E9zccariGR3jxcaWtq/"
    )

    // Tests
    assert.notEqual(originalURI, await mlNfti.baseURI())
    assert.deepEqual(
      await mlNfti.baseURI(),
      "ipfs://QmeSjSinHpPnmXmspMjwiXyN6zS4E9zccariGR3jxcaWtq/",
      "Not equal"
    )
  })

  it("Should be able to mint new NFTs", async () => {
    // Mint NFTs
    await mlNfti.mint("10")
    // Get total supply
    const totalSupply = await mlNfti.totalSupply()
    // Run tests
    assert.equal(totalSupply.toString(), 10)
  })

  it("Should return the token URI of an NFT", async () => {
    const uri = await mlNfti.tokenURI("2")

    assert.deepEqual(
      uri,
      "ipfs://QmeSjSinHpPnmXmspMjwiXyN6zS4E9zccariGR3jxcaWtq/2",
      "Not equal"
    )
  })

  it("Should display the correct burning rate", async () => {
    // Get the current burning rate
    const currentBurningRate = ethers.utils.formatEther(
      await mlNfti.tokenBurningRate()
    )

    assert.equal(currentBurningRate, 0.07)

    // Update the burning rate
    const newRate = await mlNfti.updateTokenBurningRate(
      ethers.utils.parseEther("0.101714")
    )

    // Run test
    assert.notEqual(currentBurningRate, newRate)
    assert(newRate, "0.101714")
  })

  it("Should display the correct NFT symbol", async () => {
    const symbol = await mlNfti.symbol()
    assert.equal(symbol, "NFTi")
  })

  it("Should display the correct NFT name", async () => {
    const symbol = await mlNfti.name()
    assert.equal(symbol, "ManageLife Investors NFT")
  })

  it("Should issue an NFT to an investor", async () => {
    const investorAddress = "0x1fcb2d8E0420fd4DA92979446AB247bbaA5a958a"
    // Issue an NFT to an investor
    await mlNfti.issueNftToInvestor(
      investorAddress,
      "3",
      ethers.utils.parseEther("0.000101714")
    )

    // Run test to make sure the NFT #3 has been passed to new owner
    assert.equal(await mlNfti.ownerOf("3"), investorAddress)
    assert.equal(await mlNfti.balanceOf(investorAddress), "1")
  })

  it("Should return the correct life token issuance rate", async () => {
    // Get the tokenIssuance rate of token #3
    const tokenRate = await mlNfti.lifeTokenIssuanceRate("3")

    // Update the issuance rate
    await mlNfti.updateLifeTokenIssuanceRate(
      "3",
      ethers.utils.parseEther("0.00777")
    )

    // Run tests
    assert.notEqual(
      tokenRate,
      await mlNfti.lifeTokenIssuanceRate("3").toString()
    )

    const getTokenIssuanceRate = ethers.utils.formatEther(
      await mlNfti.lifeTokenIssuanceRate("3")
    )
    assert.equal(getTokenIssuanceRate.toString(), "0.00777")
  })

  it("Should transfer an NFTi", async () => {
    const investorAddress = "0x18b0D18d331DBDc50e288D604EB1648aBFF2BfAE"
    // Transfer nft
    await mlNfti.transferNft(investorAddress, "5")

    // Run tests
    assert.equal(await mlNfti.balanceOf(investorAddress), "1")
    assert.equal(await mlNfti.ownerOf("5"), investorAddress)
  })

  it("Should be able to check claimable LIFE token rewards", async () => {
    // Check the claimable rewards
    const availableRewards = await mlNfti.checkClaimableStakingRewards("3")

    // Run tests
    expect(ethers.utils.formatEther(availableRewards)).to.be.not.undefined
    assert.equal(ethers.utils.formatEther(availableRewards), "0.00777")
  })

  it("Should be able to claim LIFE token rewards", async () => {
    // Check the claimable rewards
    const availableRewards = await mlNfti.checkClaimableStakingRewards("3")
    // Get the initial LIFE token balance of an address
    const initialLifeBalance = await token.balanceOf(
      "0x18b0D18d331DBDc50e288D604EB1648aBFF2BfAE"
    )
    // Execute rewards claiming
    await mlNfti.claimStakingRewards("3")

    // Run tests
    // Making sure that the user will be able to claim not less than zero rewards
    // NOTE: It is expected that this test will fail, because the one who will run this
    // function should be the owner of the NFT
    assert.notEqual(
      ethers.utils.formatEther(
        await token.balanceOf("0x18b0D18d331DBDc50e288D604EB1648aBFF2BfAE")
      ),
      "0"
    )
  })
})
