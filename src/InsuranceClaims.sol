// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";

library StringUtils {
    function uint2str(uint256 _i) internal pure returns (string memory) {
        if (_i == 0) {
            return "0";
        }
        uint256 j = _i;
        uint256 length;
        while (j != 0) {
            length++;
            j /= 10;
        }
        bytes memory bstr = new bytes(length);
        uint256 k = length;
        j = _i;
        while (j != 0) {
            bstr[--k] = bytes1(uint8(48 + j % 10));
            j /= 10;
        }
        return string(bstr);
    }
}

// Custom errors for better gas efficiency and clarity
error InsuranceClaims__InvalidAmount();
error InsuranceClaims__ClaimNotFound();
error InsuranceClaims__StatusAlreadySet();
error InsuranceClaims__InvalidStatus();
error InsuranceClaims__UnauthorizedAccess();

contract InsuranceClaims is Ownable {
    using StringUtils for uint256;
    
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
    event ClaimSubmitted(
        uint256 indexed claimId,
        bytes32 indexed customerIdHash,
        uint256 amount,
        uint256 timestamp,
        address indexed submitter
    );

    event ClaimStatusUpdated(
        uint256 indexed claimId,
        ClaimStatus oldStatus,
        ClaimStatus newStatus,
        uint256 timestamp,
        address indexed updater
    );

    event ClaimProcessed(
        uint256 indexed claimId,
        bytes32 indexed customerIdHash,
        uint256 amount,
        ClaimStatus status,
        uint256 processedAt
    );

    constructor() Ownable(msg.sender) {}

    uint256 public nextClaimId = 1;

    /**
     * @dev Submits a new insurance claim
     * @param customerId Raw customer ID that will be hashed
     * @param amount Claim amount
     */
    function submitClaim(
        string calldata customerId,
        uint256 amount
    ) external returns (uint256) {
        if (amount == 0) {
            revert InsuranceClaims__InvalidAmount();
        }
        
        bytes32 customerIdHash = keccak256(abi.encodePacked(customerId));
        uint256 newClaimId = nextClaimId++;

        claims[newClaimId] = Claim({
            customerIdHash: customerIdHash,
            claimId: newClaimId,
            amount: amount,
            claimDate: block.timestamp,
            status: ClaimStatus.Submitted,
            exists: true
        });

        emit ClaimSubmitted(
            newClaimId,
            customerIdHash,
            amount,
            block.timestamp,
            msg.sender
        );

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
        if (!claims[claimId].exists) {
            revert InsuranceClaims__ClaimNotFound();
        }

        Claim storage claim = claims[claimId];
        
        if (claim.status == newStatus) {
            revert InsuranceClaims__StatusAlreadySet();
        }

        if (uint(newStatus) > 2) {
            revert InsuranceClaims__InvalidStatus();
        }

        ClaimStatus oldStatus = claim.status;
        claim.status = newStatus;

        emit ClaimStatusUpdated(
            claimId,
            oldStatus,
            newStatus,
            block.timestamp,
            msg.sender
        );

        // Emit processed event when claim is finalized
        if (newStatus == ClaimStatus.Approved || newStatus == ClaimStatus.Rejected) {
            emit ClaimProcessed(
                claimId,
                claim.customerIdHash,
                claim.amount,
                newStatus,
                block.timestamp
            );
        }
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
        if (!claims[claimId].exists) {
            revert InsuranceClaims__ClaimNotFound();
        }
        
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
        if (!claims[claimId].exists) {
            revert InsuranceClaims__ClaimNotFound();
        }
        
        bytes32 customerIdHash = keccak256(abi.encodePacked(customerId));
        return claims[claimId].customerIdHash == customerIdHash;
    }

    /**
     * @dev Generates a JSON string for a claim
     * @param claimId ID of the claim to generate JSON for
     */
    function getClaimAsJSON(uint256 claimId) external view returns (string memory) {
        require(claims[claimId].exists, "Claim does not exist");
        Claim storage claim = claims[claimId];
        
        return string(abi.encodePacked(
            '{',
            '"claimId":', claim.claimId.uint2str(), ',',
            '"customerIdHash":"0x', toHexString(abi.encodePacked(claim.customerIdHash)), '",',
            '"amount":', claim.amount.uint2str(), ',',
            '"claimDate":', claim.claimDate.uint2str(), ',',
            '"status":"', getStatusString(claim.status), '"',
            '}'
        ));
    }

    /**
     * @dev Helper function to convert status enum to string
     */
    function getStatusString(ClaimStatus status) internal pure returns (string memory) {
        if (status == ClaimStatus.Submitted) return "Submitted";
        if (status == ClaimStatus.Approved) return "Approved";
        if (status == ClaimStatus.Rejected) return "Rejected";
        return "Unknown";
    }

    /**
     * @dev Helper function to convert bytes to hex string
     */
    function toHexString(bytes memory data) internal pure returns (string memory) {
        bytes memory alphabet = "0123456789abcdef";
        bytes memory str = new bytes(2 * data.length);
        for (uint256 i = 0; i < data.length; i++) {
            str[2 * i] = alphabet[uint8(data[i] >> 4)];
            str[2 * i + 1] = alphabet[uint8(data[i] & 0x0f)];
        }
        return string(str);
    }

    /**
     * @dev Get all claims for a customer
     * @param customerId Customer ID to get claims for
     */
    function getCustomerClaimsAsJSON(string calldata customerId) external view returns (string memory) {
        bytes32 customerIdHash = keccak256(abi.encodePacked(customerId));
        string memory claims_array = "[";
        bool first = true;

        for (uint256 i = 1; i < nextClaimId; i++) {
            if (claims[i].exists && claims[i].customerIdHash == customerIdHash) {
                if (!first) {
                    claims_array = string(abi.encodePacked(claims_array, ","));
                }
                claims_array = string(abi.encodePacked(claims_array, this.getClaimAsJSON(i)));
                first = false;
            }
        }

        return string(abi.encodePacked(claims_array, "]"));
    }
} 