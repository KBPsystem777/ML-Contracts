// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "erc721a/contracts/ERC721A.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

import "./Life.sol";

// @title ManageLife Investor's NFT
// @notice This is the NFTi contract of ML
contract ManageLifeInvestorsNFT is ERC721A, Ownable {
    Life private _lifeToken;

    mapping(uint256 => uint256) private _lifeTokenIssuanceRate;
    mapping(uint256 => uint64) public _stakingRewards;
    mapping(uint256 => uint256) public _unlockDate;

    event BaseURIUpdated(string _newURIAddress);
    event BurningRateUpdated(uint256 newTokenBurningRate);
    event StakingClaimed(uint256 tokenId);
    event TokenBurned(address indexed burnFrom, uint256 amount);

    // Using temporary metadata from BAYC's IPFS metadatax
    string public baseURI = "https://ml-api-dev.herokuapp.com/api/v1/nfts/";

    // @notice Placeholder tokenBurning rate value. Equivalent to 7%
    uint256 public tokenBurningRate = 70000000000000000;

    event TokenIssuanceRateUpdates(
        uint256 indexed tokenId,
        uint256 newLifeTokenIssuanceRate
    );
    event StakingInitiated(uint256 indexed tokenId);
    event BurnedNft(uint256 tokenId);

    constructor() ERC721A("ManageLife Investors NFT", "NFTi") {}

    function mint(uint256 quantity) external onlyOwner {
        _safeMint(msg.sender, quantity);
    }

    function _baseURI() internal view override returns (string memory) {
        return baseURI;
    }

    // @notice Custom function to get the adderss of the NFT owner
    function ownerOfTokenId(uint256 tokenId) public view returns (address) {
        return ownerOf(tokenId);
    }

    function updateBaseURI(string memory _newURIAddress) external onlyOwner {
        baseURI = _newURIAddress;
        emit BaseURIUpdated(_newURIAddress);
    }

    function setLifeToken(address lifeToken_) external onlyOwner {
        _lifeToken = Life(lifeToken_);
    }

    function lifeToken() external view returns (address) {
        return address(_lifeToken);
    }

    function updateTokenBurningRate(
        uint256 newTokenBurningRate
    ) external onlyOwner {
        tokenBurningRate = newTokenBurningRate;
        emit BurningRateUpdated(newTokenBurningRate);
    }

    // @notice Returns the issuance rate for a specific NFT id
    // @param tokenId TokenId of the NFT
    function lifeTokenIssuanceRate(
        uint256 tokenId
    ) external view returns (uint256) {
        return _lifeTokenIssuanceRate[tokenId];
    }

    // @notice Function to update the rewards issuance rate of an NFT. Can only be called by the ML admins
    function updateLifeTokenIssuanceRate(
        uint256 tokenId,
        uint256 newLifeTokenIssuanceRate
    ) external onlyOwner {
        // Get first the accumulated reward of the NFTi
        _lifeToken.mintInvestorsRewards(
            ownerOf(tokenId),
            checkClaimableStakingRewards(tokenId)
        );

        // Reset the init of staking rewards to current time
        _stakingRewards[tokenId] = uint64(block.timestamp);

        // Once all rewards has been minted to the owner, reset the lifeTokenIssuance rate
        _lifeTokenIssuanceRate[tokenId] = newLifeTokenIssuanceRate;
        emit TokenIssuanceRateUpdates(tokenId, newLifeTokenIssuanceRate);
    }

    // @notice Function to initialize the staking rewards
    function initStakingRewards(uint256 tokenId) internal onlyOwner {
        require(
            address(_lifeToken) != address(0),
            "ManageLife Token is not set"
        );

        _stakingRewards[tokenId] = uint64(block.timestamp);
        emit StakingInitiated(tokenId);
    }

    // @notice Function to issue an NFT to investors for the first time. Should be used by ML admins only.
    // Admins will be able to set an initial issuance rate for the NFT and initiate their staking.
    // If the NFT has already an accumulated rewards, admins will not be able to transfer it to other address
    function issueNftToInvestor(
        address to,
        uint256 tokenId,
        uint256 lifeTokenIssuanceRate_
    ) external onlyOwner {
        _lifeTokenIssuanceRate[tokenId] = lifeTokenIssuanceRate_;
        safeTransferFrom(msg.sender, to, tokenId);
        // Setting lock up dates to 365 days (12 months) as default
        _unlockDate[tokenId] = uint64(block.timestamp) + 365 days;
        initStakingRewards(tokenId);
    }

    // @notice Function to check the claimable staking reward of an NFT
    function checkClaimableStakingRewards(
        uint256 tokenId
    ) public view returns (uint256) {
        return
            (uint64(block.timestamp) - _stakingRewards[tokenId]) *
            _lifeTokenIssuanceRate[tokenId];
    }

    /**
     * @notice  Claim $LIFE token staking rewards.
     * @dev The first require method makes sure that the msg.sender is the owner of the token. Second require makes sure that the one claiming is not the ML wallet.
     * Once the require statements passed, the rewards will be minted on the caller address. Once success, the timestamp of _stakingRewards for that tokenId will be reset.
     * @param   tokenId TokenId of the NFT.
     */
    function claimStakingRewards(uint256 tokenId) public {
        require(
            msg.sender == ownerOf(tokenId),
            "Only the owner of the tokenId can claim the rewards"
        );
        // Making sure that ML wallet will not claim the reward
        require(msg.sender != owner(), "Platform wallet cannot claim");

        _lifeToken.mintInvestorsRewards(
            msg.sender,
            checkClaimableStakingRewards(tokenId)
        );
        // Record new timestamp data to reset the staking rewards data
        _stakingRewards[tokenId] = uint64(block.timestamp);

        emit StakingClaimed(tokenId);
    }

    /**
     * @notice  Burn $LIFE token rewards from an NFTi holder.
     * @dev     Burn percentage if being managed from the frontend app.
     * @param   amount Calculated amount to be burned.
     * @param   tokenId TokenId of the NFT, will be used as param in access modifier.
     */
    function burnTokens(uint256 amount, uint256 tokenId) external {
        _lifeToken.burnLifeTokens(msg.sender, amount, tokenId);
        emit TokenBurned(msg.sender, amount);
    }

    // @notice Function to transfer an NFT to from one investor to another address.
    function transferNft(address to, uint256 tokenId) external {
        require(
            msg.sender == ownerOf(tokenId),
            "Error: You must be the owner of this NFT"
        );

        if (msg.sender == owner()) {
            safeTransferFrom(msg.sender, to, tokenId);
        } else {
            // Before transferring the NFT to new owner, make sure that NFT has finished it's locked up period
            require(
                block.timestamp >= _unlockDate[tokenId],
                "Error: NFT hasn't finished locked up period"
            );
            // If the NFT has a pending reward, it should be claimed first before transferring
            if (checkClaimableStakingRewards(tokenId) >= 0) {
                claimStakingRewards(tokenId);
            }
            safeTransferFrom(msg.sender, to, tokenId);
        }

        // If the locked up period has been completed, reset the time to unlock of the said NFT to default 365 days
        _unlockDate[tokenId] = uint64(block.timestamp) + 365 days;
    }

    // @notice Function for investors to return the NFT to ML admin wallet
    // The investor should also clear the lockup period of the NFT so that the admins can transfer it to anyone at anytime.
    function returnNftToML(uint256 tokenId) external {
        require(
            msg.sender == ownerOf(tokenId),
            "Error: You must be the owner of this NFT"
        );
        // If the NFT has a pending reward, it should be claimed first before transferring
        if (checkClaimableStakingRewards(tokenId) >= 0) {
            claimStakingRewards(tokenId);
        }
        // Resetting the unlock date to remove the 70days lock up period
        _unlockDate[tokenId] = block.timestamp;
        safeTransferFrom(msg.sender, owner(), tokenId);
    }

    /***
     * @notice Function to update the lockdate of an NFT
     * @param tokenId TokenId of an NFT
     * @param _newLockDate Unix timestamp of the new lock date
     */
    function setLockDate(
        uint256 tokenId,
        uint256 _newLockDate
    ) external onlyOwner {
        _unlockDate[tokenId] = _newLockDate;
    }

    /***
     * @notice Function to burn an NFTi
     * @param tokenId TokenId of an NFT
     */
    function burnNFt(uint256 tokenId) external onlyOwner {
        super._burn(tokenId);
        emit BurnedNft(tokenId);
    }

    /***
     * @notice Function to brute force retrieving the NFTi from a holder
     * @param tokenId TokenId of an NFT
     * Requirements:
     *  - The holder of an NFT should give an approval for all to the contract address,
     * in order for the function below to run successfully
     */
    function forceClaimNft(uint256 tokenId) external onlyOwner {
        super.transferFrom(ownerOfTokenId(tokenId), msg.sender, tokenId);
    }

    // @notice Checker to see if the token holder is an NFTi investor
    modifier onlyInvestor(uint256 tokenId) {
        require(msg.sender == ownerOf(tokenId), "Only for NFTIs owner");
        _;
    }
}
