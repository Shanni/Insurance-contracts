// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract InsuranceClaims is Ownable {
    using Counters for Counters.Counter;
    Counters.Counter private _claimIds;

    enum ClaimStatus { Submitted, Approved, Rejected }

    struct Claim {
        bytes32 customerIdHash;  // Hashed customer ID for privacy
        uint256 claimId;
        uint256 amount;
        uint256 claimDate;
        ClaimStatus status;
        bool exists;
    }

    // Mapping from claimId to Claim
    mapping(uint256 => Claim) public claims;

    // Events
    event ClaimSubmitted(uint256 indexed claimId, bytes32 indexed customerIdHash, uint256 amount);
    event ClaimStatusUpdated(uint256 indexed claimId, ClaimStatus newStatus);

    constructor() Ownable(msg.sender) {}

    /**
     * @dev Submits a new insurance claim
     * @param customerId Raw customer ID that will be hashed
     * @param amount Claim amount
     */
    function submitClaim(
        string calldata customerId,
        uint256 amount
    ) external returns (uint256) {
        require(amount > 0, "Amount must be greater than 0");
        
        bytes32 customerIdHash = keccak256(abi.encodePacked(customerId));
        _claimIds.increment();
        uint256 newClaimId = _claimIds.current();

        claims[newClaimId] = Claim({
            customerIdHash: customerIdHash,
            claimId: newClaimId,
            amount: amount,
            claimDate: block.timestamp,
            status: ClaimStatus.Submitted,
            exists: true
        });

        emit ClaimSubmitted(newClaimId, customerIdHash, amount);
        return newClaimId;
    }

    /**
     * @dev Updates the status of an existing claim
     * @param claimId ID of the claim to update
     * @param newStatus New status to set
     */
    function updateClaimStatus(
        uint256 claimId,
        ClaimStatus newStatus
    ) external onlyOwner {
        require(claims[claimId].exists, "Claim does not exist");
        require(claims[claimId].status != newStatus, "Status already set");

        claims[claimId].status = newStatus;
        emit ClaimStatusUpdated(claimId, newStatus);
    }

    /**
     * @dev Retrieves claim details by claim ID
     * @param claimId ID of the claim to retrieve
     */
    function getClaim(uint256 claimId) external view returns (
        bytes32 customerIdHash,
        uint256 amount,
        uint256 claimDate,
        ClaimStatus status
    ) {
        require(claims[claimId].exists, "Claim does not exist");
        Claim storage claim = claims[claimId];
        
        return (
            claim.customerIdHash,
            claim.amount,
            claim.claimDate,
            claim.status
        );
    }

    /**
     * @dev Verifies if a claim belongs to a specific customer
     * @param claimId ID of the claim to verify
     * @param customerId Customer ID to verify against
     */
    function verifyClaimOwnership(
        uint256 claimId,
        string calldata customerId
    ) external view returns (bool) {
        require(claims[claimId].exists, "Claim does not exist");
        bytes32 customerIdHash = keccak256(abi.encodePacked(customerId));
        return claims[claimId].customerIdHash == customerIdHash;
    }
} 