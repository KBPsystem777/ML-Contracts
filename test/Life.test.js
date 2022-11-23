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
    signer = ethers.provider.getSigner(0)

    const nftiAddress = mlNfti.address
    const nftAddress = nft.address
    const tokenAddress = token.address

    console.log(
      `
      Pre-deployed contracts:
      > $LIFE Contract Address: ${tokenAddress} 
      > MLIFE NFT Contract Address: ${nftAddress}
      > NFTi Contract Address: ${nftiAddress}
      `
    )

    // Get signer address
    ;[signerAddress] = await ethers.provider.listAccounts()
  })

  it("Should set the contract owner to equal the deployer address", async () => {
    assert.equal(await token.owner(), signerAddress)
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
})
