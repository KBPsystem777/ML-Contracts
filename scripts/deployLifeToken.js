require("@nomiclabs/hardhat-waffle")

const { ethers } = require("hardhat")
const hre = require("hardhat")

/*** This script will deploy all the contracts */
async function main() {
  const [deployer] = await ethers.getSigners()
  console.log("Deploying contracts using the account: " + deployer.address)

  // Deploy ML NFT
  const LIFE_TOKEN = await hre.ethers.getContractFactory("Life")
  const LIFE = await LIFE_TOKEN.deploy()
  await LIFE.deployed()

  console.log("LIFE_OPERATOR has been deployed to: " + LIFE.address)
}

// We recommend thxs pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error)
    process.exit(1)
  })
