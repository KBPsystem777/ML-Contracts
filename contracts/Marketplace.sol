// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "./ManageLife.sol";

// @title ManageLife Marketplace contract
// @notice This is the smart contract for ML marketplace
contract Marketplace is ReentrancyGuard, Pausable, Ownable {
    using Address for address;

    uint256 public constant PERCENTS_DIVIDER = 10000;

    address public mlAdmin;

    // If set to false, this will resctrict customers to perform
    // market trading hence only ML admins are allowed to trade
    bool public allowTrading = true;

    ManageLife public mLife; // instance of the MLIFE NFT contract

    struct Offer {
        bool isForSale;
        uint32 offerId;
        address seller;
        uint256 price;
        address offeredTo;
    }

    struct Bid {
        uint32 id;
        address bidder;
        uint256 value;
    }

    // Admin Fee
    uint256 public adminPercent = 200;
    uint256 public adminPending;

    // A record of homes that are offered for sale at a specific minimum value, and perhaps to a specific person
    mapping(uint256 => Offer) public offers;

    // A record of the highest home bid
    mapping(uint256 => Bid) public bids;

    event Offered(uint256 indexed id, uint256 price, address indexed toAddress);
    event BidEntered(
        uint256 indexed id,
        uint256 value,
        address indexed fromAddress
    );
    event BidWithdrawn(uint256 indexed id, uint256 value);
    event BidCancelled(
        uint256 indexed id,
        uint256 value,
        address indexed bidder
    );
    event Bought(
        uint256 indexed id,
        uint256 value,
        address indexed fromAddress,
        address indexed toAddress,
        bool isInstant
    );
    event Cancelled(uint256 indexed id);
    event TradingStatus(bool _isTradingAllowed);

    constructor() {
        mlAdmin = msg.sender;
    }

    function pause() external whenNotPaused onlyOwner {
        _pause();
    }

    function unpause() external whenPaused onlyOwner {
        _unpause();
    }

    function setTrading(bool _isTradingAllowed) external onlyOwner {
        allowTrading = _isTradingAllowed;
        emit TradingStatus(_isTradingAllowed);
    }

    /* Allows the owner of the contract to set a new contract address */
    function setNftContract(address newAddress) external onlyOwner {
        require(newAddress != address(0x0), "zero address");
        mLife = ManageLife(newAddress);
    }

    /* Allows the owner of the contract to set a new Admin Fee Percentage */
    function setAdminPercent(uint256 _percent) external onlyOwner {
        require(_percent < 500, "invalid percent");
        adminPercent = _percent;
    }

    /*Allows the owner of the contract to withdraw pending ETH */
    function withdraw() external onlyOwner nonReentrant {
        uint256 amount = adminPending;
        adminPending = 0;
        _safeTransferETH(msg.sender, amount);
    }

    /* Allows the owner to stop offering it for sale */
    function cancelForSale(uint32 id) external onlyMLifeOwner(id) {
        offers[id] = Offer(false, id, msg.sender, 0, address(0x0));
        emit Cancelled(id);
    }

    /* Allows a owner to offer it for sale */
    function offerForSale(
        uint32 offerId,
        uint256 minSalePrice
    ) external whenNotPaused {
        if (allowTrading == false) {
            require(
                msg.sender == mlAdmin,
                "Trading is disabled at this moment, only Admin can trade"
            );
            offers[offerId] = Offer(
                true,
                offerId,
                msg.sender,
                minSalePrice,
                address(0x0)
            );
            emit Offered(offerId, minSalePrice, address(0x0));
        } else {
            require(
                msg.sender == mLife.ownerOf(offerId),
                "Only for the MLIFE owner"
            );
            offers[offerId] = Offer(
                true,
                offerId,
                msg.sender,
                minSalePrice,
                address(0x0)
            );
            emit Offered(offerId, minSalePrice, address(0x0));
        }
    }

    /* Allows a owner to offer it for sale to a specific address */
    function offerForSaleToAddress(
        uint32 offerId,
        uint256 minSalePrice,
        address toAddress
    ) external whenNotPaused {
        if (allowTrading == false) {
            require(
                msg.sender == mlAdmin,
                "Trading is disabled at this moment, only Admin can trade"
            );
            offers[offerId] = Offer(
                true,
                offerId,
                msg.sender,
                minSalePrice,
                toAddress
            );
        } else {
            require(
                msg.sender == mLife.ownerOf(offerId),
                "Only for the MLIFE owner"
            );
            offers[offerId] = Offer(
                true,
                offerId,
                msg.sender,
                minSalePrice,
                toAddress
            );
            emit Offered(offerId, minSalePrice, toAddress);
        }
    }

    /* Allows users to buy a offered for sale */
    function buy(uint32 id) external payable whenNotPaused {
        if (allowTrading == false) {
            require(
                msg.sender == mlAdmin,
                "Trading is disabled at this moment, only Admin can trade"
            );

            Offer memory offer = offers[id];
            uint256 amount = msg.value;
            require(offer.isForSale, "MLIFE is not for sale");
            require(
                offer.offeredTo == address(0x0) ||
                    offer.offeredTo == msg.sender,
                "this offer is not for you"
            );
            require(amount == offer.price, "not enough ether");
            address seller = offer.seller;
            require(seller != msg.sender, "seller == msg.sender");
            require(
                seller == mLife.ownerOf(id),
                "seller no longer owner of MLIFE"
            );

            offers[id] = Offer(false, id, msg.sender, 0, address(0x0));

            // Transfer to msg.sender from seller.
            mLife.transferFrom(seller, msg.sender, id);

            // Transfer commission to admin!
            uint256 commission = 0;
            if (adminPercent > 0) {
                commission = (amount * adminPercent) / PERCENTS_DIVIDER;
                adminPending += commission;
            }

            // Transfer ETH to seller!
            _safeTransferETH(seller, amount - commission);

            emit Bought(id, amount, seller, msg.sender, true);

            // refund bid if new owner is buyer!
            Bid memory bid = bids[id];
            if (bid.bidder == msg.sender) {
                _safeTransferETH(bid.bidder, bid.value);
                emit BidCancelled(id, bid.value, bid.bidder);
                bids[id] = Bid(id, address(0x0), 0);
            }
        } else {
            require(
                msg.sender == mLife.ownerOf(id),
                "Only for the MLIFE owner"
            );

            Offer memory offer = offers[id];
            uint256 amount = msg.value;
            require(offer.isForSale, "MLIFE is not for sale");
            require(
                offer.offeredTo == address(0x0) ||
                    offer.offeredTo == msg.sender,
                "this offer is not for you"
            );
            require(amount == offer.price, "not enough ether");
            address seller = offer.seller;
            require(seller != msg.sender, "seller == msg.sender");
            require(
                seller == mLife.ownerOf(id),
                "seller no longer owner of MLIFE"
            );

            offers[id] = Offer(false, id, msg.sender, 0, address(0x0));

            // Transfer to msg.sender from seller.
            mLife.transferFrom(seller, msg.sender, id);

            // Transfer commission to admin!
            uint256 commission = 0;
            if (adminPercent > 0) {
                commission = (amount * adminPercent) / PERCENTS_DIVIDER;
                adminPending += commission;
            }

            // Transfer ETH to seller!
            _safeTransferETH(seller, amount - commission);

            emit Bought(id, amount, seller, msg.sender, true);

            // refund bid if new owner is buyer!
            Bid memory bid = bids[id];
            if (bid.bidder == msg.sender) {
                _safeTransferETH(bid.bidder, bid.value);
                emit BidCancelled(id, bid.value, bid.bidder);
                bids[id] = Bid(id, address(0x0), 0);
            }
        }
    }

    /* Allows users to enter bids for any properties */
    function placeBid(uint32 id) external payable whenNotPaused nonReentrant {
        if (allowTrading == false) {
            require(
                msg.sender == mlAdmin,
                "Trading is disabled at this moment, only Admin can trade"
            );

            require(msg.value != 0, "cannot enter bid of zero");
            Bid memory existing = bids[id];
            require(msg.value > existing.value, "your bid is too low");
            if (existing.value > 0) {
                // Refund existing bid
                _safeTransferETH(existing.bidder, existing.value);
                emit BidCancelled(id, existing.value, existing.bidder);
            }
            bids[id] = Bid(id, msg.sender, msg.value);
            emit BidEntered(id, msg.value, msg.sender);
        } else {
            require(
                msg.sender == mLife.ownerOf(id),
                "Only for the MLIFE owner"
            );

            require(
                mLife.ownerOf(id) != msg.sender,
                "You already own this MLIFE"
            );
            require(msg.value != 0, "cannot enter bid of zero");
            Bid memory existing = bids[id];
            require(msg.value > existing.value, "your bid is too low");
            if (existing.value > 0) {
                // Refund existing bid
                _safeTransferETH(existing.bidder, existing.value);
                emit BidCancelled(id, existing.value, existing.bidder);
            }
            bids[id] = Bid(id, msg.sender, msg.value);
            emit BidEntered(id, msg.value, msg.sender);
        }
    }

    /* Allows owners to accept bids for their MLIFE */
    function acceptBid(uint32 id, uint256 minPrice) external whenNotPaused {
        if (allowTrading == false) {
            require(
                msg.sender == mlAdmin,
                "Trading is disabled at this moment, only Admin can trade"
            );
            address seller = msg.sender;
            Bid memory bid = bids[id];
            uint256 amount = bid.value;
            require(amount != 0, "cannot enter bid of zero");
            require(amount >= minPrice, "the bid is too low");

            address bidder = bid.bidder;
            require(seller != bidder, "you already own this token");
            offers[id] = Offer(false, id, bidder, 0, address(0x0));
            bids[id] = Bid(id, address(0x0), 0);

            // Transfer MLIFE to  Bidder
            mLife.transferFrom(msg.sender, bidder, id);

            uint256 commission = 0;
            // Transfer Commission!
            if (adminPercent > 0) {
                commission = (amount * adminPercent) / PERCENTS_DIVIDER;
                adminPending += commission;
            }

            // Transfer ETH to seller!
            _safeTransferETH(seller, amount - commission);

            emit Bought(id, bid.value, seller, bidder, false);
        } else {
            require(
                msg.sender == mLife.ownerOf(id),
                "Only for the MLIFE owner"
            );

            address seller = msg.sender;
            Bid memory bid = bids[id];
            uint256 amount = bid.value;
            require(amount != 0, "cannot enter bid of zero");
            require(amount >= minPrice, "the bid is too low");

            address bidder = bid.bidder;
            require(seller != bidder, "you already own this token");
            offers[id] = Offer(false, id, bidder, 0, address(0x0));
            bids[id] = Bid(id, address(0x0), 0);

            // Transfer MLIFE to  Bidder
            mLife.transferFrom(msg.sender, bidder, id);

            uint256 commission = 0;
            // Transfer Commission!
            if (adminPercent > 0) {
                commission = (amount * adminPercent) / PERCENTS_DIVIDER;
                adminPending += commission;
            }

            // Transfer ETH to seller!
            _safeTransferETH(seller, amount - commission);

            emit Bought(id, bid.value, seller, bidder, false);
        }
    }

    /* Allows bidders to withdraw their bids */
    function withdrawBid(uint32 id) external nonReentrant {
        if (allowTrading == false) {
            require(
                msg.sender == mlAdmin,
                "Trading is disabled at this moment, only Admin can trade"
            );

            Bid memory bid = bids[id];
            uint256 amount = bid.value;
            emit BidWithdrawn(id, amount);
            bids[id] = Bid(id, address(0x0), 0);
            _safeTransferETH(msg.sender, amount);
        } else {
            require(
                msg.sender == mLife.ownerOf(id),
                "Only for the MLIFE owner"
            );
            Bid memory bid = bids[id];
            require(
                bid.bidder == msg.sender,
                "The Sender is not original bidder"
            );
            uint256 amount = bid.value;
            emit BidWithdrawn(id, amount);
            bids[id] = Bid(id, address(0x0), 0);
            _safeTransferETH(msg.sender, amount);
        }
    }

    // TODO: Address this empty receive function by building a record keeping routines
    receive() external payable {}

    function _safeTransferETH(address to, uint256 value) internal {
        (bool success, ) = to.call{value: value}("");
        require(
            success,
            "Address: unable to send value, recipient may have reverted"
        );
    }

    function setMLAdmin(address newAdminAddress) external onlyOwner {
        mlAdmin = newAdminAddress;
    }

    modifier onlyMLifeOwner(uint256 tokenId) {
        require(
            msg.sender == mLife.ownerOf(tokenId),
            "Only for the MLIFE owner"
        );
        _;
    }

    /*** @notice Modifier to make sure only ML Admin can perform tradings on behalf of users if `allowTrading` == false  */
    modifier isTradingAllowed() {
        if (allowTrading == false) {
            require(
                msg.sender == mlAdmin,
                "Trading is disabled at this moment, only Admin can trade"
            );
            _;
        }
    }
}
