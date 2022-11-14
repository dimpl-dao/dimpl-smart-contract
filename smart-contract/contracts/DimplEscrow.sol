// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (utils/escrow/Escrow.sol)

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/Timers.sol";
import "./DimplERC20.sol";


contract DimplEscrow is Ownable {
    using Address for address payable;
    using Timers for Timers.BlockNumber;

    event BidCreated(uint256 bidHash, address buyer, uint256 depositInPeb, uint256 listingHash, uint128 nonce);
    event ListingCreated(uint256 listingHash, address seller, uint256 depositInPeb, uint256 priceInPeb, uint128 nonce);
    event BidCanceled(uint256 bidHash);
    event ListingCanceled(uint256 listingHash);
    event BidSelected(uint256 bidHash);
    event TransactionForceCanceled(uint256 listingHash);
    event TransactionForceApproved(uint256 listingHash);
    event TransactionApproved(uint256 listingHash);

    struct Listing {
        address seller;
        uint256 depositInPeb;
        uint256 priceInPeb;
        uint256 bidHash; 
        uint128 bidSelectedBlock;
        uint128 remonstrableBlockInterval;
        uint256[] bidHashes;      
    }

    struct Bid {
        address buyer;
        uint128 bidCreatedBlock;
        uint256 depositInPeb;
        uint256 listingHash;
    }

    mapping(uint256 => Bid) public bids;
    mapping(uint256 => Listing) public listings;

    address public governanceTokenContract;
    uint16 public listingMinDepositBasisPts = 300;
    uint16 public bidMinDepositBasisPts = 300;
    uint256 public transactionFeeBasisPts = 30;
    uint256 public blockToWeek = 604800;

    modifier ifNotTransacting(uint256 listingHash) {
        require(listings[listingHash].bidHash == 0);
        _;
    }

    modifier onlyTransacting(uint256 listingHash) {
        require(listings[listingHash].bidHash != 0);
        _;
    }

    constructor(address _governanceTokenContract){
        governanceTokenContract = _governanceTokenContract;
        bids[0].buyer = msg.sender; // listings with bidHash of 0 are regarded as not transacting -> initialize to avoid a bidding with a hash of 0
    }

    function setListingMinDepositBasisPts(uint16 _listingMinDepositBasisPts) external onlyOwner {
        require(_listingMinDepositBasisPts < 10000);
        listingMinDepositBasisPts = _listingMinDepositBasisPts;
    }

    function setBidMinDepositBasisPts(uint16 _bidMinDepositBasisPts) external onlyOwner {
        require(_bidMinDepositBasisPts < 10000);
        bidMinDepositBasisPts = _bidMinDepositBasisPts;
    }

    function setTransactionFeeBasisPts(uint16 _transactionFeeBasisPts) external onlyOwner {
        transactionFeeBasisPts = _transactionFeeBasisPts;
    }

    function setblockToWeek(uint256 _blockToWeek) external onlyOwner {
        blockToWeek = _blockToWeek;
    }

    function callDimpleERC20(bytes calldata _calldata) external payable onlyOwner returns (bytes memory) {
        (bool success, bytes memory returndata) = governanceTokenContract.call{value: msg.value}(_calldata);
        return Address.verifyCallResult(success, returndata, "callDimpleERC20 reverted");
    }

    function list(uint256 priceInPeb, uint128 nonce, uint128 remonstrableBlockInterval) external payable returns (uint256) {
        require(priceInPeb > 0);
        require(_getBasisPts(msg.value, priceInPeb) >= listingMinDepositBasisPts);
        uint256 listingHash = _hashListing(msg.sender, msg.value, priceInPeb, nonce);
        require(listings[listingHash].seller == address(0x0));

        listings[listingHash] = Listing(msg.sender, msg.value, priceInPeb, 0, 0, remonstrableBlockInterval, new uint256[](0));

        emit ListingCreated(listingHash, msg.sender, msg.value, priceInPeb, nonce);

        return listingHash;
    }

    function bid(uint256 depositInPeb, uint256 listingHash, uint128 nonce) external payable ifNotTransacting(listingHash) returns (uint256) {
        require(listings[listingHash].seller != address(0));
        require(msg.value >= depositInPeb + listings[listingHash].priceInPeb);
        require(listings[listingHash].priceInPeb > 0);
        require(_getBasisPts(depositInPeb, listings[listingHash].priceInPeb) >= bidMinDepositBasisPts);
        uint256 bidHash = _hashBid(msg.sender, depositInPeb, listingHash);
        require(bids[bidHash].buyer == address(0));

        bids[bidHash] = Bid(msg.sender, uint128(block.number), depositInPeb, listingHash);
        listings[listingHash].bidHashes.push(bidHash);

        emit BidCreated(bidHash, msg.sender, depositInPeb, listingHash, nonce);

        return bidHash;
    }

    function cancelBid(uint256 bidHash) external returns (address) {
        require(bids[bidHash].buyer == msg.sender);
        require(listings[bids[bidHash].listingHash].bidHash != bidHash);

        return _cancelBid(bidHash);
    }

    function cancelListing(uint256 listingHash) external ifNotTransacting(listingHash) returns (address) {
        require(listings[listingHash].seller == msg.sender);
        
        return _cancelListing(listingHash);
    }

    function selectBid(uint256 listingHash, uint256 bidHash) external ifNotTransacting(listingHash) returns (uint256) {
        require(listings[listingHash].seller == msg.sender);
        require(bids[bidHash].listingHash == listingHash);
        
        listings[listingHash].bidHash = bidHash;
        listings[listingHash].bidSelectedBlock = uint128(block.number);
        _cancelBidsOfExcept(listingHash, bidHash);

        emit BidSelected(bidHash);

        return bidHash;
    }

    function forceCancelTransaction(uint256 listingHash) external onlyOwner onlyTransacting(listingHash) returns (uint256) {
        listings[listingHash].seller = address(0);
        _setNotTransacting(listingHash);
        uint16 minDepositBasisPts = bidMinDepositBasisPts > listingMinDepositBasisPts ? listingMinDepositBasisPts : bidMinDepositBasisPts;
        uint256 daoFee = listings[listingHash].priceInPeb / 10000 * minDepositBasisPts;
        if(daoFee < listings[listingHash].depositInPeb) {
            _sendPeb(_cancelBid(listings[listingHash].bidHash), listings[listingHash].depositInPeb - daoFee);
            _sendPeb(bids[0].buyer, daoFee);
        } else {
            _sendPeb(_cancelBid(listings[listingHash].bidHash), listings[listingHash].depositInPeb);
        }

        emit TransactionForceCanceled(listingHash);

        return listingHash;
    }

    function forceApproveTransaction(uint256 listingHash) external onlyOwner onlyTransacting(listingHash) returns (uint256) {
        bids[listings[listingHash].bidHash].buyer = address(0);
        _setNotTransacting(listingHash);
        uint16 minDepositBasisPts = bidMinDepositBasisPts > listingMinDepositBasisPts ? listingMinDepositBasisPts : bidMinDepositBasisPts;
        uint256 daoFee = listings[listingHash].priceInPeb / 10000 * minDepositBasisPts;
        if(daoFee < bids[listings[listingHash].bidHash].depositInPeb) {
            _sendPeb(_cancelListing(listingHash), bids[listings[listingHash].bidHash].depositInPeb + listings[listingHash].priceInPeb - daoFee);
            _sendPeb(bids[0].buyer, daoFee);
        } else {
            _sendPeb(_cancelListing(listingHash), bids[listings[listingHash].bidHash].depositInPeb + listings[listingHash].priceInPeb);
        }

        emit TransactionForceApproved(listingHash);

        return listingHash;
    }

    function approveTransaction(uint256 listingHash) external onlyTransacting(listingHash) returns (uint256) {
        require(bids[listings[listingHash].bidHash].buyer == msg.sender);

        bids[listings[listingHash].bidHash].buyer = address(0);
        address seller = listings[listingHash].seller;
        listings[listingHash].seller = address(0);
        _setNotTransacting(listingHash);
        _sendPebWithFee(seller,  listings[listingHash].depositInPeb + listings[listingHash].priceInPeb);
        _sendPebWithFee(msg.sender, bids[listings[listingHash].bidHash].depositInPeb);
        DimplERC20 tokenContract = DimplERC20(governanceTokenContract);
        uint256 unlockAmount = (block.number - listings[listingHash].bidSelectedBlock) * 10e17 / blockToWeek *
        ((listings[listingHash].depositInPeb + listings[listingHash].priceInPeb + bids[listings[listingHash].bidHash].depositInPeb) / 20e18);
        tokenContract.mint(seller, unlockAmount); // seller
        tokenContract.mint(msg.sender, unlockAmount); // buyer
        tokenContract.mint(bids[0].buyer, unlockAmount); // dev

        emit TransactionApproved(listingHash);

        return listingHash;
    }

    function _cancelListing(uint256 listingHash) internal returns (address) {
        address seller = listings[listingHash].seller;
        listings[listingHash].seller = address(0);
        _cancelBidsOf(listingHash);
        _sendPeb(seller, listings[listingHash].depositInPeb);

        emit ListingCanceled(listingHash);

        return seller;
    }

    function _cancelBidsOfExcept(uint256 listingHash, uint256 bidHash) internal {
        uint256[] storage bidHashes = listings[listingHash].bidHashes;
        for (uint i=0; i < bidHashes.length; i++) {
            if(bidHashes[i] != bidHash || bids[bidHashes[i]].buyer != address(0)) {
                _cancelBid(bidHashes[i]);
            }
        }
    }

    function _cancelBidsOf(uint256 listingHash) internal {
        uint256[] storage bidHashes = listings[listingHash].bidHashes;
        for (uint i=0; i < bidHashes.length; i++) {
            if(bids[bidHashes[i]].buyer != address(0x0)) {
                _cancelBid(bidHashes[i]);
            }
        }
    }

    function _cancelBid(uint256 bidHash) internal returns (address) {
        address buyer = bids[bidHash].buyer;
        bids[bidHash].buyer = address(0);
        _sendPeb(buyer, bids[bidHash].depositInPeb + listings[bids[bidHash].listingHash].priceInPeb);

        emit BidCanceled(bidHash);

        return buyer;
    }

    function _setNotTransacting(uint256 listingHash) internal {
        listings[listingHash].bidHash = 0;
    }

    function _sendPeb(address account, uint256 pebAmount) internal {
        payable(account).sendValue(pebAmount);
    }

    function _sendPebWithFee(address account, uint256 pebAmount) internal {
        payable(account).sendValue(pebAmount / 10000 * (10000 - transactionFeeBasisPts));
        payable(bids[0].buyer).sendValue(pebAmount / 10000 * (transactionFeeBasisPts));
    }

    function _getBasisPts(uint256 numerator, uint256 denominator) internal pure returns (uint16) {
        return uint16(numerator * 10000 / denominator);
    }

    function _hashBid(address _account, uint256 _depositInPeb, uint256 _listingHash) internal pure returns (uint256) {
        return uint256(keccak256(abi.encode(_account, _depositInPeb, _listingHash)));
    }

    function _hashListing(address _account, uint256 _depositInPeb, uint256 _priceInPeb, uint128 _nonce) internal pure returns (uint256) {
        return uint256(keccak256(abi.encode(_account, _depositInPeb, _priceInPeb, _nonce)));
    }

}
