// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "./ManageLife.sol";
import "./MLInvestorsNFT.sol";

// @title $LIFE token contract for ManageLife.co
// @notice Contract for $LIFE token that handles token staking rewards
contract Life is ERC20, Ownable, Pausable {
    mapping(uint256 => uint64) public startOfStakingRewards;
    ManageLife private _manageLifeToken;
    ManageLifeInvestorsNFT private _investorsNft;

    uint256 public burningRate = 70000000000000000;

    constructor() ERC20("Life", "LIFE") {
        _mint(msg.sender, 7000000 * 10 ** decimals());
    }

    // @notice Adding emergency security features: Pause smart contracts transactions
    function pause() external whenNotPaused onlyOwner {
        _pause();
    }

    function unpause() external whenPaused onlyOwner {
        _unpause();
    }

    // @dev IMPORTANT: Set the NFT contract after deployment
    function setManageLifeToken(
        address manageLifeToken_
    ) external onlyOwner whenNotPaused {
        _manageLifeToken = ManageLife(manageLifeToken_);
    }

    function setNftiToken(
        address investorsNft_
    ) external onlyOwner whenNotPaused {
        _investorsNft = ManageLifeInvestorsNFT(investorsNft_);
    }

    function manageLifeToken() external view returns (address) {
        return address(_manageLifeToken);
    }

    function manageLifeInvestorsNft() external view returns (address) {
        return address(_investorsNft);
    }

    // @notice Only ManageLife NFT and NFTi contract addresses can call this function
    function initStakingRewards(uint256 tokenId) external whenNotPaused {
        require(
            address(_manageLifeToken) != address(0),
            "ManageLife token is not set"
        );
        // Making sure the one who will trigger this function are only ManageLife NFT and NFTi contracts:
        require(
            msg.sender == address(_manageLifeToken),
            "Only ManageLife token"
        );
        startOfStakingRewards[tokenId] = uint64(block.timestamp);
    }

    function updateStartOfStaking(
        uint256 tokenId,
        uint64 newStartDate
    ) external {
        require(
            msg.sender == owner() || msg.sender == address(_manageLifeToken),
            "Ony admins can execute this operation"
        );
        startOfStakingRewards[tokenId] = newStartDate;
    }

    // @notice Check the claimable @LIFE token reward of an NFT
    // @param tokenId The tokenId of the NFT on which the staking reward will be claimed
    function claimableStakingRewards(
        uint256 tokenId
    ) public view returns (uint256) {
        if (uint64(block.timestamp) < startOfStakingRewards[tokenId]) {
            return 0;
        }
        return
            (uint64(block.timestamp) - startOfStakingRewards[tokenId]) *
            _manageLifeToken.lifeTokenIssuanceRate(tokenId);
    }

    /**
     * @notice  Burns $LIFE token from a sender's account.
     * @param   from Address to where to burn LIFE tokens from.
     * @param   amount Amount to burn.
     * @param   tokenId TokenID of the NFT. This will be used as a param for access modifier.
     */
    function burnLifeTokens(
        address from,
        uint256 amount,
        uint256 tokenId
    ) external onlyMembers(tokenId) {
        _burn(from, amount);
    }

    function updateBurningRate(uint256 newBurningRate) external onlyOwner {
        burningRate = newBurningRate;
    }

    // @notice Function to mint new token supply
    function mint(uint256 _amount) external onlyOwner {
        _mint(msg.sender, _amount);
    }

    // @notice Function for NFTi to claim their rewards. This function will be called once the investor claimed their staking rewards.
    function mintInvestorsRewards(
        address investorAddress,
        uint256 _amount
    ) external {
        _mint(investorAddress, _amount);
    }

    // @dev Change this to make sure that the only people who
    // can run this function are those who own a rewards
    function claimStakingRewards(uint256 tokenId) public whenNotPaused {
        // @note In order to claim reward, the ManageLife NFT contract should be set first
        require(
            address(_manageLifeToken) != address(0),
            "ManageLife token is not set"
        );
        // @note The deployer address of this contract should not
        // be the owner of the reward that is being claimed
        require(
            _manageLifeToken.ownerOf(tokenId) != owner(),
            "PlatformWallet cannot claim"
        );

        if (
            msg.sender == owner() ||
            msg.sender == _manageLifeToken.ownerOf(tokenId) ||
            msg.sender == address(_manageLifeToken)
        ) {
            // If the answer on the above questions are true,
            // mint new ERC20 $LIFE tokens. Claimable amount will be minted on the property owner
            // At the same time a percentage of the claimed reward will be burned as well
            _mint(
                _manageLifeToken.ownerOf(tokenId),
                claimableStakingRewards(tokenId)
            );
        }
    }

    /**
     * @notice  Custom access modifier to make sure that the caller of transactions are member of ML.
     * @dev     This identifies if the caller is an investor or NFTi holder.
     * @param   tokenId  TokenId of the NFT that needs to be checked.
     */
    modifier onlyMembers(uint256 tokenId) {
        require(
            msg.sender == _manageLifeToken.ownerOf(tokenId) ||
                msg.sender == _investorsNft.ownerOf(tokenId),
            "Only home owner and investors can execute this"
        );
        _;
    }
}
