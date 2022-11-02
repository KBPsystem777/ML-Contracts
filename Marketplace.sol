// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

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

    ManageLife mLife; // instance of the NFT contract

    struct Offer {
        bool isForSale;
        uint256 id;
        address seller;
        uint256 minValue; // in ether
        address onlySellTo;
    }

    struct Bid {
        uint256 id;
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

    event Offered(
        uint256 indexed id,
        uint256 minValue,
        address indexed toAddress
    );
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
    event FreeMarket(bool isFreeMarket);

    constructor() {}

    function pause() external whenNotPaused onlyOwner {
        _pause();
    }

    function unpause() external whenPaused onlyOwner {
        _unpause();
    }

    /* Returns the MLIFE contract address currently being used */
    function mlifeAddress() external view returns (address) {
        return address(mLife);
    }

    /* Allows the owner of the contract to set a new contract address */
    function setContract(address newAddress) external onlyOwner {
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
    function cancelForSale(uint256 id) external onlyMLifeOwner(id) {
        offers[id] = Offer(false, id, msg.sender, 0, address(0x0));
        emit Cancelled(id);
    }

    /* Allows a owner to offer it for sale */
    function offerForSale(uint256 id, uint256 minSalePrice)
        external
        onlyMLifeOwner(id)
        whenNotPaused
    {
        offers[id] = Offer(true, id, msg.sender, minSalePrice, address(0x0));
        emit Offered(id, minSalePrice, address(0x0));
    }

    /* Allows a owner to offer it for sale to a specific address */
    function offerForSaleToAddress(
        uint256 id,
        uint256 minSalePrice,
        address toAddress
    ) external onlyMLifeOwner(id) whenNotPaused {
        offers[id] = Offer(true, id, msg.sender, minSalePrice, toAddress);
        emit Offered(id, minSalePrice, toAddress);
    }

    /* Allows users to buy a offered for sale */
    function buy(uint256 id) external payable whenNotPaused nonReentrant {
        Offer memory offer = offers[id];
        uint256 amount = msg.value;
        require(offer.isForSale, "MLIFE is not for sale");
        require(
            offer.onlySellTo == address(0x0) || offer.onlySellTo == msg.sender,
            "this offer is not for you"
        );
        require(amount == offer.minValue, "not enough ether");
        address seller = offer.seller;
        require(seller != msg.sender, "seller == msg.sender");
        require(seller == mLife.ownerOf(id), "seller no longer owner of MLIFE");

        offers[id] = Offer(false, id, msg.sender, 0, address(0x0));

        // Transfer to msg.sender from seller.
        mLife.safeTransferFrom(seller, msg.sender, id);

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

    /* Allows users to enter bids for any properties */
    function placeBid(uint256 id) external payable whenNotPaused nonReentrant {
        require(mLife.ownerOf(id) != msg.sender, "you already own this MLIFE");
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

    /* Allows owners to accept bids for their MLIFE */
    function acceptBid(uint256 id, uint256 minPrice)
        external
        onlyMLifeOwner(id)
        whenNotPaused
        nonReentrant
    {
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
        mLife.safeTransferFrom(msg.sender, bidder, id);

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

    /* Allows bidders to withdraw their bids */
    function withdrawBid(uint256 id) external nonReentrant {
        Bid memory bid = bids[id];
        require(bid.bidder == msg.sender, "the bidder is not msg sender");
        uint256 amount = bid.value;
        emit BidWithdrawn(id, amount);
        bids[id] = Bid(id, address(0x0), 0);
        _safeTransferETH(msg.sender, amount);
    }

    receive() external payable {}

    function _safeTransferETH(address to, uint256 value) internal {
        Address.sendValue(payable(to), value);
    }

    modifier onlyMLifeOwner(uint256 tokenId) {
        require(mLife.ownerOf(tokenId) == msg.sender, "only for MLIFE owner");
        _;
    }
}
