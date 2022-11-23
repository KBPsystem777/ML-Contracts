# Solidity API

## Life

### _stakingRewards

```solidity
mapping(uint256 => uint64) _stakingRewards
```

### _manageLifeToken

```solidity
contract ManageLife _manageLifeToken
```

### _investorsNft

```solidity
contract ManageLifeInvestorsNFT _investorsNft
```

### burningRate

```solidity
uint256 burningRate
```

### constructor

```solidity
constructor() public
```

### pause

```solidity
function pause() external
```

### unpause

```solidity
function unpause() external
```

### setManageLifeToken

```solidity
function setManageLifeToken(address manageLifeToken_) external
```

### setNftiToken

```solidity
function setNftiToken(address investorsNft_) external
```

### manageLifeToken

```solidity
function manageLifeToken() external view returns (address)
```

### manageLifeInvestorsNft

```solidity
function manageLifeInvestorsNft() external view returns (address)
```

### initStakingRewards

```solidity
function initStakingRewards(uint256 tokenId) external
```

### claimableStakingRewards

```solidity
function claimableStakingRewards(uint256 tokenId) public view returns (uint256)
```

### batchClaimableStakingRewards

```solidity
function batchClaimableStakingRewards(uint256[] tokenIds) external view returns (uint256)
```

### burnLifeTokens

```solidity
function burnLifeTokens(address from, uint256 amount) external
```

### updateBurningRate

```solidity
function updateBurningRate(uint256 newBurningRate) external
```

### mint

```solidity
function mint(uint256 _amount) external
```

### mintInvestorsRewards

```solidity
function mintInvestorsRewards(uint256 _amount, uint256 tokenId) external
```

### claimStakingRewards

```solidity
function claimStakingRewards(uint256 tokenId) public
```

### batchClaimStakingRewards

```solidity
function batchClaimStakingRewards(uint256[] tokenIds) external
```

### onlyInvestor

```solidity
modifier onlyInvestor(uint256 tokenId)
```

## ManageLifeInvestorsNFT

### _lifeToken

```solidity
contract Life _lifeToken
```

### _lifeTokenIssuanceRate

```solidity
mapping(uint256 => uint256) _lifeTokenIssuanceRate
```

### _stakingRewards

```solidity
mapping(uint256 => uint64) _stakingRewards
```

### _unlockDate

```solidity
mapping(uint256 => uint256) _unlockDate
```

### BaseURIUpdated

```solidity
event BaseURIUpdated(string _newURIAddress)
```

### BurningRateUpdated

```solidity
event BurningRateUpdated(uint256 newTokenBurningRate)
```

### StakingClaimed

```solidity
event StakingClaimed(uint256 tokenId)
```

### baseURI

```solidity
string baseURI
```

### tokenBurningRate

```solidity
uint256 tokenBurningRate
```

### TokenIssuanceRateUpdates

```solidity
event TokenIssuanceRateUpdates(uint256 tokenId, uint256 newLifeTokenIssuanceRate)
```

### StakingInitiated

```solidity
event StakingInitiated(uint256 tokenId)
```

### constructor

```solidity
constructor() public
```

### mint

```solidity
function mint(uint256 quantity) external
```

### _baseURI

```solidity
function _baseURI() internal view returns (string)
```

_Base URI for computing {tokenURI}. If set, the resulting URI for each
token will be the concatenation of the `baseURI` and the `tokenId`. Empty
by default, it can be overridden in child contracts._

### ownerOfTokenId

```solidity
function ownerOfTokenId(uint256 tokenId) external view returns (address)
```

### updateBaseURI

```solidity
function updateBaseURI(string _newURIAddress) external
```

### setLifeToken

```solidity
function setLifeToken(address lifeToken_) external
```

### lifeToken

```solidity
function lifeToken() external view returns (address)
```

### updateTokenBurningRate

```solidity
function updateTokenBurningRate(uint256 newTokenBurningRate) external
```

### lifeTokenIssuanceRate

```solidity
function lifeTokenIssuanceRate(uint256 tokenId) external view returns (uint256)
```

### updateLifeTokenIssuanceRate

```solidity
function updateLifeTokenIssuanceRate(uint256 tokenId, uint256 newLifeTokenIssuanceRate) external
```

### initStakingRewards

```solidity
function initStakingRewards(uint256 tokenId) internal
```

### issueNftToInvestor

```solidity
function issueNftToInvestor(address to, uint256 tokenId, uint256 lifeTokenIssuanceRate_) external
```

### checkClaimableStakingRewards

```solidity
function checkClaimableStakingRewards(uint256 tokenId) public view returns (uint256)
```

### claimStakingRewards

```solidity
function claimStakingRewards(uint256 tokenId) public
```

### transferNft

```solidity
function transferNft(address to, uint256 tokenId) external
```

### returnNftToML

```solidity
function returnNftToML(uint256 tokenId) external
```

## ManageLife

### _tokenId

```solidity
uint256 _tokenId
```

### _lifeToken

```solidity
contract Life _lifeToken
```

### _marketplace

```solidity
contract Marketplace _marketplace
```

### PROPERTY_CUSTODIAN

```solidity
address PROPERTY_CUSTODIAN
```

This is the wallet address where all property NFTs will be
stored as soon as the property got vacated or returned to ML

### baseURI

```solidity
string baseURI
```

### _lifeTokenIssuanceRate

```solidity
mapping(uint256 => uint256) _lifeTokenIssuanceRate
```

### _fullyPayed

```solidity
mapping(uint256 => bool) _fullyPayed
```

### FullyPayed

```solidity
event FullyPayed(uint256 tokenId)
```

