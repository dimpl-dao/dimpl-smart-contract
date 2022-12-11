// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./DimplEscrow.sol";
import "./DimplERC20.sol";

contract DimplGovernor is Ownable {

  event ProposalCreated(uint256 listingHash, address proposer, uint256 snapshotId, uint128 nonce);
  event ProposalExecuted(uint256 listingHash, VoteType voteType);
  event VoteCast(uint256 listingHash, VoteType voteType, uint256 amount);

  enum VoteType {
      Against,
      For
  }
  
  struct Proposal {
    bool executed;
    address proposer;
    uint128 proposalCreatedBlock;
    uint256 snapshotId;
    uint256 listingHash;
    uint256 againstVotes;
    uint256 forVotes;
    mapping(address => bool) hasVoted;
  }

  constructor(address _escrowContract, address _governanceTokenContract){
    escrowContract = _escrowContract;
    governanceTokenContract = _governanceTokenContract;
  }

  address public escrowContract;
  address public governanceTokenContract;
  uint256 public votingDelay = 172800; // 2 day
  uint256 public votingDuration = 259200; // 3 day
  mapping(uint256 => Proposal) private proposals;

  function setVotingDelay(uint256 _votingDelay) external onlyOwner {
    votingDelay = _votingDelay;
  }

  function setVotingDuration(uint256 _votingDuration) external onlyOwner {
    votingDuration = _votingDuration;
  }

  function callDimpleEscrow(bytes calldata _calldata) external payable onlyOwner returns (bytes memory) {
      (bool success, bytes memory returndata) = escrowContract.call{value: msg.value}(_calldata);
      return Address.verifyCallResult(success, returndata, "callDimpleEscrow reverted");
  }

  function propose(uint256 listingHash, uint128 nonce) external returns (uint256) {
    DimplEscrow dimplEscrow = DimplEscrow(escrowContract);
    (, address seller, , , uint256 bidHash, uint128 bidSelectedBlock, uint128 remonstrableBlockInterval) = dimplEscrow.listings(listingHash);
    require(seller == msg.sender);
    require(bidHash != uint256(0));
    require(block.number >= bidSelectedBlock + remonstrableBlockInterval);
    require(proposals[listingHash].proposer == address(0));
    require(proposals[listingHash].executed == false);

    dimplEscrow.setLocked(listingHash);
    uint256 snapshotId = DimplERC20(governanceTokenContract).snapshot();
    proposals[listingHash].proposer = msg.sender;
    proposals[listingHash].proposalCreatedBlock = uint128(block.number);
    proposals[listingHash].listingHash = listingHash;
    proposals[listingHash].snapshotId = snapshotId;

    emit ProposalCreated(listingHash, msg.sender, snapshotId, nonce);

    return listingHash;
  }

  function vote(uint256 listingHash, VoteType voteType) external returns(uint256) {
    require(proposals[listingHash].proposer != address(0));
    require(proposals[listingHash].executed == false);
    require(proposals[listingHash].hasVoted[msg.sender] == false);
    require(proposals[listingHash].proposalCreatedBlock + votingDelay < block.number);
    require(proposals[listingHash].proposalCreatedBlock + votingDelay + votingDuration >= block.number);

    uint256 balance = balanceOfAt(msg.sender, listingHash);
    proposals[listingHash].hasVoted[msg.sender] = true;
    if(voteType == VoteType.Against) {
      proposals[listingHash].againstVotes += balance;
    } else {
      proposals[listingHash].forVotes += balance;
    }

    emit VoteCast(listingHash, voteType, balance);

    return voteType == VoteType.Against ? proposals[listingHash].againstVotes : proposals[listingHash].forVotes;
  }

  function execute(uint256 listingHash) external returns(VoteType) {
    require(proposals[listingHash].proposer != address(0));
    require(proposals[listingHash].executed == false);
    require(proposals[listingHash].proposalCreatedBlock + votingDelay + votingDuration < block.number);

    proposals[listingHash].executed = true;
    VoteType winner = proposals[listingHash].forVotes > proposals[listingHash].againstVotes ? VoteType.For : VoteType.Against;
    if(winner == VoteType.For) {
      DimplEscrow(governanceTokenContract).forceCancelTransaction(proposals[listingHash].listingHash);
    } else {
      DimplEscrow(governanceTokenContract).forceApproveTransaction(proposals[listingHash].listingHash);
    }
    
    emit ProposalExecuted(listingHash, winner);

    return winner;
  }

  function balanceOfAt(address account, uint256 listingHash) public view returns(uint256) {
    return DimplERC20(governanceTokenContract).balanceOfAt(account, proposals[listingHash].snapshotId);
  }

}