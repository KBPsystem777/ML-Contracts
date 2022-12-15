# Solidity API

## Life

An ERC-20 contract for ManageLife.
Token Symbol: LIFE ($LIFE)
This contract manages token rewards issued to ManageLife homeowners and investors.
This contract also handles native token functions (EIP20 Token Standard).

### startOfStakingRewards

```solidity
mapping(uint256 => uint64) startOfStakingRewards
```

Mapping to get the start of staking for each NFTs.
Start of stake data is in UNIX timestamp form.

### _manageLifeToken

```solidity
contract ManageLife _manageLifeToken
```

Instance of the MLIFE NFT contract

### _investorsNft

```solidity
contract ManageLifeInvestorsNFT _investorsNft
```

Instance of the NFTi contract

### constructor

```solidity
constructor(uint256 initialSupply) public
```

Set initial token supply before deploying.

### pause

```solidity
function pause() external
```

Security feature to Pause smart contracts transactions

### unpause

```solidity
function unpause() external
```

Unpausing the Paused transactions feature.

### setManageLifeToken

```solidity
function setManageLifeToken(address manageLifeToken_) external
```

Set the MLIFE's NFT contract address.

_Important to set this after deployment._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| manageLifeToken_ | address | Address of the MLIFE NFT contract |

### setNftiToken

```solidity
function setNftiToken(address investorsNft_) external
```

Set the NFTi contract address.

_Important to set this after deployment._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| investorsNft_ | address | Contract address of NFTi contract. |

### manageLifeToken

```solidity
function manageLifeToken() external view returns (address)
```

Return the MLIFE's contract address.

_If set, this will return the MLIFE contract address_

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| [0] | address | address  . |

### manageLifeInvestorsNft

```solidity
function manageLifeInvestorsNft() external view returns (address)
```

Return the NFTi's contract address.

_If set, this will return the NFTi contract address._

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| [0] | address | address  . |

### initStakingRewards

```solidity
function initStakingRewards(uint256 tokenId) external
```

Initialize the Staking for an NFT.

_Reverts if the caller is not the MLIFE contract address,
MLIFE contact address is not set and if the contract is on-paused status._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| tokenId | uint256 | TokenId of the NFT to start stake. |

### updateStartOfStaking

```solidity
function updateStartOfStaking(uint256 tokenId, uint64 newStartDate) external
```

Update the start of stake of an NFT.

_Since staking reward is based on time, this function will
reset the stake start of an NFT that just recently claimed a token reward.
This will be also an on-demand operation where the admins needs to reset
the start of stake of an NFT, based off UNIX time._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| tokenId | uint256 | TokenID of an NFT. |
| newStartDate | uint64 | New start of stake of an NFT. This param should be based on UNIX timestamp and into uint64 type. |

### claimableStakingRewards

```solidity
function claimableStakingRewards(uint256 tokenId) public view returns (uint256)
```

Returns the claimable $LIFE token of an NFT.

_MLIFE contract is dependent on this function in calculating
the estimated staking rewards of an MLIFE.
Formula in calculating the reward:
Rewards = Current timestamp - StartOfStake timestamp * Life token issuance rate._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| tokenId | uint256 | MLIFE's tokenId. |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| [0] | uint256 | uint256 |

### burnLifeTokens

```solidity
function burnLifeTokens(address from, uint256 amount, uint256 tokenId) external
```

Burns $LIFE token from a sender's account.

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| from | address | Address to where to burn LIFE tokens from. |
| amount | uint256 | Amount to burn. |
| tokenId | uint256 | TokenID of the NFT. This will be used as a param for access modifier. |

### mint

```solidity
function mint(uint256 _amount) external
```

Function to mint additional token supply.

_Newly minted amount will be credited to the contract owner._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| _amount | uint256 | Additional amount to be minted. |

### mintInvestorsRewards

```solidity
function mintInvestorsRewards(address investorAddress, uint256 _amount) external
```

Mint $LIFE token rewards for NFTi Investors.