### StakingIniatialized

```solidity
event StakingIniatialized(uint256 tokenId)
```

### PropertyReturned

```solidity
event PropertyReturned(address from, uint256 tokenId)
```

### PropertyCustodianUpdated

```solidity
event PropertyCustodianUpdated(address newPropertyCustodian)
```

### TokenIssuanceRateUpdated

```solidity
event TokenIssuanceRateUpdated(uint256 token, uint256 newLifeTokenIssuanceRate)
```

### constructor

```solidity
constructor() public
```

### setMarketplace

```solidity
function setMarketplace(address payable marketplace_) external
```

### marketplace

```solidity
function marketplace() external view returns (address)
```

### setLifeToken

```solidity
function setLifeToken(address lifeToken_) external
```

### lifeToken

```solidity
function lifeToken() external view returns (address)
```

### lifeTokenIssuanceRate

```solidity
function lifeTokenIssuanceRate(uint256 tokenId) external view returns (uint256)
```

### fullyPayed

```solidity
function fullyPayed(uint256 tokenId) public view returns (bool)
```

### markFullyPayed

```solidity
function markFullyPayed(uint256 tokenId) external
```

### mint

```solidity
function mint(string uri, uint256 propertyId, uint256 lifeTokenIssuanceRate_) external
```

### burn

```solidity
function burn(uint256 tokenId) public
```

_Burns `tokenId`. See {ERC721-_burn}.

Requirements:

- The caller must own `tokenId` or be an approved operator._

### retract

```solidity
function retract(uint256 tokenId) external
```

### returnProperty

```solidity
function returnProperty(uint256 tokenId) external
```

Function to return the property from the current owner to the custodian wallet.

### approve

```solidity
function approve(address to, uint256 tokenId) public
```

_See {IERC721-approve}._

### _beforeTokenTransfer

```solidity
function _beforeTokenTransfer(address from, address to, uint256 tokenId) internal
```

_Hook that is called before any token transfer. This includes minting
and burning.

Calling conditions:

- When `from` and `to` are both non-zero, ``from``'s `tokenId` will be
transferred to `to`.
- When `from` is zero, `tokenId` will be minted for `to`.
- When `to` is zero, ``from``'s `tokenId` will be burned.
- `from` and `to` are never both zero.

To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks]._

### _burn

```solidity
function _burn(uint256 tokenId) internal
```

### tokenURI

```solidity
function tokenURI(uint256 tokenId) public view returns (string)
```

### updateBaseURI

```solidity
function updateBaseURI(string _newURIAddress) external
```

### updateLifeTokenIssuanceRate

```solidity
function updateLifeTokenIssuanceRate(uint256 tokenId, uint256 newLifeTokenIssuanceRate) external
```

### updatePropertyCustodian

```solidity
function updatePropertyCustodian(address _newPropertyCustodian) external
```

Function to change the property custodian wallet address.

## Marketplace

### PERCENTS_DIVIDER

```solidity
uint256 PERCENTS_DIVIDER
```

### mLife

```solidity
contract ManageLife mLife
```

### Offer

```solidity
struct Offer {
  bool isForSale;
  uint256 id;
  address seller;
  uint256 minValue;
  address onlySellTo;
}
```

### Bid

```solidity
struct Bid {
  uint256 id;
  address bidder;
  uint256 value;
}
```

### adminPercent

```solidity
uint256 adminPercent
```

### adminPending

```solidity
uint256 adminPending
```

### offers

```solidity
mapping(uint256 => struct Marketplace.Offer) offers
```

### bids

```solidity
mapping(uint256 => struct Marketplace.Bid) bids
```

### Offered

```solidity
event Offered(uint256 id, uint256 minValue, address toAddress)
```

### BidEntered

```solidity
event BidEntered(uint256 id, uint256 value, address fromAddress)
```

### BidWithdrawn

```solidity
event BidWithdrawn(uint256 id, uint256 value)
```

### BidCancelled

```solidity
event BidCancelled(uint256 id, uint256 value, address bidder)
```

### Bought

```solidity
event Bought(uint256 id, uint256 value, address fromAddress, address toAddress, bool isInstant)
```

### Cancelled

```solidity
event Cancelled(uint256 id)
```

### FreeMarket

```solidity
event FreeMarket(bool isFreeMarket)
```

### constructor

```solidity
constructor() public
```

### pause

```solidity
function pause() external
```

### unpause

```solidity
function unpause() external
```

### mlifeAddress

```solidity
function mlifeAddress() external view returns (address)
```

### setContract

```solidity
function setContract(address newAddress) external
```

### setAdminPercent

```solidity
function setAdminPercent(uint256 _percent) external
```

### withdraw

```solidity
function withdraw() external
```

### cancelForSale

```solidity
function cancelForSale(uint256 id) external
```

### offerForSale

```solidity
function offerForSale(uint256 id, uint256 minSalePrice) external
```

### offerForSaleToAddress

```solidity
function offerForSaleToAddress(uint256 id, uint256 minSalePrice, address toAddress) external
```

### buy

```solidity
function buy(uint256 id) external payable
```

### placeBid

```solidity
function placeBid(uint256 id) external payable
```

### acceptBid

```solidity
function acceptBid(uint256 id, uint256 minPrice) external
```

### withdrawBid

```solidity
function withdrawBid(uint256 id) external
```

### receive

```solidity
receive() external payable
```

### _safeTransferETH

```solidity
function _safeTransferETH(address to, uint256 value) internal
```

### onlyMLifeOwner

```solidity
modifier onlyMLifeOwner(uint256 tokenId)
```

