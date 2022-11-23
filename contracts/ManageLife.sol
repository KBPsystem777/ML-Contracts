// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./Life.sol";
import "./Marketplace.sol";

// @title ManageLife NFT
// @notice NFT contract for ManageLife Platform
contract ManageLife is ERC721, ERC721URIStorage, ERC721Burnable, Ownable {
    uint256 private _tokenId = 1;
    Life private _lifeToken;
    Marketplace private _marketplace;

    /// @notice This is the wallet address where all property NFTs will be
    /// stored as soon as the property got vacated or returned to ML
    address public PROPERTY_CUSTODIAN;

    mapping(uint256 => uint256) private _lifeTokenIssuanceRate;
    mapping(uint256 => bool) private _fullyPayed;

    event FullyPayed(uint256 tokenId);
    event StakingIniatialized(uint256 tokenId);
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
        return "https://ml-api-dev.herokuapp.com/api/v1/nfts/";
    }

    function getBaseURI() external pure returns (string memory) {
        return _baseURI();
    }

    function setMarketplace(address payable marketplace_) external onlyOwner {
        _marketplace = Marketplace(marketplace_);
    }

    function marketplace() external view returns (address) {
        return address(_marketplace);
    }

    function setLifeToken(address lifeToken_) external onlyOwner {
        _lifeToken = Life(lifeToken_);
    }

    function lifeToken() external view returns (address) {
        return address(_lifeToken);
    }

    // Returns the issuance rate for a specif NFT id
    function lifeTokenIssuanceRate(uint256 tokenId)
        external
        view
        returns (uint256)
    {
        return _lifeTokenIssuanceRate[tokenId];
    }

    function fullyPayed(uint256 tokenId) public view returns (bool) {
        return _fullyPayed[tokenId];
    }

    // This will mark the property as paid
    function markFullyPayed(uint256 tokenId) external onlyOwner {
        _fullyPayed[tokenId] = true;
        // @notice Initialized staking for this tokenId if the tokenId is not owned by the contract owner
        if (owner() != ownerOf(tokenId)) {
            _lifeToken.claimStakingRewards(tokenId);
        }
        emit FullyPayed(tokenId);
    }

    function mint(uint256 propertyId, uint256 lifeTokenIssuanceRate_)
        external
        onlyOwner
    {
        require(address(_lifeToken) != address(0), "Life token is not set");
        uint256 tokenId = propertyId;
        require(!_exists(tokenId), "Error: TokenId already minted");
        _mint(owner(), propertyId);
        _lifeTokenIssuanceRate[tokenId] = lifeTokenIssuanceRate_;
    }

    // Burn an NFT
    function burn(uint256 tokenId) public override onlyOwner {
        _burn(tokenId);
    }

    function retract(uint256 tokenId) external onlyOwner {
        _safeTransfer(ownerOf(tokenId), owner(), tokenId, "");
    }

    /// @notice Function to return the property from the current owner to the custodian wallet.
    function returnProperty(uint256 tokenId) external {
        require(fullyPayed(tokenId), "Not fully paid. Transfers restricted");
        require(
            msg.sender == ownerOf(tokenId),
            "Transfer failed: You are not the owner of this property"
        );
        safeTransferFrom(msg.sender, PROPERTY_CUSTODIAN, tokenId, "");
    }

    // Give an access to an address for a specific NFT item.
    // Works like setApprovalForAll but for a specific NFT only
    function approve(address to, uint256 tokenId) public override {
        require(
            fullyPayed(tokenId) ||
                ownerOf(tokenId) == owner() ||
                to == address(_marketplace),
            "Approval restricted"
        );
        super.approve(to, tokenId);
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal override {
        require(
            fullyPayed(tokenId) ||
                from == owner() ||
                to == owner() ||
                msg.sender == address(_marketplace),
            "Transfers restricted"
        );
        if (!fullyPayed(tokenId)) {
            if (from == owner()) {
                _lifeToken.initStakingRewards(tokenId);
            }
            if (to == owner() && from != address(0)) {
                _lifeToken.claimStakingRewards(tokenId);
            }
        }
        super._beforeTokenTransfer(from, to, tokenId);
        emit StakingIniatialized(tokenId);
    }

    function _burn(uint256 tokenId)
        internal
        override(ERC721, ERC721URIStorage)
    {
        super._burn(tokenId);
    }

    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721, ERC721URIStorage)
        returns (string memory)
    {
        return super.tokenURI(tokenId);
    }

    /***
     * @notice Function to update the token issuance rate of an NFT
     * @param tokenId of an NFT
     * @param newLifeTokenIssuanceRate new issuance rate of the NFT
     */
    function updateLifeTokenIssuanceRate(
        uint256 tokenId,
        uint256 newLifeTokenIssuanceRate
    ) external onlyOwner {
        // TODO: Fix and the issue on OnlyOwner on L178-179
        if (_lifeToken.claimableStakingRewards(tokenId) > 1) {
            _lifeToken.claimStakingRewards(tokenId);
            _lifeToken.updateStartOfStaking(tokenId, 17444390400);
            _lifeTokenIssuanceRate[tokenId] = newLifeTokenIssuanceRate;
            _lifeToken.updateStartOfStaking(tokenId, uint64(block.timestamp));

            emit TokenIssuanceRateUpdated(tokenId, newLifeTokenIssuanceRate);
        }
    }

    /// @notice Function to change the property custodian wallet address.
    function updatePropertyCustodian(address _newPropertyCustodian)
        external
        onlyOwner
    {
        PROPERTY_CUSTODIAN = _newPropertyCustodian;
        emit PropertyCustodianUpdated(_newPropertyCustodian);
    }
}