_NFTi contract depends on this function to mint $LIFE
token rewards to investors. Newly minted tokens here will be
credited directly to the investor's wallet address and NOT on the admin wallet._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| investorAddress | address | Wallet address of the investor. |
| _amount | uint256 | Amount to be minted on the investor's address. Amount is based on the calculated staking rewards from NFTi contract. |

### claimStakingRewards

```solidity
function claimStakingRewards(uint256 tokenId) public
```

Claim $LIFE token staking rewards.

_MLIFE's rewards issuance is reliant on this function.
Once the user claim the rewards, this function will mint the
tokens directly on the homeowner's wallet.
Notes:
- ML's admin or deployer wallet cannot claim $LIFE rewards.
- Setting the MLIFE contract address is prerequisite in running this function.
- This function can only be called by MLIFE holders.
- A percentage of the token reward will be burned. Percentage will be determined by the ML admin.
- Burn call will be handled separately by the frontend app._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| tokenId | uint256 | MLIFE's tokenId. |

### onlyMembers

```solidity
modifier onlyMembers(uint256 tokenId)
```

Custom access modifier to make sure that the caller of transactions are member of ML.

_This identifies if the caller is an investor or NFTi holder._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| tokenId | uint256 | TokenId of the NFT that needs to be checked. |

## ManageLifeInvestorsNFT

NFTi (ERC-721) contract for ManageLife Investors.
Owning this NFT represents a investment in ManageLife's properties in real life.
NFT Symbol: NFTi

### lifeToken

```solidity
contract Life lifeToken
```

Life token instance

### _lifeTokenIssuanceRate

```solidity
mapping(uint256 => uint256) _lifeTokenIssuanceRate
```

Mapping of NFTi tokenId to their issuance rates

### stakingRewards

```solidity
mapping(uint256 => uint64) stakingRewards
```

Mapping of NFTi tokenId to their start of staking

### unlockDate

```solidity
mapping(uint256 => uint256) unlockDate
```

Mapping of NFTi tokenId to their unlock dates

### BaseURIUpdated

```solidity
event BaseURIUpdated(string _newURIAddress)
```

### StakingClaimed

```solidity
event StakingClaimed(uint256 tokenId)
```

### TokenBurned

```solidity
event TokenBurned(address burnFrom, uint256 amount)
```

### TokenIssuanceRateUpdates

```solidity
event TokenIssuanceRateUpdates(uint256 tokenId, uint256 newLifeTokenIssuanceRate)
```

### StakingInitiated

```solidity
event StakingInitiated(uint256 tokenId)
```

### BurnedNft

```solidity
event BurnedNft(uint256 tokenId)
```

### constructor

```solidity
constructor() public
```

### mint

```solidity
function mint(uint256 quantity) external
```

Mint new NFTis.

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| quantity | uint256 | Number of NFTis to be minted. |

### _baseURI

```solidity
function _baseURI() internal pure returns (string)
```

Setting the baseURI of NFTi metadata.

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| [0] | string | string |

### baseURI

```solidity
function baseURI() external pure returns (string)
```

Query the baseURI of NFTi

_Will return the API address where the metadata are stored._

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| [0] | string | string |

### setLifeToken

```solidity
function setLifeToken(address lifeToken_) external
```

Set the Life token contract address.

_Important to set this after deployment in order to build integration with
the ERC20 contract._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| lifeToken_ | address | $LIFE token contract address. |

### lifeTokenIssuanceRate

```solidity
function lifeTokenIssuanceRate(uint256 tokenId) external view returns (uint256)
```

Query the life token issuance rate of an NFTi.

_Default token issuance rate of NFTi is set by admins once the NFTi is
issued to investor. Issuance rates varies per NFTi and is maintained by ML admins._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| tokenId | uint256 | NFTi's tokenId. |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| [0] | uint256 | uint256 |

### updateLifeTokenIssuanceRate

```solidity
function updateLifeTokenIssuanceRate(uint256 tokenId, uint256 newLifeTokenIssuanceRate) external
```

Update life token issuance rate of an NFTi.

