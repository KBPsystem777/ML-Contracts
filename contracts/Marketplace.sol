// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "./ManageLife.sol";

/**
 * @notice Marketplace contract for ManageLife.
 * This contract the market trading of NFTs in the ML ecosystem.
 * In real life, an NFT here represents a home or real-estate property
 * run by ManageLife.
 *
 * @author https://managelife.io
 */
contract Marketplace is ReentrancyGuard, Pausable, Ownable {
    using SafeERC20 for IERC20;

    // Instance of the MLRE NFT contract.
    ManageLife public mLife;

    // @note Supported tokens: $MLIFE, USDC and USDT
    IERC20 public lifeToken;
    IERC20 public usdt;
    IERC20 public usdc;

    // @notice Deployer address will be considered as the ML admins
    constructor(address _lifeToken, address _usdt, address _usdc) {
        lifeToken = IERC20(_lifeToken);
        usdt = IERC20(_usdt);
        usdc = IERC20(_usdc);
    }

    /// Percent divider to calculate ML's transaction earnings.
    uint256 public constant PERCENTS_DIVIDER = 10000;

    /** @notice Trading status. This determines if normal users will be
     * allowed to permitted to perform market trading (Bidding, Selling, Buy).
     * By default Admin wallet will perform all these functions on behalf of all customers
     * due to legal requirements.
     * Once legal landscape permits, customers will be able to perform market trading by themselves.
     */
    bool public allowTrading = false;

    struct Offer {
        uint256 tokenId;
        address seller;
        uint256 price;
        address offeredTo;
        address paymentToken;
    }

    struct Bid {
        address bidder;
        uint256 value;
        address paymentToken;
    }

    /// @notice Default admin fee. 200 initial value is equals to 2%
    uint256 public adminPercent = 200;

    /// Status for adming pending claimable earnings.
    uint256 public adminPending;

    /// Mapping of MLRE tokenIds to Offers
    mapping(uint256 => Offer) public offers;

    /// Mapping of MLRE tokenIds to Bids
    mapping(uint256 => Bid) public bids;

    /// Mapping for pending refunds
    mapping(address => uint256) public pendingRefunds;

    event Offered(
        uint256 indexed tokenId,
        uint256 price,
        address indexed toAddress,
        address indexed paymentToken
    );

    event BidEntered(
        uint256 indexed tokenId,
        uint256 value,
        address indexed fromAddress,
        address indexed paymentToken
    );

    event BidCancelled(
        uint256 indexed tokenId,
        uint256 value,
        address indexed bidder
    );

    event Bought(
        uint256 indexed tokenId,
        uint256 value,
        address indexed fromAddress,
        address indexed toAddress
    );

    event BidWithdrawn(
        uint256 indexed tokenId,
        uint256 value,
        address indexed bidder
    );
    event SaleCancelled(uint256 indexed tokenId);
    event TradingStatus(bool _isTradingAllowed);
    event Received(address, uint);
    event PendingRefund(address indexed bidder, uint256 refundAmount);
    event RefundSent(address indexed bidder, uint256 refundAmount);
    event AdminWithdrawal(uint256 amount);
    error InvalidPercent(uint256 _percent, uint256 minimumPercent);

    /// @notice Security feature to Pause smart contracts transactions
    function pause() external whenNotPaused onlyOwner {
        _pause();
    }

    /// @notice Unpausing the Paused transactions feature.
    function unpause() external whenPaused onlyOwner {
        _unpause();
    }

    /**
     * @notice Update the `allowTrading` status to true/false.
     * @dev Can only be executed by contract owner. Will emit TradingStatus event.
     * @param _isTradingAllowed New boolean status to set.
     */
    function setTrading(bool _isTradingAllowed) external onlyOwner {
        allowTrading = _isTradingAllowed;
        emit TradingStatus(_isTradingAllowed);
    }

    /**
     * @notice Set the MLRE contract.
     * @dev Important to set this after deployment. Only MLRE address is needed.
     * Will not access 0x0 (zero/invalid) address.
     * @param nftAddress Address of MLRE contract.
     */
    function setNftContract(address nftAddress) external onlyOwner {
        require(nftAddress != address(0x0), "Zero address");
        mLife = ManageLife(nftAddress);
    }

    /**
     * @notice Allows admin wallet to set new percentage fee.
     * @dev This throws an error is the new percentage is less than 500.
     * @param _percent New admin percentage.
     */
    function setAdminPercent(uint256 _percent) external onlyOwner {
        if (_percent < 500) {
            revert InvalidPercent({_percent: _percent, minimumPercent: 500});
        }
        adminPercent = _percent;
    }

    function safeTransferERC20(
        IERC20 token,
        address to,
        uint256 amount
    ) internal {
        token.safeTransfer(to, amount);
    }

    /**
     * @notice Withdrawalof marketplace earnings by the Admin.
     * @dev Can only be triggered by the admin wallet or contract owner.
     * This will transfer the market earnings to the admin wallet.
     */
    function withdraw() external onlyOwner nonReentrant {
        uint256 amount = adminPending;
        adminPending = 0;
        _safeTransferETH(owner(), amount);
        emit AdminWithdrawal(amount);
    }

    /**
     * @notice Cancel the existing sale offer.
     *
     * @dev Once triggered, the offer struct for this tokenId will be destroyed.
     * Can only be called by MLRE holders. The caller of this function should be
     * the owner if the NFT in MLRE contract.
     *
     * @param tokenId TokenId of the NFT.
     */
    function cancelForSale(uint256 tokenId) external {
        require(msg.sender == mLife.ownerOf(tokenId), "Unathorized");
        delete offers[tokenId];
        emit SaleCancelled(tokenId);
    }

    /**
     * @notice Offer a property or NFT for sale in the marketplace.
     * @param tokenId MLRE tokenId to be put on sale.
     * @param minSalePrice Minimum sale price of the property.
     */
    function offerForSale(
        uint256 tokenId,
        uint256 minSalePrice,
        address paymentToken
    ) external whenNotPaused isTradingAllowed {
        require(
            msg.sender == mLife.ownerOf(tokenId),
            "You do not own this MLRE"
        );
        require(
            paymentToken == address(lifeToken) ||
                paymentToken == address(usdt) ||
                paymentToken == address(usdc) ||
                paymentToken == address(0),
            "Unsupported payment"
        );
        offers[tokenId] = Offer(
            tokenId,
            msg.sender,
            minSalePrice,
            address(0x0),
            paymentToken
        );
        emit Offered(tokenId, minSalePrice, address(0x0), paymentToken);
    }

    /**
     * @notice Offer a property for sale to a specific wallet address only.
     * @param tokenId TokenId of the property to be offered.
     * @param minSalePrice Minimum sale prices of the property.
     * @param toAddress Wallet address on where the property will be offered to.
     */
    function offerForSaleToAddress(
        uint256 tokenId,
        uint256 minSalePrice,
        address toAddress,
        address paymentToken
    ) external whenNotPaused isTradingAllowed {
        require(
            msg.sender == mLife.ownerOf(tokenId),
            "You do not own this MLRE"
        );
        require(
            paymentToken == address(lifeToken) ||
                paymentToken == address(usdt) ||
                paymentToken == address(usdc) ||
                paymentToken == address(0),
            "Unsupported payment"
        );
        offers[tokenId] = Offer(
            tokenId,
            msg.sender,
            minSalePrice,
            toAddress,
            paymentToken
        );
        emit Offered(tokenId, minSalePrice, toAddress, paymentToken);
    }

    /**
     * @notice Allows users to buy a property that is registered in ML.
     * @dev Anyone (public) can buy an MLRE property.
     * @param tokenId TokenId of the property.
     */
    function buy(
        uint256 tokenId
    ) external payable whenNotPaused isTradingAllowed nonReentrant {
        Offer memory offer = offers[tokenId];
        require(
            offer.offeredTo == address(0x0) || offer.offeredTo == msg.sender,
            "This offer is not for you"
        );

        uint256 amount = msg.value;
        require(offer.price > 0, "Price must be greater than zero");
        require(
            amount == offer.price || offer.paymentToken != address(0),
            "Invalid payment amount"
        );

        address seller = offer.seller;
        require(seller != msg.sender, "Seller cannot be buyer");

        // Deleting the offers mapping once sell is confirmed
        delete offers[tokenId];

        // Calculate and allocate commission
        uint256 commission = 0;
        if (adminPercent > 0) {
            commission = (amount * adminPercent) / PERCENTS_DIVIDER;
            adminPending += commission;
        }

        emit Bought(tokenId, amount, seller, msg.sender);

        if (offer.paymentToken == address(0)) {
            require(msg.value == offer.price, "ETH does not match offer");
            _safeTransferETH(seller, offer.price - commission);
        } else if (offer.paymentToken == address(lifeToken)) {
            safeTransferERC20(lifeToken, seller, offer.price - commission);
        } else if (offer.paymentToken == address(usdt)) {
            safeTransferERC20(usdt, seller, offer.price - commission);
        } else if (offer.paymentToken == address(usdc)) {
            safeTransferERC20(usdc, seller, offer.price - commission);
        }

        // Handle bid cancellation if buyer was also highest bidder
        Bid memory bid = bids[tokenId];
        if (bid.bidder == msg.sender) {
            delete bids[tokenId];
            _safeTransferETH(bid.bidder, bid.value);
            emit BidCancelled(tokenId, bid.value, bid.bidder);
        }

        // Ensure the seller is still the owner of the token
        require(mLife.ownerOf(tokenId) == seller, "NFT transfer failed");
        // Transfer NFT using safeTransferFrom to accommodate EOAs and contract accounts
        mLife.safeTransferFrom(seller, msg.sender, tokenId);

        // Validate that the amount is sufficient to cover the commission
        require(amount >= commission, "Amount is less than commission");

        // Calculate the seller's earnings after commission deduction
        uint256 sellerEarnings = amount - commission;

        // Transfer ether to seller minus commission
        if (offer.paymentToken == address(0)) {
            _safeTransferETH(seller, sellerEarnings);
        } else if (offer.paymentToken == address(lifeToken)) {
            safeTransferERC20(lifeToken, seller, sellerEarnings);
        } else if (offer.paymentToken == address(usdt)) {
            safeTransferERC20(usdt, seller, sellerEarnings);
        } else if (offer.paymentToken == address(usdc)) {
            safeTransferERC20(usdc, seller, sellerEarnings);
        }
    }

    /**
     * @notice Allows users to submit a bid to any offered properties.
     * @dev Anyone in public can submit a bid on a property, either MLRE and NFTi holders of not.
     * @param _tokenId tokenId of the property.
     */
    function placeBid(
        uint256 _tokenId
    ) external payable whenNotPaused nonReentrant isTradingAllowed {
        require(msg.value != 0, "Cannot enter bid of zero");
        Bid memory existing = bids[_tokenId];
        require(msg.value > existing.value, "Your bid is too low");

        // Handle refund for the previous bidder
        if (existing.value > 0) {
            // Update the pending refunds mapping
            pendingRefunds[existing.bidder] += existing.value;
            emit BidCancelled(_tokenId, existing.value, existing.bidder);
            emit PendingRefund(existing.bidder, existing.value);
        }
        // Record the new bid
        bids[_tokenId] = Bid(msg.sender, msg.value, address(0));
        emit BidEntered(_tokenId, msg.value, msg.sender, address(0));
    }

    /**
     * @notice Allows home owners to accept bids submitted on their properties
     * @param tokenId tokenId of the property.
     * @param minPrice Minimum bidding price.
     */
    function acceptBid(
        uint256 tokenId,
        uint256 minPrice
    ) external whenNotPaused isTradingAllowed nonReentrant {
        Bid memory bid = bids[tokenId];

        require(
            msg.sender == mLife.ownerOf(tokenId),
            "You do not own this MLRE"
        );
        require(bid.value > 0, "No active bid on this MLRE");
        require(
            bid.value == minPrice,
            "The bid doesnt match the property value"
        );

        uint256 commission = 0;
        /// Transfer Commission to admin wallet
        if (adminPercent > 0) {
            commission = (bid.value * adminPercent) / PERCENTS_DIVIDER;
            adminPending += commission;
        }

        adminPending += commission;

        delete offers[tokenId];
        delete bids[tokenId];

        /// Transfer MLRE NFT to the Bidder
        mLife.transferFrom(msg.sender, bid.bidder, tokenId);

        /// Transfer ETH to seller
        _safeTransferETH(msg.sender, bid.value - commission);

        emit Bought(tokenId, bid.value, msg.sender, bid.bidder);
    }

    /**
     * @notice Allows bidders to withdraw their bid on a specific property.
     * @param tokenId tokenId of the property that is currently being bid.
     */
    function withdrawBid(
        uint256 tokenId
    ) external nonReentrant isTradingAllowed {
        Bid memory bid = bids[tokenId];
        require(bid.bidder == msg.sender, "No bid to withdraw");

        uint256 amount = bid.value;

        bids[tokenId] = Bid(address(0x0), 0, address(0));

        _safeTransferETH(msg.sender, amount);

        emit BidWithdrawn(tokenId, amount, address(0));
    }

    /**
     * @dev This records the address and ether value that was sent to the Marketplace
     */
    receive() external payable {
        emit Received(msg.sender, msg.value);
    }

    /// @dev Eth transfer hook
    function _safeTransferETH(address to, uint256 value) internal {
        (bool success, ) = to.call{value: value}("");
        require(
            success,
            "Address: unable to send value, recipient may have reverted"
        );
    }

    function withdrawRefunds() external nonReentrant {
        uint256 refund = pendingRefunds[msg.sender];
        require(refund > 0, "No refunds available");

        // Reset the refund balance before transferring the amount
        pendingRefunds[msg.sender] = 0;

        emit RefundSent(msg.sender, refund);

        // Transfer the balance to the caller
        (bool success, ) = msg.sender.call{value: refund}("");
        require(success, "Refund transfer failed");
    }

    /**
     * @notice Modifier to make users are not able to perform
     * market tradings on a certain period.
     *
     * @dev `allowTrading` should be set to `true` in order for the users to facilitate the
     * market trading by themselves.
     */
    modifier isTradingAllowed() {
        require(allowTrading, "Trading is disabled at this moment");
        _;
    }
}
