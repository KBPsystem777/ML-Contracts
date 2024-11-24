require("@nomiclabs/hardhat-waffle")
require("@nomiclabs/hardhat-etherscan")
require("solidity-docgen")

require("dotenv").config()

module.exports = {
  solidity: "0.8.24",
  docgen: {
    outputDir: "./",
  },
  networks: {
    local: {
      url: "http://127.0.0.1:8545",
      accounts: [process.env.REACT_APP_PRIVATE_KEY],
    },
    ropsten: {
      url: process.env.REACT_APP_ROPSTEN_URL,
      accounts: [process.env.REACT_APP_PRIVATE_KEY],
    },
    mumbai: {
      url: process.env.REACR_APP_MUMBAI_URL,
      accounts: [process.env.REACT_APP_PRIVATE_KEY],
    },
    rinkeby: {
      url: process.env.REACT_APP_RINKEBY_URL,
      accounts: [process.env.REACT_APP_PRIVATE_KEY],
    },
    goerli: {
      url: process.env.REACT_APP_GOERLI_URL,
      accounts: [process.env.REACT_APP_PRIVATE_KEY],
    },
    sepolia: {
      url: process.env.REACT_APP_SEPOLIA_URL,
      accounts: [process.env.REACT_APP_PRIVATE_KEY],
    },
    holesky: {
      url: process.env.REACT_APP_HOLESKY_URL,
      accounts: [process.env.REACT_APP_PRIVATE_KEY],
    },
    mainnet: {
      url: process.env.REACT_APP_ETH_URL,
      accounts: [process.env.REACT_APP_PRIVATE_KEY],
    },
    polygon: {
      url: process.env.REACT_APP_POLYGON_URL,
      accounts: [process.env.REACT_APP_PRIVATE_KEY],
    },
  },
  etherscan: {
    //apiKey: process.env.REACT_APP_POLYGONSCAN_KEY, // Change if changing networks
    apiKey: process.env.REACT_APP_ETHERSCAN_KEY,
  },
}
