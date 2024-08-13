// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {MockNFT} from "../src/mock/MockNFT.sol";
contract MockNFTScript is Script {
    function run() public {
        address account = vm.rememberKey(vm.envUint("PRIVATE_KEY"));
        console.log("Account : ", account);
        vm.startBroadcast(account);
        MockNFT mockNFTContract = new MockNFT();
        console.log("MockNFTContract : ", address(mockNFTContract));
        vm.stopBroadcast();
    }
}
