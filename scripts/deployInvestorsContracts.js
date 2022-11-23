require("@nomiclabs/hardhat-waffle")

const { ethers } = require("hardhat")
const hre = require("hardhat")

async function main() {
  const [deployer] = await ethers.getSigners()
  console.log("Deploying contracts using the account: " + deployer.address)

  // Deploy ML token (ERC20)
  const investorsNFT = await hre.ethers.getContractFactory(
    "ManageLifeInvestorsNFT"
  )
  const InvNFT = await investorsNFT.deploy()
  await InvNFT.deployed()

  console.log("MLife Investor NFT has been deployed to:", InvNFT.address)
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error)
    process.exit(1)
  })
