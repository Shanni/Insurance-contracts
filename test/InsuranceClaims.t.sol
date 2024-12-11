// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/InsuranceClaims.sol";

contract InsuranceClaimsTest is Test {
    InsuranceClaims public insuranceClaims;
    address owner = address(1);
    address user = address(2);

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
} 