_Updated issuance rate will be provided manually by ML admins.
If an NFTi has an accumulated rewards already, the reward will be transferred
first to the holder before updating the issuance rate._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| tokenId | uint256 | NFTi's tokenId. |
| newLifeTokenIssuanceRate | uint256 | New issuance rate as provided by ML admins. |

### initStakingRewards

```solidity
function initStakingRewards(uint256 tokenId) internal
```

Initialize the staking reward for an NFTi.

_This will be triggered by the transfer hook and requires that
the MLIFE contract should be set._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| tokenId | uint256 | TokenId of NFTi to be set. |

### issueNftToInvestor

```solidity
function issueNftToInvestor(address to, uint256 tokenId, uint256 lifeTokenIssuanceRate_) external
```

Function to issue an NFT to investors for the first time. Should be used by ML admins only.

_Admins will be able to set an initial issuance rate for the NFT and initiate their staking.
If the NFT has already an accumulated rewards, admins will not be able to transfer it to other address.
Once this has been issued to an investor, the NFTi will be locked up by default for 1 year. At this period,
the NFTi will not be able to be transfer to any contract or wallet address. Lock up period can be updated
by admin wallet._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| to | address | Address to issue the NFT |
| tokenId | uint256 | TokenId to be issued. |
| lifeTokenIssuanceRate_ | uint256 | Token issuance rate. Will be based on ML's mortgrage payment book. |

### checkClaimableStakingRewards

```solidity
function checkClaimableStakingRewards(uint256 tokenId) public view returns (uint256)
```

### claimStakingRewards

```solidity
function claimStakingRewards(uint256 tokenId) public
```

Claim $LIFE token staking rewards.

_The rewards will be directly minted on the caller address.
Once success, the timestamp of _stakingRewards for that tokenId will be reset._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| tokenId | uint256 | TokenId of the NFT. |

### burnTokens

```solidity
function burnTokens(uint256 amount, uint256 tokenId) external
```

Burn $LIFE token rewards from an NFTi holder.

_Burn percentage if being managed from the frontend app._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| amount | uint256 | Calculated amount to be burned. |
| tokenId | uint256 | TokenId of the NFT, will be used as param in access modifier. |

### transferNft

```solidity
function transferNft(address to, uint256 tokenId) external
```

Transfer NFTi function

_This transfer operation checks for some requirements before it
successfully proceed.
Requirements:
- Sender must be the NFTi owner
- NFTi should have no or have finished the locked up period._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| to | address | Receiver of NFTi |
| tokenId | uint256 | NFTi tokenId to be sent. |

### returnNftToML

```solidity
function returnNftToML(uint256 tokenId) external
```

Return the NFTi to ML wallet.

_Use case - The investment period has been completed for a specificc NFTi
and the asset needs to be returned. The investor should also clear the lockup
period of the NFT so that the admins can transfer it to anyone at anytime. In
an event that the NFTi has a claimable reward during the execution of this
operation, the reward will be transferred first to the investor._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| tokenId | uint256 | NFTi's tokenId. |

### setLockDate

```solidity
function setLockDate(uint256 tokenId, uint256 _newLockDate) external
```

### burnNFt

```solidity
function burnNFt(uint256 tokenId) external
```

### forceClaimNft

```solidity
function forceClaimNft(uint256 tokenId) external
```

### onlyInvestor

```solidity
modifier onlyInvestor(uint256 tokenId)
```

_Modifier checks to see if the token holder is an NFTi investor_

## ManageLife

NFT (ERC-721) contract for ManageLife Homeowners.
An NFT represents a property or home ownership in real life.
Properties are all being managed by ManageLife.
NFT Symbol: MLIFE

### lifeToken

```solidity
contract Life lifeToken
```

### marketplace

```solidity
contract Marketplace marketplace
```

### PROPERTY_CUSTODIAN

```solidity
address PROPERTY_CUSTODIAN
```

This is the wallet address where all property NFTs will be
stored as soon as the property got vacated or returned to ML.

### lifeTokenIssuanceRate

```solidity
mapping(uint256 => uint256) lifeTokenIssuanceRate
```

