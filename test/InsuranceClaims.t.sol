// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/InsuranceClaims.sol";

contract InsuranceClaimsTest is Test {
    InsuranceClaims public insuranceClaims;
    address owner = address(1);
    address user = address(2);

    // Events copied from InsuranceClaims contract for testing
    event ClaimSubmitted(
        uint256 indexed claimId,
        bytes32 indexed customerIdHash,
        uint256 amount,
        uint256 timestamp,
        address indexed submitter
    );

    event ClaimStatusUpdated(
        uint256 indexed claimId,
        InsuranceClaims.ClaimStatus oldStatus,
        InsuranceClaims.ClaimStatus newStatus,
        uint256 timestamp,
        address indexed updater
    );

    event ClaimProcessed(
        uint256 indexed claimId,
        bytes32 indexed customerIdHash,
        uint256 amount,
        InsuranceClaims.ClaimStatus status,
        uint256 processedAt
    );

    function setUp() public {
        vm.prank(owner);
        insuranceClaims = new InsuranceClaims();
    }

    function testSubmitClaim() public {
        vm.prank(user);
        uint256 claimId = insuranceClaims.submitClaim("USER123", 1 ether);
        assertEq(claimId, 1);

        (bytes32 customerIdHash, uint256 amount, uint256 claimDate, InsuranceClaims.ClaimStatus status) = 
            insuranceClaims.getClaim(claimId);
        
        assertEq(amount, 1 ether);
        assertEq(uint(status), uint(InsuranceClaims.ClaimStatus.Submitted));
        assertTrue(claimDate > 0);
        assertEq(customerIdHash, keccak256(abi.encodePacked("USER123")));
    }

    function testUpdateClaimStatus() public {
        // First submit a claim
        vm.prank(user);
        uint256 claimId = insuranceClaims.submitClaim("USER123", 1 ether);

        // Update status as owner
        vm.prank(owner);
        insuranceClaims.updateClaimStatus(claimId, InsuranceClaims.ClaimStatus.Approved);

        // Verify the status was updated
        (, , , InsuranceClaims.ClaimStatus status) = insuranceClaims.getClaim(claimId);
        assertEq(uint(status), uint(InsuranceClaims.ClaimStatus.Approved));
    }

    function testFailUpdateClaimStatusNonOwner() public {
        // First submit a claim
        vm.prank(user);
        uint256 claimId = insuranceClaims.submitClaim("USER123", 1 ether);

        // Try to update status as non-owner (should fail)
        vm.prank(user);
        insuranceClaims.updateClaimStatus(claimId, InsuranceClaims.ClaimStatus.Approved);
    }

    function testVerifyClaimOwnership() public {
        // Submit a claim
        vm.prank(user);
        uint256 claimId = insuranceClaims.submitClaim("USER123", 1 ether);

        // Verify correct ownership
        assertTrue(insuranceClaims.verifyClaimOwnership(claimId, "USER123"));
        
        // Verify incorrect ownership
        assertFalse(insuranceClaims.verifyClaimOwnership(claimId, "WRONG_USER"));
    }

    function testGetClaimAsJSON() public {
        // Submit a claim first
        vm.prank(user);
        uint256 claimId = insuranceClaims.submitClaim("USER123", 1 ether);
        
        string memory jsonString = insuranceClaims.getClaimAsJSON(claimId);
        assertTrue(bytes(jsonString).length > 0);
        
        // Basic validation that it contains expected fields
        assertTrue(contains(jsonString, '"claimId":1'));
        assertTrue(contains(jsonString, '"status":"Submitted"'));
        assertTrue(contains(jsonString, '"amount":1000000000000000000')); // 1 ether in wei
    }

    function testGetCustomerClaimsAsJSON() public {
        // Submit multiple claims
        vm.startPrank(user);
        insuranceClaims.submitClaim("USER123", 1 ether);
        insuranceClaims.submitClaim("USER123", 2 ether);
        vm.stopPrank();

        string memory jsonArray = insuranceClaims.getCustomerClaimsAsJSON("USER123");
        assertTrue(bytes(jsonArray).length > 0);
        assertTrue(contains(jsonArray, '"claimId":1'));
        assertTrue(contains(jsonArray, '"claimId":2'));
    }

    function testCustomErrors() public {
        // Test invalid amount
        vm.expectRevert(InsuranceClaims__InvalidAmount.selector);
        vm.prank(user);
        insuranceClaims.submitClaim("USER123", 0);

        // Test claim not found
        vm.expectRevert(InsuranceClaims__ClaimNotFound.selector);
        vm.prank(owner);
        insuranceClaims.updateClaimStatus(999, InsuranceClaims.ClaimStatus.Approved);

        // Submit a claim and test status already set
        vm.prank(user);
        uint256 claimId = insuranceClaims.submitClaim("USER123", 1 ether);
        
        vm.prank(owner);
        insuranceClaims.updateClaimStatus(claimId, InsuranceClaims.ClaimStatus.Approved);
        
        vm.expectRevert(InsuranceClaims__StatusAlreadySet.selector);
        vm.prank(owner);
        insuranceClaims.updateClaimStatus(claimId, InsuranceClaims.ClaimStatus.Approved);
    }

    function testEventEmission() public {
        vm.prank(user);
        
        // Test ClaimSubmitted event
        vm.expectEmit(true, true, true, true);
        emit ClaimSubmitted(1, keccak256(abi.encodePacked("USER123")), 1 ether, block.timestamp, user);
        uint256 claimId = insuranceClaims.submitClaim("USER123", 1 ether);

        // Test ClaimStatusUpdated event
        vm.prank(owner);
        vm.expectEmit(true, true, true, true);
        emit ClaimStatusUpdated(
            claimId,
            InsuranceClaims.ClaimStatus.Submitted,
            InsuranceClaims.ClaimStatus.Approved,
            block.timestamp,
            owner
        );
        insuranceClaims.updateClaimStatus(claimId, InsuranceClaims.ClaimStatus.Approved);
    }

    function testClaimStructure() public {
        // Submit a claim and get its ID
        vm.prank(user);
        uint256 claimId = insuranceClaims.submitClaim("USER123", 1.5 ether);

        // Get the claim from mapping
        (
            bytes32 customerIdHash,
            uint256 amount,
            uint256 claimDate,
            InsuranceClaims.ClaimStatus status
        ) = insuranceClaims.getClaim(claimId);

        // Test each field of the struct
        bytes32 expectedHash = keccak256(abi.encodePacked("USER123"));
        assertEq(customerIdHash, expectedHash, "Customer ID hash mismatch");
        assertEq(amount, 1.5 ether, "Amount mismatch");
        assertEq(status, InsuranceClaims.ClaimStatus.Submitted, "Initial status should be Submitted");
        
        // Test claim date is recent
        assertGt(claimDate, block.timestamp - 1 minutes, "Claim date too old");
        assertLe(claimDate, block.timestamp, "Claim date in future");

        // Test claim existence
        (bool exists) = insuranceClaims.claims(claimId);
        assertTrue(exists, "Claim should exist");

        // Test non-existent claim
        vm.expectRevert(InsuranceClaims__ClaimNotFound.selector);
        insuranceClaims.getClaim(999);

        // Test claim ID sequence
        vm.prank(user);
        uint256 secondClaimId = insuranceClaims.submitClaim("USER456", 2 ether);
        assertEq(secondClaimId, claimId + 1, "Claim IDs should be sequential");

        // Test different customer IDs produce different hashes
        (bytes32 secondCustomerIdHash, , , ) = insuranceClaims.getClaim(secondClaimId);
        assertTrue(customerIdHash != secondCustomerIdHash, "Different customers should have different hashes");
    }

    function testClaimStatusTransitions() public {
        // Submit a claim
        vm.prank(user);
        uint256 claimId = insuranceClaims.submitClaim("USER123", 1 ether);

        // Test initial status
        (, , , InsuranceClaims.ClaimStatus status) = insuranceClaims.getClaim(claimId);
        assertEq(uint(status), uint(InsuranceClaims.ClaimStatus.Submitted), "Initial status should be Submitted");

        // Test transition to Approved
        vm.prank(owner);
        insuranceClaims.updateClaimStatus(claimId, InsuranceClaims.ClaimStatus.Approved);
        (, , , status) = insuranceClaims.getClaim(claimId);
        assertEq(uint(status), uint(InsuranceClaims.ClaimStatus.Approved), "Status should be Approved");

        // Test cannot transition from Approved to Submitted
        vm.expectRevert(InsuranceClaims__StatusAlreadySet.selector);
        vm.prank(owner);
        insuranceClaims.updateClaimStatus(claimId, InsuranceClaims.ClaimStatus.Approved);

        // Test transition to Rejected (should fail as already Approved)
        vm.prank(owner);
        vm.expectRevert(InsuranceClaims__StatusAlreadySet.selector);
        insuranceClaims.updateClaimStatus(claimId, InsuranceClaims.ClaimStatus.Rejected);
    }

    function testClaimAmounts() public {
        // Test zero amount
        vm.prank(user);
        vm.expectRevert(InsuranceClaims__InvalidAmount.selector);
        insuranceClaims.submitClaim("USER123", 0);

        // Test various amounts
        uint256[] memory amounts = new uint256[](3);
        amounts[0] = 0.1 ether;
        amounts[1] = 1 ether;
        amounts[2] = 100 ether;

        for (uint i = 0; i < amounts.length; i++) {
            vm.prank(user);
            uint256 claimId = insuranceClaims.submitClaim("USER123", amounts[i]);
            
            (, uint256 storedAmount, , ) = insuranceClaims.getClaim(claimId);
            assertEq(storedAmount, amounts[i], "Stored amount should match submitted amount");
        }

        // Test max uint256 amount
        vm.prank(user);
        uint256 maxClaimId = insuranceClaims.submitClaim("USER123", type(uint256).max);
        (, uint256 maxAmount, , ) = insuranceClaims.getClaim(maxClaimId);
        assertEq(maxAmount, type(uint256).max, "Should handle maximum uint256 amount");
    }

    // Helper function to check if a string contains a substring
    function contains(string memory what, string memory where) internal pure returns (bool) {
        bytes memory whatBytes = bytes(what);
        bytes memory whereBytes = bytes(where);

        if (whereBytes.length > whatBytes.length) {
            return false;
        }

        for (uint i = 0; i <= whatBytes.length - whereBytes.length; i++) {
            bool found = true;
            for (uint j = 0; j < whereBytes.length; j++) {
                if (whatBytes[i + j] != whereBytes[j]) {
                    found = false;
                    break;
                }
            }
            if (found) {
                return true;
            }
        }
        return false;
    }
} 