// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./ManageLife.sol";

/**
 * @notice Marketplace contract for ManageLife.
 * This contract the market trading of NFTs in the ML ecosystem.
 * In real life, an NFT here represents a home or real-estate property
 * run by ManageLife.
 *
 * @author https://managelife.co
 */
contract Marketplace is ReentrancyGuard, Pausable, Ownable {
    address public mlAdmin;

    /// Deployer address will be considered as the ML admins
    constructor() {
        mlAdmin = msg.sender;
    }

    /// Percent divider to calculate ML's transaction earnings.
    uint256 public constant PERCENTS_DIVIDER = 10000;

    /** @notice Trading status. This determines if normal users will be
     * allowed to permitted to perform market trading (Bidding, Selling, Buy).
     * By default Admin wallet will perform all these functions on behalf of all customers
     * due to legal requirements.
     * Once legal landscape permits, customers will be able to perform market trading by themselves.
     */
    bool public allowTrading = true;

    /// instance of the MLIFE NFT contract.
    ManageLife public mLife;

    struct Offer {
        uint32 tokenId;
        address seller;
        uint256 price;
        address offeredTo;
    }

    struct Bid {
        address bidder;
        uint256 value;
    }

    /// Default admin fee.
    uint256 public adminPercent = 200;

    /// Status for adming pending claimable earnings.
    uint256 public adminPending;

    /// Mapping of MLIFE tokenIds to Offers
    mapping(uint256 => Offer) public offers;

    /// Mapping of MLIFE tokenIds to Bids
    mapping(uint256 => Bid) public bids;

    event Offered(
        uint256 indexed tokenId,
        uint256 price,
        address indexed toAddress
    );

    event BidEntered(
        uint32 indexed tokenId,
        uint256 value,
        address indexed fromAddress
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
        address indexed toAddress,
        bool isInstant
    );
    event BidWithdrawn(uint256 indexed tokenId, uint256 value);
    event Cancelled(uint256 indexed tokenId);
    event TradingStatus(bool _isTradingAllowed);
    event Received(address, uint);

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
     * @notice Set the MLIFE contract.
     * @dev Important to set this after deployment. Only MLIFE address is needed.
     * Will not access 0x0 (zero/invalid) address.
     * @param nftAddress Address of MLIFE contract.
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

    /*Allows the owner of the contract to withdraw pending ETH */
    /**
     * @notice Withdraw marketplace earnings.
     * @dev Can only be triggered by the admin wallet or contract owner.
     * This will transfer the market earning to the admin wallet.
     */
    function withdraw() external onlyOwner nonReentrant {
        uint256 amount = adminPending;
        adminPending = 0;
        _safeTransferETH(mlAdmin, amount);
    }

    /**
     * @notice Cancel and existing sale offer.
     * @dev Once triggered, the offer struct for this tokenId will be destroyed.
     * Can only be called by MLIFE holders.
     * @param tokenId TokenId of the NFT.
     */
    function cancelForSale(uint32 tokenId) external onlyMLifeOwner(tokenId) {
        delete offers[tokenId];
        emit Cancelled(tokenId);
    }

    /**
     * @notice Offer a property or NFT for sale in the marketplace.
     *
     * @dev If `allowTrading` is equals to true,
     * users are allowed to execute this function. Else, admin wallet will facilitate
     * the offering sale on their behalf.
     *
     * @param tokenId MLIFE tokenId to be put on sale.
     * @param minSalePrice Minimum sale price of the property.
     */
    function offerForSale(
        uint32 tokenId,
        uint256 minSalePrice
    ) external whenNotPaused {
        if (allowTrading == false) {
            require(
                msg.sender == mlAdmin,
                "Trading is disabled at this moment, only Admin can trade"
            );
            offers[tokenId] = Offer(
                tokenId,
                msg.sender,
                minSalePrice,
                address(0x0)
            );
            emit Offered(tokenId, minSalePrice, address(0x0));
        } else {
            require(
                msg.sender == mLife.ownerOf(tokenId),
                "Only for the MLIFE owner"
            );
            offers[tokenId] = Offer(
                tokenId,
                msg.sender,
                minSalePrice,
                address(0x0)
            );
            emit Offered(tokenId, minSalePrice, address(0x0));
        }
    }

    /**
     * @notice Offer a property for sale to a specific wallet address only.
     *
     * @dev Allows MLIFE holders to sell their property to a specific wallet address.
     * By default, this process is being performed by the admin wallet on behalf of the customers
     * not until the `allowTrading` has been set to `true`.
     *
     * @param tokenId TokenId of the property to be offered.
     * @param minSalePrice Minimum sale prices of the property.
     * @param toAddress Wallet address on where the property will be offered to.
     */
    function offerForSaleToAddress(
        uint32 tokenId,
        uint256 minSalePrice,
        address toAddress
    ) external whenNotPaused {
        if (allowTrading == false) {
            require(
                msg.sender == mlAdmin,
                "Trading is disabled at this moment, only Admin can trade"
            );
            offers[tokenId] = Offer(
                tokenId,
                msg.sender,
                minSalePrice,
                toAddress
            );
        } else {
            require(
                msg.sender == mLife.ownerOf(tokenId),
                "Only for the MLIFE owner"
            );
            offers[tokenId] = Offer(
                tokenId,
                msg.sender,
                minSalePrice,
                toAddress
            );
            emit Offered(tokenId, minSalePrice, toAddress);
        }
    }

    /**
     * @notice Allows users to buy a property that is registered in ML.
     *
     * @dev By default, this operation is disabled for customers.
     * Only admin wallet can perform this on their behalf until the
     * `allowTrading` variable is equals to true.
     *
     * @param tokenId TokenId of the property.
     */
    function buy(uint32 tokenId) external payable whenNotPaused {
        if (allowTrading == false) {
            require(
                msg.sender == mlAdmin,
                "Trading is disabled at this moment, only Admin can trade"
            );

            Offer memory offer = offers[tokenId];
            uint256 amount = msg.value;
            require(
                offer.offeredTo == address(0x0) ||
                    offer.offeredTo == msg.sender,
                "This offer is not for you"
            );
            require(amount == offer.price, "Not enough ether");
            address seller = offer.seller;
            require(seller != msg.sender, "Seller == msg.sender");
            require(
                seller == mLife.ownerOf(tokenId),
                "Seller is not an MLIFE owner"
            );

            offers[tokenId] = Offer(tokenId, msg.sender, 0, address(0x0));

            /// Transfer to msg.sender from seller.
            mLife.transferFrom(seller, msg.sender, tokenId);

            /// Transfer commission to admin
            uint256 commission = 0;
            if (adminPercent > 0) {
                commission = (amount * adminPercent) / PERCENTS_DIVIDER;
                adminPending += commission;
            }

            /// Transfer ETH to seller
            _safeTransferETH(seller, amount - commission);

            emit Bought(tokenId, amount, seller, msg.sender, true);

            /// Refund bid if new owner is buyer
            Bid memory bid = bids[tokenId];
            if (bid.bidder == msg.sender) {
                _safeTransferETH(bid.bidder, bid.value);
                emit BidCancelled(tokenId, bid.value, bid.bidder);
                bids[tokenId] = Bid(address(0x0), 0);
            }
        } else {
            require(
                msg.sender == mLife.ownerOf(tokenId),
                "Only for the MLIFE owner"
            );

            Offer memory offer = offers[tokenId];
            uint256 amount = msg.value;
            require(
                offer.offeredTo == address(0x0) ||
                    offer.offeredTo == msg.sender,
                "This offer is not for you"
            );
            require(amount == offer.price, "Not enough ether");
            address seller = offer.seller;
            require(seller != msg.sender, "Seller == msg.sender");
            require(
                seller == mLife.ownerOf(tokenId),
                "Seller is not an MLIFE owner"
            );

            offers[tokenId] = Offer(tokenId, msg.sender, 0, address(0x0));

            /// Transfer to msg.sender from seller.
            mLife.transferFrom(seller, msg.sender, tokenId);

            /// Transfer commission to admin!
            uint256 commission = 0;
            if (adminPercent > 0) {
                commission = (amount * adminPercent) / PERCENTS_DIVIDER;
                adminPending += commission;
            }

            /// Transfer ETH to seller!
            _safeTransferETH(seller, amount - commission);

            emit Bought(tokenId, amount, seller, msg.sender, true);

            /// Refund bid if new owner is buyer
            Bid memory bid = bids[tokenId];
            if (bid.bidder == msg.sender) {
                _safeTransferETH(bid.bidder, bid.value);
                emit BidCancelled(tokenId, bid.value, bid.bidder);
                bids[tokenId] = Bid(address(0x0), 0);
            }
        }
    }

    /**
     * @notice Allows users to submit a bid to any properties.
     *
     * @dev By default, bidding is disabled for customers.
     * Only admin wallet can perform bidding on their behalf until the
     * `allowTrading` variable is equals to true.
     *
     * @param   tokenId tokenId of the property.
     */
    function placeBid(
        uint32 tokenId
    ) external payable whenNotPaused nonReentrant {
        if (allowTrading == false) {
            require(
                msg.sender == mlAdmin,
                "Trading is disabled at this moment, only Admin can trade"
            );

            require(msg.value != 0, "Cannot enter bid of zero");
            Bid memory existing = bids[tokenId];
            require(msg.value > existing.value, "Your bid is too low");
            if (existing.value > 0) {
                /// Refund existing bid
                _safeTransferETH(existing.bidder, existing.value);
                emit BidCancelled(tokenId, existing.value, existing.bidder);
            }
            bids[tokenId] = Bid(msg.sender, msg.value);
            emit BidEntered(tokenId, msg.value, msg.sender);
        } else {
            require(
                msg.sender == mLife.ownerOf(tokenId),
                "Only for the MLIFE owner"
            );

            require(
                mLife.ownerOf(tokenId) != msg.sender,
                "You already own this MLIFE"
            );
            require(msg.value != 0, "Cannot enter bid of zero");
            Bid memory existing = bids[tokenId];
            require(msg.value > existing.value, "Your bid is too low");
            if (existing.value > 0) {
                /// Refund existing bid
                _safeTransferETH(existing.bidder, existing.value);
                emit BidCancelled(tokenId, existing.value, existing.bidder);
            }
            bids[tokenId] = Bid(msg.sender, msg.value);
            emit BidEntered(tokenId, msg.value, msg.sender);
        }
    }

    /**
     * @notice Allows home owners to accept bids on their properties
     * @param tokenId tokenId of the property.
     * @param minPrice Minimum bidding price.
     */
    function acceptBid(
        uint32 tokenId,
        uint256 minPrice
    ) external whenNotPaused {
        if (allowTrading == false) {
            require(
                msg.sender == mlAdmin,
                "Trading is disabled at this moment, only Admin can trade"
            );
            address seller = msg.sender;
            Bid memory bid = bids[tokenId];
            uint256 amount = bid.value;
            require(amount != 0, "Cannot enter bid of zero");
            require(amount >= minPrice, "the bid is too low");

            address bidder = bid.bidder;
            require(seller != bidder, "You already own this token");
            offers[tokenId] = Offer(tokenId, bidder, 0, address(0x0));
            bids[tokenId] = Bid(address(0x0), 0);

            /// Transfer MLIFE to  Bidder
            mLife.transferFrom(msg.sender, bidder, tokenId);

            uint256 commission = 0;
            /// Transfering commission fee to admin wallet
            if (adminPercent > 0) {
                commission = (amount * adminPercent) / PERCENTS_DIVIDER;
                adminPending += commission;
            }

            /// Transfer ETH to seller
            _safeTransferETH(seller, amount - commission);

            emit Bought(tokenId, bid.value, seller, bidder, false);
        } else {
            require(
                msg.sender == mLife.ownerOf(tokenId),
                "Only for the MLIFE owner"
            );

            address seller = msg.sender;
            Bid memory bid = bids[tokenId];
            uint256 amount = bid.value;
            require(amount != 0, "Cannot enter bid of zero");
            require(amount >= minPrice, "The bid is too low");

            address bidder = bid.bidder;
            require(seller != bidder, "You already own this token");
            offers[tokenId] = Offer(tokenId, bidder, 0, address(0x0));
            bids[tokenId] = Bid(address(0x0), 0);

            /// Transfer MLIFE NFT to the Bidder
            mLife.transferFrom(msg.sender, bidder, tokenId);

            uint256 commission = 0;
            /// Transfer Commission to admin wallet
            if (adminPercent > 0) {
                commission = (amount * adminPercent) / PERCENTS_DIVIDER;
                adminPending += commission;
            }

            /// Transfer ETH to seller
            _safeTransferETH(seller, amount - commission);

            emit Bought(tokenId, bid.value, seller, bidder, false);
        }
    }

    /* Allows bidders to withdraw their bids */
    /**
     * @notice Allows bidders to withdraw their bid on a specific property.
     *
     * @dev There will be different process flows on this function depending
     * on the value of `allowTrading`. By default, the entire trading will be
     * facilitated by the admin wallet.
     *
     * @param tokenId tokenId of the property that is currently being bid.
     */
    function withdrawBid(uint32 tokenId) external nonReentrant {
        if (allowTrading == false) {
            require(
                msg.sender == mlAdmin,
                "Trading is disabled at this moment, only Admin can trade"
            );

            Bid memory bid = bids[tokenId];
            uint256 amount = bid.value;
            emit BidWithdrawn(tokenId, amount);
            bids[tokenId] = Bid(address(0x0), 0);
            _safeTransferETH(msg.sender, amount);
        } else {
            require(
                msg.sender == mLife.ownerOf(tokenId),
                "Only for the MLIFE owner"
            );
            Bid memory bid = bids[tokenId];
            require(
                bid.bidder == msg.sender,
                "The Sender is not original bidder"
            );
            uint256 amount = bid.value;
            emit BidWithdrawn(tokenId, amount);
            bids[tokenId] = Bid(address(0x0), 0);
            _safeTransferETH(msg.sender, amount);
        }
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

    /**
     * @notice Allow admins to set new ML Admin wallet.
     * Only contract owner/deployer can execute this function
     *
     * @param newAdminAddress New wallet address to be used.
     */
    function setMLAdmin(address newAdminAddress) external onlyOwner {
        mlAdmin = newAdminAddress;
    }

    /**
     * @notice Modifier to make sure only MLIFE
     * NFT holders can run a specific functions.
     */
    modifier onlyMLifeOwner(uint256 tokenId) {
        require(
            msg.sender == mLife.ownerOf(tokenId),
            "Only for the MLIFE owner"
        );
        _;
    }

    /**
     * @notice Modifier to make sure only admin wallet can perform
     * market tradings on behalf of all users.
     *
     * @dev `allowTrading` should be set to `true` in order for the users to facilitate the
     * market trading by themselves.
     */
    modifier isTradingAllowed() {
        if (allowTrading == false) {
            require(
                msg.sender == mlAdmin,
                "Trading is disabled, only Admin can trade."
            );
            _;
        }
    }
}
