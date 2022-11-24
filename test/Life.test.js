const { ethers } = require("hardhat")
const { assert, expect } = require("chai")

describe(" >>> $LIFE token test Items >>>", function () {
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

  it("Should have an initial supply of 7M tokens", async () => {
    const supply = await token.totalSupply()
    // Expecting that the token's initial supply is 7M
    const value = "7000000" // Change based on the known initial supply
    expect(supply).to.be.not.undefined
    expect(supply).to.be.not.null
    expect(supply).to.be.equal(ethers.utils.parseEther(value))
  })

  it("Should increment total supply after every mint", async () => {
    await token.mint(ethers.utils.parseEther("500000"))
    const newTokenSupply = ethers.utils.formatEther(await token.totalSupply())
    assert.equal(newTokenSupply, 7500000.0)
  })
  it("Should display the correct token symbol", async () => {
    const symbol = await token.symbol()
    assert.equal(symbol, "LIFE")
  })

  it("Should allow token(s) transfers", async () => {
    await token.transfer(
      "0xD10E6200590067b1De5240795F762B43C8e4Cc08",
      ethers.utils.parseEther("1017")
    )

    const accountBalance = await token.balanceOf(
      "0xD10E6200590067b1De5240795F762B43C8e4Cc08"
    )
    expect(ethers.utils.formatEther(accountBalance)).to.be.not.null
    expect(ethers.utils.formatEther(accountBalance)).to.be.not.equals(0)
    assert.equal(ethers.utils.formatEther(accountBalance), "1017.0")
  })

  it("Should update the burning rate", async () => {
    await token.updateBurningRate(ethers.utils.parseEther("0.000101714"))

    const newBurningRate = ethers.utils.formatEther(await token.burningRate())
    expect(newBurningRate).to.be.not.null
    expect(newBurningRate).to.be.not.equals(0)
    assert.equal(newBurningRate, "0.000101714")
  })

  it("Should burn some tokens from an account", async () => {
    await token.burnLifeTokens(
      "0xD10E6200590067b1De5240795F762B43C8e4Cc08",
      ethers.utils.parseEther("100")
    )

    const newBalance = ethers.utils.formatEther(
      await token.balanceOf("0xD10E6200590067b1De5240795F762B43C8e4Cc08")
    )
    assert.equal(newBalance, "917.0")
  })

  it("Should initialize token rewards for MLIFE after NFT transfer", async () => {
    await nft.setLifeToken(token.address)
    // Mint some NFT first
    await nft.mint(ethers.utils.parseEther("777"), "1000000000000000000")
    // Transfer the token to another address
    await nft["safeTransferFrom(address,address,uint256)"](
      await nft.owner(),
      "0xD10E6200590067b1De5240795F762B43C8e4Cc08",
      ethers.utils.parseEther("777")
    )

    assert.equal(
      await nft.balanceOf("0xD10E6200590067b1De5240795F762B43C8e4Cc08"),
      1
    )

    expect(await token.startOfStakingRewards(ethers.utils.parseUnits("1", 18)))
      .to.be.not.null
  })
  it("Should allow claiming of rewards", async () => {
    await nft.setLifeToken(token.address)

    // Mint some NFT first
    await nft.mint(ethers.utils.parseEther("2"), "1000000000000000000")

    // Transfer the token to another address
    await nft["safeTransferFrom(address,address,uint256)"](
      await nft.owner(),
      "0xD10E6200590067b1De5240795F762B43C8e4Cc08",
      ethers.utils.parseEther("2")
    )
    // Make sure the receipient has already 2 NFTs. The other 1 was from the above test
    assert.equal(
      await nft.balanceOf("0xD10E6200590067b1De5240795F762B43C8e4Cc08"),
      2
    )

    expect(await token.claimStakingRewards(ethers.utils.parseEther("2"))).not.to
      .be.undefined

    // Expecting the contract to return a JSON containing the transaction details
    expect(
      await token.claimStakingRewards(ethers.utils.parseEther("2"))
    ).to.contains({})
    expect(await token.claimStakingRewards(ethers.utils.parseEther("2"))).to.not
      .throw
  })

  it("Should check the available claimable rewards", async () => {
    await nft.setLifeToken(token.address)

    // Check the claimable rewards of tokenId #777 from Line #133
    const claimable = ethers.utils.formatEther(
      await token.claimableStakingRewards(ethers.utils.parseEther("777"))
    )

    assert.equal(claimable, "7.0")
    expect(claimable).to.not.to.throw
    expect(claimable).to.be.not.null
  })

  it("Should mint token rewards for NFTi holders", async () => {
    // Address of NFTi holder
    const testAddress = "0x1fcb2d8E0420fd4DA92979446AB247bbaA5a958a"

    // Query the token balance of test address
    // to make sure they dont hold any LIFE tokens at this point
    const holderTokenBalance = ethers.utils.formatEther(
      await token.balanceOf(testAddress)
    )
    // Making sure that the test address
    // has zero $LIFE token balance
    assert.equal(holderTokenBalance, "0.0")

    // Mint rewards to NFTi investors/holders
    await token.mintInvestorsRewards(
      testAddress,

      ethers.utils.parseEther("9090")
    )

    const testAddressNewBalance = await token.balanceOf(testAddress)

    // Making sure that the 9090 units of $LIFE tokens will be minted to
    // the testAddress
    assert.equal(
      ethers.utils.formatEther(testAddressNewBalance.toString()),
      "9090.0"
    )
  })

  it("Should update the start of staking of an NFT", async () => {
    // Query the start of staking of NFT tokenId #77
    // Should return a uint256 of "1669300067"
    // "1669300067" is equals to Thu Nov 24 2022 22:27:47 GMT+0800 (Philippine Standard Time)
    // That was computed by running the below script:
    // new Date(1669300067 * 1000)
    await token.startOfStakingRewards(ethers.utils.parseEther("777"))

    // Update the start of stake of tokenId #777 to 12-25-2022
    // In uint64, 12-25-2022 is equals to 1671897600
    await token.updateStartOfStaking(ethers.utils.parseEther("777"), 1671897600)

    const newStart = await token.startOfStakingRewards(
      ethers.utils.parseEther("777")
    )

    // Expect that the new start of stake for #777 is now "1671897600"
    assert.equal(newStart.toString(), "1671897600")

    expect(newStart.toString()).to.not.throw
    expect(newStart.toString()).to.be.string("1671897600")
    expect(newStart.toString()).to.not.be.null
    expect(newStart.toString()).to.not.be.undefined
  })
})
