// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./Life.sol";
import "./Marketplace.sol";

/**
 * @notice NFT (ERC-721) contract for ManageLife Homeowners.
 * An NFT represents a property or home ownership in real life.
 * Properties are all being managed by ManageLife.
 * NFT Symbol: MLIFE
 *
 * @author https://managelife.co
 */
contract ManageLife is ERC721, ERC721URIStorage, ERC721Burnable, Ownable {
    Life public lifeToken;
    Marketplace public marketplace;

    /**
     * @notice This is the wallet address where all property NFTs will be
     * stored as soon as the property got vacated or returned to ML.
     */
    address public PROPERTY_CUSTODIAN;

    /// Mapping to get the issuance rate of a tokenId (propery).
    mapping(uint256 => uint256) public lifeTokenIssuanceRate;

    /// Mapping to check the payment status of a tokenId.
    mapping(uint256 => bool) private _fullyPaid;

    event FullyPaid(uint256 tokenId);
    event StakingInitialized(uint256 tokenId);
    event PropertyReturned(address indexed from, uint256 tokenId);
    event PropertyCustodianUpdated(address newPropertyCustodian);
    event TokenIssuanceRateUpdated(
        uint256 token,
        uint256 newLifeTokenIssuanceRate
    );

    constructor() ERC721("ManageLife", "MLIFE") {
        PROPERTY_CUSTODIAN = msg.sender;
    }

    function _baseURI() internal pure override returns (string memory) {
        return "https://iweb3api.managelifeapi.co/api/v1/nfts/";
    }

    /**
     * @notice Return the base URI of NFT metadata.
     * @dev Returns the API address where the metadata are stored.
     * @return  string
     */
    function baseURI() external pure returns (string memory) {
        return _baseURI();
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
     * @notice Function to set the @LIFE token contract address.
     * @dev Very important to set this after contract deployment.
     * @param lifeToken_ Address of the $LIFE token contract.
     */
    function setLifeToken(address lifeToken_) external onlyOwner {
        lifeToken = Life(lifeToken_);
    }

    /**
     * @notice Function to check if a property (NFT) is fully paid from mortgages at ML.
     * @param tokenId TokenId of the NFT property to be checked.
     * @return  bool - will return true/false.
     */
    function fullyPaid(uint256 tokenId) public view returns (bool) {
        return _fullyPaid[tokenId];
    }

    /**
     * @notice Mark an NFT or property fully paid from all mortgages at ML.
     * @dev This can only be executed by the contract deployer or admin wallet.
     * @param tokenId TokenId of the NFT.
     */
    function markFullyPaid(uint256 tokenId) external onlyOwner {
        _fullyPaid[tokenId] = true;

        /// @notice Staking for this property will be initialized if this is not owned by admin wallet.
        if (owner() != ownerOf(tokenId)) {
            lifeToken.claimStakingRewards(tokenId);
        }
        emit FullyPaid(tokenId);
    }

    /**
     * @notice Function to mint new NFT properties.
     *
     * @dev Property ID will be the property number provided by the ML-NFT-API service.
     * Life token issuance rate will be populated by the web3 admin from the portal app.
     *
     * @param propertyId Property ID of the NFT. This will be provided by the FrontEnd app.
     * @param lifeTokenIssuanceRate_ Issuance rate percentage that is based on morgage payments maintained by ML.
     */
    function mint(
        uint256 propertyId,
        uint256 lifeTokenIssuanceRate_
    ) external onlyOwner {
        require(address(lifeToken) != address(0), "Life token is not set");
        uint256 tokenId = propertyId;
        require(!_exists(tokenId), "Error: TokenId already minted");
        _mint(owner(), propertyId);
        lifeTokenIssuanceRate[tokenId] = lifeTokenIssuanceRate_;
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
     * @param tokenId TokenId of the property that needs to be retrackted.
     */
    function retract(uint256 tokenId) external onlyOwner {
        _safeTransfer(ownerOf(tokenId), owner(), tokenId, "");
    }

    /**
     * @notice Homeowners or NFT holders to return a property to ML wallet.
     * @dev This will fail if the caller is not the owner of the NFT.
     * @param tokenId TokenId of the NFT to be returned.
     */
    function returnProperty(uint256 tokenId) external {
        require(
            msg.sender == ownerOf(tokenId),
            "Transfer failed: You are not the owner of this property"
        );
        safeTransferFrom(msg.sender, PROPERTY_CUSTODIAN, tokenId, "");
    }

    /**
     * @notice Allow homeowners/NFT holders to approve a 3rd party account
     * to perform transactions on their behalf.
     *
     * @dev This works like setApprovalForAll. The owner is giving ownership wo their NFT.
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
            fullyPaid(tokenId) ||
                ownerOf(tokenId) == owner() ||
                to == address(marketplace),
            "Approval restricted"
        );
        super.approve(to, tokenId);
    }

    /**
     * @notice Transfer hooks. The functions inside will be executed as soon as the
     * concerned NFT is being trasnferred.
     *
     * @dev Operations inside this hook will be accomplished
     * if either of the checks below were accomplished:
     * - Customers cannot be able to transfer their NFTs if they are not yet fully paid.
     * - Sender is the contract owner.
     * - Receiver is the contract owner.
     * - Caller of thid function is the Marketplace contract address.
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
        require(
            fullyPaid(tokenId) ||
                from == owner() ||
                to == owner() ||
                msg.sender == address(marketplace),
            "Transfers restricted"
        );
        if (!fullyPaid(tokenId)) {
            /// @dev If the sender of the NFT is contract owner, staking will be initiated.
            if (from == owner()) {
                lifeToken.initStakingRewards(tokenId);
            }
            /** @dev If the user will return the NFT to the contract owner,
             * all the accumulated staking rewards will be claimed first.
             */
            if (to == owner() && from != address(0)) {
                lifeToken.claimStakingRewards(tokenId);
            }
        }
        emit StakingInitialized(tokenId);

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

    /**
     * @notice Update the property custodian.
     *
     * @dev New address set here will be the new owner of all returned NFTs/properties.
     * Will emit PropertyCustodianUpdated event.
     *
     * @param _newPropertyCustodian Wallet address of the new property custodian.
     */
    function updatePropertyCustodian(
        address _newPropertyCustodian
    ) external onlyOwner {
        PROPERTY_CUSTODIAN = _newPropertyCustodian;
        emit PropertyCustodianUpdated(_newPropertyCustodian);
    }
}