Mapping to get the issuance rate of a tokenId (propery).

### _fullyPaid

```solidity
mapping(uint256 => bool) _fullyPaid
```

Mapping to check the payment status of a tokenId.

### FullyPaid

```solidity
event FullyPaid(uint256 tokenId)
```

### StakingInitialized

```solidity
event StakingInitialized(uint256 tokenId)
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

### _baseURI

```solidity
function _baseURI() internal pure returns (string)
```

_Base URI for computing {tokenURI}. If set, the resulting URI for each
token will be the concatenation of the `baseURI` and the `tokenId`. Empty
by default, can be overridden in child contracts._

### baseURI

```solidity
function baseURI() external pure returns (string)
```

Return the base URI of NFT metadata.

_Returns the API address where the metadata are stored._

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| [0] | string | string |

### setMarketplace

```solidity
function setMarketplace(address payable marketplace_) external
```

Function to set the Marketplace contract address.

_Very important to set this after contract deployment._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| marketplace_ | address payable | Address of the marketplace contract. |

### setLifeToken

```solidity
function setLifeToken(address lifeToken_) external
```

Function to set the @LIFE token contract address.

_Very important to set this after contract deployment._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| lifeToken_ | address | Address of the $LIFE token contract. |

### fullyPaid

```solidity
function fullyPaid(uint256 tokenId) public view returns (bool)
```

Function to check if a property (NFT) is fully paid from mortgages at ML.

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| tokenId | uint256 | TokenId of the NFT property to be checked. |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| [0] | bool | bool - will return true/false. |

### markFullyPaid

```solidity
function markFullyPaid(uint256 tokenId) external
```

Mark an NFT or property fully paid from all mortgages at ML.

_This can only be executed by the contract deployer or admin wallet._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| tokenId | uint256 | TokenId of the NFT. |

### mint

```solidity
function mint(uint256 propertyId, uint256 lifeTokenIssuanceRate_) external
```

Function to mint new NFT properties.

_Property ID will be the property number provided by the ML-NFT-API service.
Life token issuance rate will be populated by the web3 admin from the portal app._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| propertyId | uint256 | Property ID of the NFT. This will be provided by the FrontEnd app. |
| lifeTokenIssuanceRate_ | uint256 | Issuance rate percentage that is based on morgage payments maintained by ML. |

### burn

```solidity
function burn(uint256 tokenId) public
```

Burn an NFT. Typical use case is remove an property from ML's custody.

_Can only be executed by the admin/deployer wallet._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| tokenId | uint256 | TokenId of the NFT to be burned. |

### retract

```solidity
function retract(uint256 tokenId) external
```

Admin wallet to retract a property (NFT) from a customer.

_Use case is the admin wallet needs to force claim an NFT from a customer._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| tokenId | uint256 | TokenId of the property that needs to be retrackted. |

### returnProperty

```solidity
function returnProperty(uint256 tokenId) external
```

Homeowners or NFT holders to return a property to ML wallet.

_This will fail if the caller is not the owner of the NFT._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| tokenId | uint256 | TokenId of the NFT to be returned. |

### approve

```solidity
function approve(address to, uint256 tokenId) public
```

Allow homeowners/NFT holders to approve a 3rd party account
to perform transactions on their behalf.

_This works like setApprovalForAll. The owner is giving ownership wo their NFT.
Use case of this is an ML customer who would like to give an access to anyone to
use the home/property.
Requirements in order to make sure this call will succeed:
- The property should be fully paid.
- Function caller should be the ml admin deployer wallet.
- Receiver should be the Marketplace contract address._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| to | address | Wallet address who will be granted with the above permission. |
| tokenId | uint256 | TokenId of the NFT. |

### _beforeTokenTransfer

```solidity
function _beforeTokenTransfer(address from, address to, uint256 tokenId) internal
```

Transfer hooks. The functions inside will be executed as soon as the
concerned NFT is being trasnferred.

_Operations inside this hook will be accomplished
if either of the checks below were accomplished:
- Customers cannot be able to transfer their NFTs if they are not yet fully paid.
- Sender is the contract owner.
- Receiver is the contract owner.
- Caller of thid function is the Marketplace contract address._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| from | address | Sender of the NFT. |
| to | address | Receiver of the NFT. |
| tokenId | uint256 | TokenId of the NFT. |

### _burn

```solidity
function _burn(uint256 tokenId) internal
```

### tokenURI

```solidity
function tokenURI(uint256 tokenId) public view returns (string)
```

Query the tokenURI of an NFT.

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| tokenId | uint256 | TokenId of an NFT to be queried. |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| [0] | string | string - API address of the NFT's metadata |

### updateLifeTokenIssuanceRate

```solidity
function updateLifeTokenIssuanceRate(uint256 tokenId, uint256 newLifeTokenIssuanceRate) external
```

### updatePropertyCustodian

```solidity
function updatePropertyCustodian(address _newPropertyCustodian) external
```

Update the property custodian.

_New address set here will be the new owner of all returned NFTs/properties.
Will emit PropertyCustodianUpdated event._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| _newPropertyCustodian | address | Wallet address of the new property custodian. |

## Marketplace

Marketplace contract for ManageLife.
This contract the market trading of NFTs in the ML ecosystem.
In real life, an NFT here represents a home or real-estate property
run by ManageLife.

### mlAdmin

```solidity
address mlAdmin
```

### constructor

```solidity
constructor() public
```

Deployer address will be considered as the ML admins

### PERCENTS_DIVIDER

```solidity
uint256 PERCENTS_DIVIDER
```

Percent divider to calculate ML's transaction earnings.

### allowTrading

```solidity
bool allowTrading
```

Trading status. This determines if normal users will be
allowed to permitted to perform market trading (Bidding, Selling, Buy).
By default Admin wallet will perform all these functions on behalf of all customers
due to legal requirements.
Once legal landscape permits, customers will be able to perform market trading by themselves.

### mLife

```solidity
contract ManageLife mLife
```

instance of the MLIFE NFT contract.

### Offer

```solidity
struct Offer {
  uint32 tokenId;
  address seller;
  uint256 price;
  address offeredTo;
}
```

### Bid

```solidity
struct Bid {
  address bidder;
  uint256 value;
}
```

### adminPercent

```solidity
uint256 adminPercent
```

Default admin fee.

### adminPending

```solidity
uint256 adminPending
```

Status for adming pending claimable earnings.

### offers

```solidity
mapping(uint256 => struct Marketplace.Offer) offers
```

Mapping of MLIFE tokenIds to Offers

### bids

```solidity
mapping(uint256 => struct Marketplace.Bid) bids
```

Mapping of MLIFE tokenIds to Bids

### Offered

```solidity
event Offered(uint256 tokenId, uint256 price, address toAddress)
```

### BidEntered

```solidity
event BidEntered(uint32 tokenId, uint256 value, address fromAddress)
```

### BidCancelled

```solidity
event BidCancelled(uint256 tokenId, uint256 value, address bidder)
```

### Bought

```solidity
event Bought(uint256 tokenId, uint256 value, address fromAddress, address toAddress, bool isInstant)
```

### BidWithdrawn

```solidity
event BidWithdrawn(uint256 tokenId, uint256 value)
```

### Cancelled

```solidity
event Cancelled(uint256 tokenId)
```

### TradingStatus

```solidity
event TradingStatus(bool _isTradingAllowed)
```

### Received

```solidity
event Received(address, uint256)
```

### InvalidPercent

```solidity
error InvalidPercent(uint256 _percent, uint256 minimumPercent)
```

### pause

```solidity
function pause() external
```

Security feature to Pause smart contracts transactions

### unpause

```solidity
function unpause() external
```

Unpausing the Paused transactions feature.

### setTrading

```solidity
function setTrading(bool _isTradingAllowed) external
```

Update the `allowTrading` status to true/false.

_Can only be executed by contract owner. Will emit TradingStatus event._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| _isTradingAllowed | bool | New boolean status to set. |

### setNftContract

```solidity
function setNftContract(address nftAddress) external
```

Set the MLIFE contract.

_Important to set this after deployment. Only MLIFE address is needed.
Will not access 0x0 (zero/invalid) address._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| nftAddress | address | Address of MLIFE contract. |

### setAdminPercent

```solidity
function setAdminPercent(uint256 _percent) external
```

Allows admin wallet to set new percentage fee.

_This throws an error is the new percentage is less than 500._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| _percent | uint256 | New admin percentage. |

### withdraw

```solidity
function withdraw() external
```

Withdraw marketplace earnings.

_Can only be triggered by the admin wallet or contract owner.
This will transfer the market earning to the admin wallet._

### cancelForSale

```solidity
function cancelForSale(uint32 tokenId) external
```

Cancel and existing sale offer.

_Once triggered, the offer struct for this tokenId will be destroyed.
Can only be called by MLIFE holders._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| tokenId | uint32 | TokenId of the NFT. |

### offerForSale

```solidity
function offerForSale(uint32 tokenId, uint256 minSalePrice) external
```

Offer a property or NFT for sale in the marketplace.

_If `allowTrading` is equals to true,
users are allowed to execute this function. Else, admin wallet will facilitate
the offering sale on their behalf._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| tokenId | uint32 | MLIFE tokenId to be put on sale. |
| minSalePrice | uint256 | Minimum sale price of the property. |

### offerForSaleToAddress

```solidity
function offerForSaleToAddress(uint32 tokenId, uint256 minSalePrice, address toAddress) external
```

Offer a property for sale to a specific wallet address only.

_Allows MLIFE holders to sell their property to a specific wallet address.
By default, this process is being performed by the admin wallet on behalf of the customers
not until the `allowTrading` has been set to `true`._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| tokenId | uint32 | TokenId of the property to be offered. |
| minSalePrice | uint256 | Minimum sale prices of the property. |
| toAddress | address | Wallet address on where the property will be offered to. |

### buy

```solidity
function buy(uint32 tokenId) external payable
```

Allows users to buy a property that is registered in ML.

_By default, this operation is disabled for customers.
Only admin wallet can perform this on their behalf until the
`allowTrading` variable is equals to true._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| tokenId | uint32 | TokenId of the property. |

### placeBid

```solidity
function placeBid(uint32 tokenId) external payable
```

Allows users to submit a bid to any properties.

_By default, bidding is disabled for customers.
Only admin wallet can perform bidding on their behalf until the
`allowTrading` variable is equals to true._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| tokenId | uint32 | tokenId of the property. |

### acceptBid

```solidity
function acceptBid(uint32 tokenId, uint256 minPrice) external
```

Allows home owners to accept bids on their properties

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| tokenId | uint32 | tokenId of the property. |
| minPrice | uint256 | Minimum bidding price. |

### withdrawBid

```solidity
function withdrawBid(uint32 tokenId) external
```

Allows bidders to withdraw their bid on a specific property.

_There will be different process flows on this function depending
on the value of `allowTrading`. By default, the entire trading will be
facilitated by the admin wallet._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| tokenId | uint32 | tokenId of the property that is currently being bid. |

### receive

```solidity
receive() external payable
```

_This records the address and ether value that was sent to the Marketplace_

### _safeTransferETH

```solidity
function _safeTransferETH(address to, uint256 value) internal
```

_Eth transfer hook_

### setMLAdmin

```solidity
function setMLAdmin(address newAdminAddress) external
```

Allow admins to set new ML Admin wallet.
Only contract owner/deployer can execute this function

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| newAdminAddress | address | New wallet address to be used. |

### onlyMLifeOwner

```solidity
modifier onlyMLifeOwner(uint256 tokenId)
```

Modifier to make sure only MLIFE
NFT holders can run a specific functions.

### isTradingAllowed

```solidity
modifier isTradingAllowed()
```

Modifier to make sure only admin wallet can perform
market tradings on behalf of all users.

_`allowTrading` should be set to `true` in order for the users to facilitate the
market trading by themselves._

