// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/// @title ManageLife Marketplace
/// @author https://managelife.io
/// @notice This smart contract is used within the ManageLife ecosystem for buying and selling MLRE properties
/// @dev A different marketplace contract needs to be built for the NFTi
contract Marketplace is ReentrancyGuard, Ownable, Pausable {
    struct Listing {
        address seller;
        uint256 tokenId;
        address paymentToken; // ETH is represented by address(0)
        uint256 minPrice;
        bool active;
    }

    struct Bid {
        address bidder;
        uint256 amount;
    }

    using SafeERC20 for IERC20;

    uint256 public marketplaceFee = 200; // 2% scaled
    uint256 public constant FEE_DENOMINATOR = 10000;
    uint256 public MAX_FEE = 500; // 5% Initial max admin fee

    uint256 public adminsEthEarnings;
    mapping(address => uint256) public adminsTokenEarnings;
    mapping(uint256 => Listing) public listings;
    mapping(uint256 => Bid) public currentBids;
    mapping(address => uint256) public ethRefundsForBidders;
    mapping(address => mapping(address => uint256))
        public tokenRefundsForBidders;

    address public MLIFE;
    address public tokenUSDT;
    address public tokenUSDC;
    address public nftContract;

    event ListingCreated(
        address indexed seller,
        uint256 indexed tokenId,
        address paymentToken,
        uint256 minPrice
    );
    event ListingCancelled(uint256 _tokenId, address seller);
    event BidPlaced(
        uint256 indexed tokenId,
        address indexed bidder,
        uint256 amount
    );
    event BidWithdrawn(uint256 tokenId, address indexed bidder);
    event NFTSold(
        uint256 tokenId,
        address indexed buyer,
        address indexed seller,
        uint256 price
    );
    event AdminEthWithdrawals(address _admin, uint256 _amount);
    event AdminTokenWithdrawals(
        address _admin,
        address _token,
        uint256 _amount
    );
    event RefundIssued(address _receiver, address _tokenType, uint256 _amount);
    event MarketplaceFeeUpdated(uint256 newFee);
    event NftAddressUpdated(address _oldAddress, address _newAddress);
    event MLifeTokenAddressUpdated(address _oldAddress, address _newAddress);
    event UsdcAddressUpdated(address _oldAddress, address _newAddress);
    event UsdtAddressUpdated(address _oldAddress, address _newAddress);
    event MaxFeeUpdated(uint256 _newMaxFee);
    event RefundWithdrawn(
        address _paymentType,
        address _receiver,
        uint256 _amount
    );

    event Paused();
    event Unpaused();

    modifier onlyNFTOwner(uint256 tokenId) {
        require(
            IERC721(nftContract).ownerOf(tokenId) == msg.sender,
            "Not NFT owner"
        );
        _;
    }

    modifier validPaymentToken(address token) {
        require(
            token == address(0) ||
                token == MLIFE ||
                token == tokenUSDT ||
                token == tokenUSDC,
            "Unsupported payment token"
        );
        _;
    }

    modifier isListingActive(uint256 _tokenId) {
        require(listings[_tokenId].active, "Listing not active");
        _;
    }

    constructor(
        address _nftContract,
        address _MLIFE,
        address _tokenUSDT,
        address _tokenUSDC
    ) Ownable(msg.sender) ReentrancyGuard() Pausable() {
        nftContract = _nftContract;
        MLIFE = _MLIFE;
        tokenUSDT = _tokenUSDT;
        tokenUSDC = _tokenUSDC;
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function updateMarketplaceFee(
        uint256 _newFee
    ) external onlyOwner whenNotPaused {
        require(_newFee > 0, "Invalid fee update");
        require(_newFee <= MAX_FEE, "Fee exceeds threshold");
        marketplaceFee = _newFee;
        emit MarketplaceFeeUpdated(_newFee);
    }

    function updateNftContract(address _newAddress) external onlyOwner {
        require(_newAddress != address(0), "Invalid address");
        nftContract = _newAddress;
        emit NftAddressUpdated(nftContract, _newAddress);
    }

    function updateMLifeTokenAddress(address _newAddress) external onlyOwner {
        require(_newAddress != address(0), "Invalid address");

        address oldAddress = MLIFE;
        MLIFE = _newAddress;
        emit MLifeTokenAddressUpdated(oldAddress, _newAddress);
    }

    function updateUsdtTokenAddress(address _newAddress) external onlyOwner {
        require(_newAddress != address(0), "Invalid address");

        address oldAddress = tokenUSDT;
        tokenUSDT = _newAddress;
        emit UsdtAddressUpdated(oldAddress, _newAddress);
    }

    function updateUsdcTokenAddress(address _newAddress) external onlyOwner {
        require(_newAddress != address(0), "Invalid address");

        address oldAddress = tokenUSDC;
        tokenUSDC = _newAddress;
        emit UsdcAddressUpdated(oldAddress, _newAddress);
    }

    /*** Function to update the MAX_FEE. Max fee threshold is the highest percentage that the
     * marketplace could increase it's fee limit
     * @param _newMaxFee New may fee value that should not be zero and higher than 900 (95%)
     */
    function updateMaxFee(uint256 _newMaxFee) external onlyOwner whenNotPaused {
        // @note 900 == 9% maxFee
        require(
            _newMaxFee > 0 && _newMaxFee < 900,
            "Fee must be > 0 and < 900"
        );

        MAX_FEE = _newMaxFee;
        emit MaxFeeUpdated(_newMaxFee);
    }

    /*** @notice Creating a listing - Sell your NFT property to Marketplace
     * @dev Seller's should approve this marketplace contract as operator first.
     * All NFTs to be listed will be held to this contract until the seller withdraws it
     * or a buyer has bought it.
     * @param tokenId TokenId of the NFT from MLRE contract
     * @param paymentToken Type of payment. See token addresses of supported tokens. ETH defaults to address(0)
     * @param minPrice Cost of the property/NFT
     */
    function createListing(
        uint256 tokenId,
        address paymentToken,
        uint256 minPrice
    )
        external
        whenNotPaused
        onlyNFTOwner(tokenId)
        validPaymentToken(paymentToken)
    {
        require(minPrice > 0, "Price should not be zero");
        require(
            IERC721(nftContract).isApprovedForAll(msg.sender, address(this)) ||
                IERC721(nftContract).getApproved(tokenId) == address(this),
            "NFT Approval required"
        );
        IERC721(nftContract).transferFrom(msg.sender, address(this), tokenId);

        listings[tokenId] = Listing({
            seller: msg.sender,
            tokenId: tokenId,
            paymentToken: paymentToken,
            minPrice: minPrice,
            active: true
        });

        emit ListingCreated(msg.sender, tokenId, paymentToken, minPrice);
    }

    /*** @notice Cancelling the listing of a property. Once cancelled, the
     * deposited NFT during the listing creation will be returned to the seller
     * @param _tokenId TokenId of the property
     */
    function cancelListing(
        uint256 _tokenId
    ) external whenNotPaused nonReentrant {
        require(listings[_tokenId].active, "Listing not active");
        require(listings[_tokenId].seller == msg.sender, "Not listing owner");

        // Transferring back the NFT to the owner
        IERC721(nftContract).transferFrom(address(this), msg.sender, _tokenId);
        delete listings[_tokenId];
        emit ListingCancelled(_tokenId, msg.sender);
    }

    /*** @notice Function to allow people to submit a bid on a listed property
     * @dev This marketplace contract should be allowed as a token spender if payment type is token
     * @dev Outbidden users can claim their refunds using withdrawTokenRefunds and withdrawEthRefunds functions
     * @param _tokenId TokenId of the property
     * @param _amount Bid amount. Bid amount should be equal or higher than the current sale valu of the listing
     * @param _paymentType Mode of payment or token addresses, either ETH/tokens.
     */
    function placeBid(
        uint256 _tokenId,
        uint256 _amount,
        address _paymentType
    )
        external
        payable
        whenNotPaused
        nonReentrant
        isListingActive(_tokenId)
        validPaymentToken(_paymentType)
    {
        Listing memory listing = listings[_tokenId];
        require(_amount >= listing.minPrice, "Your bid is below minimum price");

        if (listing.paymentToken == address(0)) {
            // ETH payment
            require(msg.value == _amount, "Incorrect ETH sent");
        } else {
            // Token payment
            bool success = IERC20(listing.paymentToken).transferFrom(
                msg.sender,
                address(this),
                _amount
            );
            require(success, "Token transfer failed");
        }

        Bid memory currentBid = currentBids[_tokenId];
        require(
            _amount > currentBid.amount,
            "Bid must be higher than current bid"
        );

        // @note There is a mechanism where bidders can outbid others
        // @note Refund previous bidder
        if (currentBid.amount > 0) {
            _refundBid(
                listing.paymentToken,
                currentBid.bidder,
                currentBid.amount
            );
        }

        currentBids[_tokenId] = Bid({bidder: msg.sender, amount: _amount});
        emit BidPlaced(_tokenId, msg.sender, _amount);
    }

    /*** @notice Function to accept the current bid on a property
     * This can only be triggered by the seller of the listing
     * @dev Once accepted, admin wallet will cut a fee from the total sale price
     * @param _tokenId TokenId of the property
     */
    function acceptBid(
        uint256 _tokenId
    ) external nonReentrant whenNotPaused isListingActive(_tokenId) {
        Listing storage listing = listings[_tokenId];
        Bid memory bid = currentBids[_tokenId];

        require(listing.seller == msg.sender, "Only seller can accept bid");
        require(bid.amount > 0, "No active bid");

        uint256 fee = (bid.amount * marketplaceFee) / FEE_DENOMINATOR;
        adminsEthEarnings += fee;
        uint256 sellerProceeds = bid.amount - fee;

        // Distribute proceeds
        if (listing.paymentToken == address(0)) {
            // ETH payment
            // Safe ETH transfer
            (bool success, ) = listing.seller.call{value: sellerProceeds}("");
            require(success, "ETH transfer to seller failed");
        } else {
            adminsTokenEarnings[listing.paymentToken] += fee;
            // Token payment
            IERC20(listing.paymentToken).safeTransfer(
                listing.seller,
                sellerProceeds
            );
        }

        // Transfer NFT
        IERC721(nftContract).transferFrom(
            address(this),
            bid.bidder,
            listing.tokenId
        );

        // Deleting listings and bids
        delete listings[_tokenId];
        delete currentBids[_tokenId];

        emit NFTSold(_tokenId, bid.bidder, listing.seller, bid.amount);
    }

    /*** @notice Allowing bidders to withdraw their outbidden ETHs */
    function withdrawEthRefunds() external nonReentrant {
        uint256 amount = ethRefundsForBidders[msg.sender];
        require(amount > 0, "No refundable amount");

        // @note @dev Ensuring that the marketplace has enough ETH balance
        require(
            amount <= address(this).balance,
            "Insufficient contract balance"
        );

        ethRefundsForBidders[msg.sender] = 0;

        // Safe transfer ETH
        (bool success, ) = msg.sender.call{value: amount}("");
        require(success, "ETH refund request failed");

        emit RefundWithdrawn(address(0), msg.sender, amount);
    }

    /*** @notice Allowing bidders to withdraw their outbidden tokens
     * Tokens to be withdrawn here are only the supported types: MLIFE/USDT/USDC
     * @param _paymentToken Contract address of the token to be withdrawn
     */
    function withdrawTokenRefunds(address _paymentToken) external nonReentrant {
        uint256 amount = tokenRefundsForBidders[msg.sender][_paymentToken];
        require(amount > 0, "No refundable token");
        // Ensuring first that the marketplace contract has enough token balance
        require(
            IERC20(_paymentToken).balanceOf(address(this)) >= amount,
            "Insufficient Marketplace's token balance"
        );

        // Resetting the token refunds mapping
        tokenRefundsForBidders[msg.sender][_paymentToken] = 0;

        IERC20(_paymentToken).safeTransfer(msg.sender, amount);
        emit RefundWithdrawn(_paymentToken, msg.sender, amount);
    }

    /*** @notice Function to allow bidders to withdraw their bid.
     * @dev This is also a mechanism for bidders
     * to get their deposited ETH or tokens in the contract. All withdrawn assets (ETH/tokens)
     * will be placed under ethRefundsForBidders or tokenRefundsForBidders mappings
     * @param _tokenId NFT's tokenID
     */
    function withdrawBid(uint256 _tokenId) external nonReentrant whenNotPaused {
        Bid memory bid = currentBids[_tokenId];
        require(bid.bidder == msg.sender, "Not the current bidder");

        _refundBid(listings[_tokenId].paymentToken, bid.bidder, bid.amount);

        delete currentBids[_tokenId];
        emit BidWithdrawn(_tokenId, msg.sender);
    }

    /*** @notice Allowing admin to withdraw their ETH earnings */
    function withdrawAdminEthEarnings() external onlyOwner nonReentrant {
        uint256 earnings = adminsEthEarnings;
        require(earnings > 0, "No ETH to withdraw");
        adminsEthEarnings = 0;

        // Safe ETH transfer
        (bool success, ) = msg.sender.call{value: earnings}("");
        require(success, "ETH earnings transfer failed");
        emit AdminEthWithdrawals(owner(), earnings);
    }
    /*** @notice Allowing admin to withdraw their token earnings: MLIFE/USDC/USDT
     * @param _tokenAddress Contract address of the token to be withdrawn
     */
    function withdrawAdminTokenEarnings(
        address _tokenAddress
    ) external onlyOwner nonReentrant {
        uint256 tokenEarnings = adminsTokenEarnings[_tokenAddress];
        require(tokenEarnings > 0, "No token earnings to withdraw");

        adminsTokenEarnings[_tokenAddress] = 0;
        IERC20(_tokenAddress).transfer(owner(), tokenEarnings);
        emit AdminTokenWithdrawals(owner(), _tokenAddress, tokenEarnings);
    }

    /*** Internal function to handle refunds mapping for both ETH and token payments
     * @dev This function facilitates the refunds for outbidden users and save them on mappings
     * depending on the payment type
     */
    function _refundBid(
        address paymentToken,
        address bidder,
        uint256 amount
    ) internal {
        if (paymentToken == address(0)) {
            // Refunding the ETH to the outbid user
            ethRefundsForBidders[bidder] += amount;
        } else {
            // Refunding the token to the outbid user
            tokenRefundsForBidders[bidder][paymentToken] += amount;
        }
        emit RefundIssued(bidder, paymentToken, amount);
    }
}

/// @thanks Built for ManageLife by Koleen Paunon - https://koleenbp.com
