// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

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