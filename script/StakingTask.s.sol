// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";

import {StakingTask} from "../src/StakingTask.sol";
import {UUPSProxy} from "../src/proxy/UUPSProxy.sol";

contract StakingTaskScript is Script {
    function setUp() public {}

    function run() public {
        address account = vm.rememberKey(vm.envUint("PRIVATE_KEY"));
        console.log("Account : ", account);
        vm.startBroadcast(account);

        // Deploying implementation
        StakingTask stakingTask = new StakingTask();
        console.log("STAKING CONTRACT : ", address(stakingTask));

        //     address _owner = 0x501e0636c64b28840e0C38409Beb87d6BdfA835A,
        //     uint256 _rewardsPerBlock = 0.001 ether,
        //     uint32 _withdrawDelay = 1 day i.e. 86400 seconds,
        //     uint32 _rewardsClaimDelay = 1 day i.e. 86400 seconds,
        UUPSProxy proxy = new UUPSProxy(
            address(stakingTask),
            abi.encodeWithSignature(
                "initialize(address,uint256,uint32,uint32)",
                account,
                0.001 ether,
                86400,
                86400
            )
        );
        console.log("PROCY : ", address(proxy));

        StakingTask _task = StakingTask(address(proxy));
        console.log(_task.s_owner());
        console.log(_task.s_rewardPerBlock());
        console.log(_task.s_withdrawDelay());
        console.log(_task.s_rewardsClaimDelay());

        vm.stopBroadcast();
    }
}
