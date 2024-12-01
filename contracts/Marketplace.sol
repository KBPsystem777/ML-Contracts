// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "./ManageLife.sol";

/**
 * @notice Marketplace contract for ManageLife.
 * This contract is the market trading of NFTs in the ML ecosystem.
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
    constructor(
        address _lifeToken,
        address _usdt,
        address _usdc
    ) Ownable(msg.sender) Pausable() ReentrancyGuard() {
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

    /// Mapping for pending ETH refunds
    mapping(address => uint256) public pendingETHRefunds;

    /// Maping for pending token refunds
    mapping(address => mapping(address => uint256)) public pendingTokenRefunds;

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
    event MarketplaceAmtReceived(address, uint);
    event PendingRefund(address indexed bidder, uint256 refundAmount);
    event ETHRefundSent(address indexed owner, uint256 refundAmount);
    event TokenRefundSent(
        address indexed owner,
        uint256 refundAmount,
        address tokenType
    );
    event AdminWithdrawal(uint256 amount);
    event AdminPercentageUpdated(uint256 newAmount);

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
        emit AdminPercentageUpdated(_percent);
    }

    function safeTransferERC20(
        IERC20 token,
        address to,
        uint256 amount
    ) internal {
        token.safeTransfer(to, amount);
    }

    /**
     * @notice Withdrawal of marketplace earnings by the Admin.
     * @dev Can only be triggered by the admin wallet or contract owner.
     * This will transfer all pending earnings in ETH or tokens to the admin wallet.
     */
    function withdraw() external onlyOwner nonReentrant {
        // Withdraw pending ETH
        uint256 ethEarnings = adminPending;
        if (ethEarnings > 0) {
            adminPending = 0; // Resetting the earnings mapping
            _safeTransferETH(owner(), ethEarnings);
            emit AdminWithdrawal(ethEarnings);
        }

        // Withdraw $MLIFE token earnings
        uint256 mlifeEarnings = pendingTokenRefunds[owner()][
            address(lifeToken)
        ];
        if (mlifeEarnings > 0) {
            pendingTokenRefunds[owner()][address(lifeToken)] = 0; // Resetting the earnings mapping
            lifeToken.safeTransfer(owner(), mlifeEarnings);
            emit TokenRefundSent(owner(), mlifeEarnings, address(lifeToken));
        }

        // Withdraw USDT token earnings
        uint256 usdtEarnings = pendingTokenRefunds[owner()][address(usdt)];
        if (usdtEarnings > 0) {
            pendingTokenRefunds[owner()][address(usdt)] = 0; // Resetting the earnings mapping
            usdt.safeTransfer(owner(), usdtEarnings);
            emit TokenRefundSent(owner(), usdtEarnings, address(usdt));
        }

        // Withdraw USDC token earnings
        uint256 usdcEarnings = pendingTokenRefunds[owner()][address(usdc)];
        if (usdcEarnings > 0) {
            pendingTokenRefunds[owner()][address(usdc)] = 0; // Resetting the earnings mapping
            usdc.safeTransfer(owner(), usdcEarnings);
            emit TokenRefundSent(owner(), usdcEarnings, address(usdc));
        }

        // Ensuring at least one withdrawal was processed
        require(
            ethEarnings > 0 ||
                mlifeEarnings > 0 ||
                usdtEarnings > 0 ||
                usdcEarnings > 0,
            "No earnings to withdraw"
        );
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
     * Can be offered in any of the following supported payment methods: ETH, MLIFE, USDT and USDC
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
     * Can be offered in any of the following supported payment methods: ETH, MLIFE, USDT and USDC
     * @param tokenId TokenId of the property to be offered.
     * @param minSalePrice Minimum sale prices of the property.
     * @param toAddress Wallet address on where the property will be offered to.
     * @param paymentToken Mode of payment either via ETH or ERC20 tokens (MLIFE, USDT, USDC)
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
     * Supported payment methods: ETH, MLIFE, USDT and USDC
     * @dev Anyone (public) can buy an MLRE property.
     * @param tokenId TokenId of the property.
     */
    function buy(
        uint256 tokenId
    ) external payable whenNotPaused isTradingAllowed nonReentrant {
        Offer memory offer = offers[tokenId];

        address seller = offer.seller;
        uint256 amount = msg.value;

        // Ensure the seller is still the owner of the token
        require(mLife.ownerOf(tokenId) == seller, "NFT transfer failed");
        require(seller != msg.sender, "Seller cannot be buyer");

        // Making sure the property is offered publicly or offered directly to the caller
        require(
            offer.offeredTo == address(0) || offer.offeredTo == msg.sender,
            "This offer is not for you"
        );

        require(offer.price > 0, "Price must be greater than zero");

        // Deleting the offers mapping once sell is confirmed
        delete offers[tokenId];

        // Calculate and allocate commission
        uint256 commission = 0;
        if (adminPercent > 0) {
            commission = (amount * adminPercent) / PERCENTS_DIVIDER;
            adminPending += commission;
        }

        emit Bought(tokenId, amount, seller, msg.sender);
        uint256 sellerEarnings = offer.price - commission;

        if (offer.paymentToken == address(0)) {
            require(msg.value == offer.price, "ETH does not match offer");
            _safeTransferETH(seller, sellerEarnings);
        } else if (offer.paymentToken == address(lifeToken)) {
            safeTransferERC20(lifeToken, seller, sellerEarnings);
        } else if (offer.paymentToken == address(usdt)) {
            safeTransferERC20(usdt, seller, sellerEarnings);
        } else if (offer.paymentToken == address(usdc)) {
            safeTransferERC20(usdc, seller, sellerEarnings);
        }

        // Handle bid cancellation if buyer was also highest bidder
        Bid memory bid = bids[tokenId];
        if (bid.bidder == msg.sender) {
            delete bids[tokenId];
            _safeTransferETH(bid.bidder, bid.value);
            emit BidCancelled(tokenId, bid.value, bid.bidder);
        }

        // Transfer NFT using safeTransferFrom to accommodate EOAs and contract accounts
        mLife.safeTransferFrom(seller, msg.sender, tokenId);
    }

    /**
     * @notice Allows users to submit a bid to any offered properties. Payment type can be ETH ot ERC20 tokens.
     * @dev Anyone in public can submit a bid on a property.
     * @param _tokenId tokenId of the property.
     */
    function placeBid(
        uint256 _tokenId,
        uint256 _bidAmount,
        address _paymentToken
    ) external payable whenNotPaused nonReentrant isTradingAllowed {
        Bid memory existing = bids[_tokenId];

        require(
            msg.value == existing.value,
            "You bid does not match the property price"
        );

        require(
            _paymentToken == address(lifeToken) ||
                _paymentToken == address(usdt) ||
                _paymentToken == address(usdc) ||
                _paymentToken == address(0),
            "Unsupported payment method"
        );

        // ETH payment
        if (_paymentToken == address(0)) {
            require(
                msg.value == existing.value,
                "You bid does not match the property price"
            );
            // Refund the previous bidder if possible
            if (existing.value > 0 && existing.paymentToken == address(0)) {
                _safeTransferETH(existing.bidder, existing.value);
                emit PendingRefund(existing.bidder, existing.value);
            }
            delete bids[_tokenId];
        } else {
            // ERC20 payments
            require(_bidAmount > existing.value, "Your bid mmust be higher");

            IERC20 token = IERC20(_paymentToken);

            // Ensuring the bidder has sufficient token funds
            require(
                token.balanceOf(msg.sender) >= _bidAmount,
                "Token balance too low"
            );

            // Refunding the previous bidder if possible
            if (
                existing.value > 0 &&
                existing.paymentToken != address(0) &&
                existing.paymentToken == _paymentToken
            ) {
                IERC20(existing.paymentToken).safeTransfer(
                    existing.bidder,
                    existing.value
                );
                emit PendingRefund(existing.bidder, existing.value);
            }

            // Transferring the bid amount to the contract
            token.safeTransferFrom(msg.sender, address(this), _bidAmount);

            // Update the bid
            bids[_tokenId] = Bid(msg.sender, _bidAmount, _paymentToken);
        }
        emit BidEntered(
            _tokenId,
            bids[_tokenId].value,
            msg.sender,
            _paymentToken
        );
    }

    /**
     * @notice Allows home owners to accept bids submitted on their properties.
     * @param tokenId tokenId of the property.
     * @param minPrice Sale price of the property
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
        require(bid.value > 0, "No valid bid to accept");
        require(
            bid.value == minPrice,
            "The bid doesnt match the property value"
        );

        // Removing the bid and offers after accepting
        delete offers[tokenId];
        delete bids[tokenId];

        // Calculating the seller earnings and ManageLife's commissions
        uint256 commission = (bid.value * adminPercent) / PERCENTS_DIVIDER;
        uint256 sellerEarnings = bid.value - commission;

        // Add commission to the admin's pending earnings
        adminPending += commission;

        // Logic to determine what payment method to use in sending the seller earnings
        if (bid.paymentToken == address(0)) {
            // Handle ETH payments
            _safeTransferETH(msg.sender, sellerEarnings);
        } else if (bid.paymentToken == address(lifeToken)) {
            // Handle $MLIFE token payment
            safeTransferERC20(lifeToken, msg.sender, sellerEarnings);
        } else if (bid.paymentToken == address(usdt)) {
            safeTransferERC20(usdt, msg.sender, sellerEarnings);
        } else if (bid.paymentToken == address(usdc)) {
            safeTransferERC20(usdc, msg.sender, sellerEarnings);
        } else {
            revert("Unsupported payment method");
        }

        /// Transfer MLRE NFT to the Bidder
        mLife.transferFrom(msg.sender, bid.bidder, tokenId);

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
        emit MarketplaceAmtReceived(msg.sender, msg.value);
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
        uint256 ethRefund = pendingETHRefunds[msg.sender];
        uint256 tokenRefund;
        address tokenAddress;

        // Check if there's an ETH refund
        if (ethRefund > 0) {
            // Clearing the mapping of ETH
            pendingETHRefunds[msg.sender] = 0;

            emit ETHRefundSent(msg.sender, ethRefund);

            (bool success, ) = msg.sender.call{value: ethRefund}("");
            require(success, "ETH transfer failed");
        }

        // Iterate through the possible token type refunds
        // $MLIFE
        if (pendingTokenRefunds[msg.sender][address(lifeToken)] > 0) {
            tokenAddress = address(lifeToken);
            tokenRefund = pendingTokenRefunds[msg.sender][tokenAddress];
            pendingTokenRefunds[msg.sender][tokenAddress] = 0;

            emit TokenRefundSent(msg.sender, tokenRefund, tokenAddress);
            // Transfer the $MLIFE token to the user
            IERC20(tokenAddress).safeTransfer(msg.sender, tokenRefund);
        }
        // USDT
        if (pendingTokenRefunds[msg.sender][address(usdt)] > 0) {
            tokenAddress = address(usdt);
            tokenRefund = pendingTokenRefunds[msg.sender][tokenAddress];
            pendingTokenRefunds[msg.sender][tokenAddress] = 0;

            emit TokenRefundSent(msg.sender, tokenRefund, tokenAddress);
            // Transfer the USDT token to the user
            IERC20(tokenAddress).safeTransfer(msg.sender, tokenRefund);
        }
        // USDC
        if (pendingTokenRefunds[msg.sender][address(usdc)] > 0) {
            tokenAddress = address(usdc);
            tokenRefund = pendingTokenRefunds[msg.sender][tokenAddress];
            pendingTokenRefunds[msg.sender][tokenAddress] = 0;

            emit TokenRefundSent(msg.sender, tokenRefund, tokenAddress);
            // Transfer the USDC token to the user
            IERC20(tokenAddress).safeTransfer(msg.sender, tokenRefund);
        }
        // Ensure there's at least one refund processed
        require(ethRefund > 0 || tokenRefund > 0, "No refunds available");
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
