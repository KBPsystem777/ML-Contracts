// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./Life.sol";
import "./Marketplace.sol";

/**
 * @notice ManageLife Member NFT (ERC-721) contract for ManageLife Members.
 * An NFT represents a membership or home ownership in real life.
 * Properties are all being managed by ManageLife.
 * NFT Symbol: MLRE
 *
 * @author https://managelife.io
 */
contract ManageLife is ERC721, ERC721URIStorage, ERC721Burnable, Ownable {
    Life public lifeToken;
    Marketplace public marketplace;

    /// @notice Mapping to get the issuance rate of a tokenId (propery).
    mapping(uint256 => uint256) public lifeTokenIssuanceRate;

    /// @notice Mapping to check the payment status of a tokenId.
    mapping(uint256 => bool) public fullyPaid;

    event FullyPaid(uint256 tokenId);
    event StakingInitialized(uint256 tokenId);
    event TokenIssuanceRateUpdated(
        uint256 token,
        uint256 newLifeTokenIssuanceRate
    );
    event PropertyRetracted(
        address _currentOwner,
        address _admin,
        uint256 _tokenId
    );
    event BaseURIUpdated(string _newURIAddress);

    constructor() ERC721("ManageLife Member", "MLRE") {}

    /// @notice Public base URI of ML's NFTs
    string public baseUri = "https://api.managelife.io/api/v1/nft/";

    function _baseURI() internal view virtual override returns (string memory) {
        return baseUri;
    }

    /**
     * @notice Function to change the base URI of the NFTs.
     * @dev Giving the ML Admins an options in the future to change the URI of NFTs.
     * @param newBaseUri New URI string.
     */
    function setBaseURI(string memory newBaseUri) external onlyOwner {
        baseUri = newBaseUri;
        emit BaseURIUpdated(newBaseUri);
    }

    /**
     * @notice Function to set the Marketplace contract address.
     * @dev Very important to set this after contract deployment.
     * @param marketplace_ Address of the marketplace contract.
     */
    function setMarketplace(address payable marketplace_) external onlyOwner {
        marketplace = Marketplace(marketplace_);
    }

    /**
     * @notice Function to set the $MLIFE token contract address.
     * @dev Very important to set this after contract deployment.
     * @param lifeToken_ Address of the $MLIFE token contract.
     */
    function setLifeToken(address lifeToken_) external onlyOwner {
        lifeToken = Life(lifeToken_);
    }

    /**
     * @notice Mark an NFT or property fully paid from all mortgages at ML.
     * @dev This can only be executed by the contract deployer or admin wallet.
     * @param _tokenId TokenId of the NFT.
     */
    function markFullyPaid(uint256 _tokenId) external onlyOwner {
        fullyPaid[_tokenId] = true;

        /// @notice Staking for this property will be initialized if this is not owned by admin wallet.
        if (owner() != ownerOf(_tokenId)) {
            lifeToken.initStakingRewards(_tokenId);
        }
        emit FullyPaid(_tokenId);
    }

    /**
     * @notice Function to mint new NFT properties.
     *
     * @dev Property ID will be the property number provided by the ML-NFT-API service.
     * Life token issuance rate will be populated by the web3 admin from the portal app.
     *
     * @param _propertyId Property ID of the NFT. This will be provided by the web3 admin app.
     * @param _lifeTokenIssuanceRate Issuance rate percentage that is based on mortgage payments maintained by ML.
     */
    function mint(
        uint256 _propertyId,
        uint256 _lifeTokenIssuanceRate
    ) external onlyOwner {
        uint256 tokenId = _propertyId;
        require(address(lifeToken) != address(0), "Life token is not set");
        require(!isTokenMinted(tokenId), "Error: TokenId already minted");
        lifeTokenIssuanceRate[tokenId] = _lifeTokenIssuanceRate;
        _mint(owner(), tokenId);
    }

    /**
     * @notice Burn an NFT. Typical use case is remove an property from ML's custody.
     * @dev Can only be executed by the admin/deployer wallet.
     * @param tokenId TokenId of the NFT to be burned.
     */
    function burn(uint256 tokenId) public override onlyOwner {
        _burn(tokenId);
    }

    /**
     * @notice Admin wallet to retract a property (NFT) from a customer.
     * @dev Use case is the admin wallet needs to force claim an NFT from a customer.
     * @param _tokenId TokenId of the property that needs to be retracted.
     */
    function retract(uint256 _tokenId) external onlyOwner {
        address currentOwner = ownerOf(_tokenId);
        require(currentOwner != address(0), "Token not owned by current owner");
        _safeTransfer(currentOwner, owner(), _tokenId, "");
        emit PropertyRetracted(currentOwner, owner(), _tokenId);
    }

    /**
     * @notice Homeowners or NFT holders to return a property to ML wallet.
     * @dev This will fail if the caller is not the owner of the NFT.
     * @param _tokenId TokenId of the NFT to be returned.
     */
    function returnProperty(uint256 _tokenId) external {
        require(msg.sender == ownerOf(_tokenId), "Caller is not the owner");
        safeTransferFrom(msg.sender, owner(), _tokenId, "");
    }

    /**
     * @notice Allow homeowners/NFT holders to approve a 3rd party account
     * to perform transactions on their behalf.
     *
     * @dev This works like setApprovalForAll. The owner is giving ownership of their NFT.
     * Use case of this is an ML customer who would like to give an access to anyone to
     * use the home/property.
     * Requirements in order to make sure this call will succeed:
     * - The property should be fully paid.
     * - Function caller should be the ml admin deployer wallet.
     * - Receiver should be the Marketplace contract address.
     *
     * @param to Wallet address who will be granted with the above permission.
     * @param tokenId TokenId of the NFT.
     */
    function approve(address to, uint256 tokenId) public override {
        require(
            fullyPaid[tokenId] ||
                ownerOf(tokenId) == owner() ||
                to == address(marketplace),
            "Approval restricted"
        );
        super.approve(to, tokenId);
    }

    /**
     * @notice Transfer hooks. The functions inside will be executed as soon as the
     * concerned NFT is being transferred.
     *
     * @dev Operations inside this hook will be accomplished
     * if either of the checks below were accomplished:
     * - Customers cannot be able to transfer their NFTs if they are not yet fully paid.
     * - Sender is the contract owner.
     * - Receiver is the contract owner.
     * - Caller of this function is the Marketplace contract address.
     *
     * @param from Sender of the NFT.
     * @param to Receiver of the NFT.
     * @param tokenId TokenId of the NFT.
     */
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal override {
        // @note We are preventing nfts that are not full paid yet to be transferred to another address
        // @note Allowed transfers are only from admin to users and users to admin
        require(
            fullyPaid[tokenId] ||
                from == owner() ||
                to == owner() ||
                msg.sender == address(marketplace),
            "Transfers restricted"
        );

        // @note Staking will be initialized only if the sender of the nft is the admin wallet and nft is not yet paid fully
        if (from == owner() && !fullyPaid[tokenId]) {
            lifeToken.initStakingRewards(tokenId);
            emit StakingInitialized(tokenId);
        }

        // @note If the nft is returned to the admin wallet, generated staking rewards will be released
        if (to == owner() && from != address(0)) {
            lifeToken.claimStakingRewards(tokenId);
        }

        // @note Initialize the staking, if nft is fully paid. We're also allowing users here to transfer
        // the nft to any address since the nft has been fully paid.
        if (fullyPaid[tokenId] && from != owner()) {
            lifeToken.initStakingRewards(tokenId);
        }

        super._beforeTokenTransfer(from, to, tokenId);
    }

    function _burn(
        uint256 tokenId
    ) internal override(ERC721, ERC721URIStorage) {
        super._burn(tokenId);
    }

    /**
     * @notice Query the tokenURI of an NFT.
     * @param tokenId TokenId of an NFT to be queried.
     * @return  string - API address of the NFT's metadata
     */
    function tokenURI(
        uint256 tokenId
    ) public view override(ERC721, ERC721URIStorage) returns (string memory) {
        return super.tokenURI(tokenId);
    }

    /***
     * @notice Function to check if a token has already been minted.
     * @param _tokenId TokenId of an NFT to be queried
     * @return bool - Boolean result
     */
    function isTokenMinted(uint256 _tokenId) public view returns (bool) {
        return ownerOf(_tokenId) != address(0);
    }

    /***
     * @notice Function to update the token issuance rate of an NFT
     * @dev Issuance rate are being maintained by the ML admins.
     * @param tokenId of an NFT
     * @param newLifeTokenIssuanceRate new issuance rate of the NFT
     */
    function updateLifeTokenIssuanceRate(
        uint256 tokenId,
        uint256 newLifeTokenIssuanceRate
    ) external onlyOwner {
        lifeToken.claimStakingRewards(tokenId);
        lifeTokenIssuanceRate[tokenId] = newLifeTokenIssuanceRate;
        lifeToken.updateStartOfStaking(tokenId, uint64(block.timestamp));
        emit TokenIssuanceRateUpdated(tokenId, newLifeTokenIssuanceRate);
    }
}
