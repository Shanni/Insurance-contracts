// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/InsuranceClaims.sol";

contract DeployInsuranceClaims is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        vm.startBroadcast(deployerPrivateKey);
        
        InsuranceClaims insuranceClaims = new InsuranceClaims();
        
        vm.stopBroadcast();

        console.log("InsuranceClaims deployed to:", address(insuranceClaims));
    }
} 