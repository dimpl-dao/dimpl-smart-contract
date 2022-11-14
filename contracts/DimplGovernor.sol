// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./DimplEscrow.sol";
import "./DimplERC20.sol";

contract DimplGovernor is Ownable {

  event ProposalCreated(uint256 proposalHash, uint256 listingHash, address proposer, uint256 snapshotId, uint128 nonce);
  event ProposalExecuted(uint256 proposalHash, VoteType voteType);
  event VoteCast(uint256 proposalHash, VoteType voteType, uint256 amount);

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
    (address seller, , , uint256 bidHash, uint128 bidSelectedBlock, uint128 remonstrableBlockInterval) = dimplEscrow.listings(listingHash);
    require(seller == msg.sender);
    require(bidHash != uint256(0));
    require(block.number >= bidSelectedBlock + remonstrableBlockInterval);
    uint256 proposalHash = hashProposal(listingHash, nonce);
    require(proposals[proposalHash].proposer != address(0));
    require(proposals[proposalHash].executed == false);

    uint256 snapshotId = DimplERC20(governanceTokenContract).snapshot();
    proposals[proposalHash].proposer = msg.sender;
    proposals[proposalHash].proposalCreatedBlock = uint128(block.number);
    proposals[proposalHash].listingHash = listingHash;
    proposals[proposalHash].snapshotId = snapshotId;

    emit ProposalCreated(proposalHash, listingHash, msg.sender, snapshotId, nonce);

    return proposalHash;
  }

  function vote(uint256 proposalHash, VoteType voteType) external returns(uint256) {
    require(proposals[proposalHash].executed == false);
    require(proposals[proposalHash].hasVoted[msg.sender] == false);
    require(proposals[proposalHash].proposalCreatedBlock + votingDelay < block.number);
    require(proposals[proposalHash].proposalCreatedBlock + votingDelay + votingDuration >= block.number);

    uint256 balance = balanceOfAt(msg.sender, proposalHash);
    proposals[proposalHash].hasVoted[msg.sender] = true;
    if(voteType == VoteType.Against) {
      proposals[proposalHash].againstVotes += balance;
    } else {
      proposals[proposalHash].forVotes += balance;
    }

    emit VoteCast(proposalHash, voteType, balance);

    return voteType == VoteType.Against ? proposals[proposalHash].againstVotes : proposals[proposalHash].forVotes;
  }

  function execute(uint256 proposalHash) external returns(VoteType) {
    require(proposals[proposalHash].executed == false);
    require(proposals[proposalHash].proposalCreatedBlock + votingDelay + votingDuration < block.number);

    proposals[proposalHash].executed = true;
    VoteType winner = proposals[proposalHash].forVotes > proposals[proposalHash].againstVotes ? VoteType.For : VoteType.Against;
    if(winner == VoteType.For) {
      DimplEscrow(governanceTokenContract).forceCancelTransaction(proposals[proposalHash].listingHash);
    } else {
      DimplEscrow(governanceTokenContract).forceApproveTransaction(proposals[proposalHash].listingHash);
    }
    
    emit ProposalExecuted(proposalHash, winner);

    return winner;
  }

  function balanceOfAt(address account, uint256 proposalHash) public view returns(uint256) {
    return DimplERC20(governanceTokenContract).balanceOfAt(account, proposals[proposalHash].snapshotId);
  }

  function hashProposal(uint256 listingHash, uint128 nonce) public pure returns (uint256) {
    return uint256(keccak256(abi.encode(listingHash, nonce)));
  }


}