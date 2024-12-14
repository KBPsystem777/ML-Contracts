// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

// Same imports as before
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";

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

    // Constants and variables (unchanged from earlier)
    uint256 public marketplaceFee = 200; // 2% scaled
    uint256 public constant FEE_DENOMINATOR = 10000;
    uint256 public MAX_FEE = 900; // 9% Initial max admin fee

    uint256 public listingCounter;
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
        uint256 listingId,
        address indexed seller,
        uint256 indexed tokenId,
        address paymentToken,
        uint256 minPrice
    );
    event ListingCancelled(uint256 _tokenId, address seller);
    event BidPlaced(uint256 listingId, address indexed bidder, uint256 amount);
    event BidWithdrawn(uint256 listingId, address indexed bidder);
    event NFTSold(
        uint256 listingId,
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
    event MarketplaceFeeUpdated(uint256 newFee);
    event NftAddressUpdated(address _oldAddress, address _newAddress);
    event MLifeTokenAddressUpdated(address _oldAddress, address _newAddress);
    event UsdcAddressUpdated(address _oldAddress, address _newAddress);
    event UsdtAddressUpdated(address _oldAddress, address _newAddress);
    event MaxFeeUpdated(uint256 _newMaxFee);

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
        MLIFE = _newAddress;
        emit MLifeTokenAddressUpdated(MLIFE, _newAddress);
    }

    function updateUsdtTokenAddress(address _newAddress) external onlyOwner {
        require(_newAddress != address(0), "Invalid address");
        tokenUSDT = _newAddress;
        emit UsdtAddressUpdated(tokenUSDT, _newAddress);
    }

    function updateUsdcTokenAddress(address _newAddress) external onlyOwner {
        require(_newAddress != address(0), "Invalid address");
        tokenUSDC = _newAddress;
        emit UsdcAddressUpdated(tokenUSDC, _newAddress);
    }

    function updateMaxFee(uint256 _newMaxFee) external onlyOwner {
        MAX_FEE = _newMaxFee;
        emit MaxFeeUpdated(_newMaxFee);
    }

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
        IERC721(nftContract).transferFrom(msg.sender, address(this), tokenId);

        listings[listingCounter] = Listing({
            seller: msg.sender,
            tokenId: tokenId,
            paymentToken: paymentToken,
            minPrice: minPrice,
            active: true
        });

        emit ListingCreated(
            listingCounter,
            msg.sender,
            tokenId,
            paymentToken,
            minPrice
        );

        listingCounter++;
    }
    function cancelListing(
        uint256 _tokenId
    ) external whenNotPaused nonReentrant {
        require(listings[_tokenId].active, "Listing not active");
        require(listings[_tokenId].seller == msg.sender, "Not listing owner");
        delete listings[_tokenId];
        emit ListingCancelled(_tokenId, msg.sender);
    }

    function placeBid(
        uint256 listingId,
        uint256 amount
    ) external payable whenNotPaused nonReentrant isListingActive(listingId) {
        Listing memory listing = listings[listingId];
        require(amount >= listing.minPrice, "Bid below minimum price");

        if (listing.paymentToken == address(0)) {
            // ETH payment
            require(msg.value == amount, "Incorrect ETH sent");
        } else {
            // Token payment
            bool success = IERC20(listing.paymentToken).transferFrom(
                msg.sender,
                address(this),
                amount
            );
            require(success, "Token transfer failed");
        }

        Bid memory currentBid = currentBids[listingId];
        require(
            amount > currentBid.amount,
            "Bid must be higher than current bid"
        );

        // Refund previous bidder
        if (currentBid.amount > 0) {
            _refundBid(
                listing.paymentToken,
                currentBid.bidder,
                currentBid.amount
            );
        }

        currentBids[listingId] = Bid({bidder: msg.sender, amount: amount});
        emit BidPlaced(listingId, msg.sender, amount);
    }

    function acceptBid(
        uint256 listingId
    ) external nonReentrant whenNotPaused isListingActive(listingId) {
        Listing storage listing = listings[listingId];
        Bid memory bid = currentBids[listingId];

        require(listing.seller == msg.sender, "Only seller can accept bid");
        require(bid.amount > 0, "No active bid");

        uint256 fee = (bid.amount * marketplaceFee) / FEE_DENOMINATOR;
        uint256 sellerProceeds = bid.amount - fee;

        // Distribute proceeds
        if (listing.paymentToken == address(0)) {
            // ETH payment
            adminsEthEarnings += fee;
            payable(listing.seller).transfer(sellerProceeds);
        } else {
            // Token payment
            IERC20(listing.paymentToken).transfer(
                listing.seller,
                sellerProceeds
            );
            adminsTokenEarnings[listing.paymentToken] += fee;
        }

        // Transfer NFT
        IERC721(nftContract).transferFrom(
            address(this),
            bid.bidder,
            listing.tokenId
        );

        // Deleting listings and bids
        delete listings[listingId];
        delete currentBids[listingId];

        emit NFTSold(listingId, bid.bidder, listing.seller, bid.amount);
    }

    /*** Allowing bidders to withdraw their outbidden ETHs */
    function withdrawEthRefunds() external nonReentrant {
        uint256 amount = ethRefundsForBidders[msg.sender];
        require(amount > 0, "No refundable amount");
        ethRefundsForBidders[msg.sender] = 0;
        payable(msg.sender).transfer(amount);
    }

    /*** Allowing bidders to withdraw their outbidden tokens */
    function withdrawTokenRefunds(address _paymentToken) external nonReentrant {
        uint256 amount = tokenRefundsForBidders[msg.sender][_paymentToken];
        require(amount > 0, "No refundable token");
        tokenRefundsForBidders[msg.sender][_paymentToken] = 0;
        IERC20(_paymentToken).transfer(msg.sender, amount);
    }

    function withdrawBid(
        uint256 listingId
    ) external nonReentrant whenNotPaused {
        Bid memory bid = currentBids[listingId];
        require(bid.bidder == msg.sender, "Not the current bidder");

        _refundBid(listings[listingId].paymentToken, bid.bidder, bid.amount);

        delete currentBids[listingId];
        emit BidWithdrawn(listingId, msg.sender);
    }

    function withdrawAdminEthEarnings() external onlyOwner nonReentrant {
        uint256 adminEarnings = adminsEthEarnings;
        require(adminEarnings > 0, "No ETH to withdraw");
        adminsEthEarnings = 0;
        _safeTransferETH(owner(), adminEarnings);
        emit AdminEthWithdrawals(owner(), adminEarnings);
    }

    function withdrawAdminTokenEarnings(
        address _tokenAddress
    ) external onlyOwner nonReentrant {
        uint256 tokenEarnings = adminsTokenEarnings[_tokenAddress];
        require(tokenEarnings > 0, "No token earnings to withdraw");

        adminsTokenEarnings[_tokenAddress] = 0;
        IERC20(_tokenAddress).transfer(owner(), tokenEarnings);
        emit AdminTokenWithdrawals(owner(), _tokenAddress, tokenEarnings);
    }

    function _safeTransferETH(address to, uint256 amount) private {
        (bool success, ) = to.call{value: amount}("");
        require(
            success,
            "ETH transfer failed. Contact support for manual withdrawals"
        );
    }

    function _refundBid(
        address paymentToken,
        address bidder,
        uint256 amount
    ) internal {
        if (paymentToken == address(0)) {
            ethRefundsForBidders[bidder] += amount;
        } else {
            tokenRefundsForBidders[bidder][paymentToken] += amount;
        }
    }
}
