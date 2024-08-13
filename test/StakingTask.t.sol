// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import {MockNFT} from "../src/mock/MockNFT.sol";
import {StakingTask} from "../src/StakingTask.sol";
import {UUPSProxy} from "../src/proxy/UUPSProxy.sol";
contract StakingTaskTests is Test {
    MockNFT public nftContract;
    StakingTask public stakingContract;
    address owner = vm.addr(1);
    address user = vm.addr(2);
    uint32 delay = 1 days;
    uint rewardPerBlock = 0.0001 ether;
    function setUp() public {
        nftContract = new MockNFT();
        StakingTask _stakingContract = new StakingTask();
        UUPSProxy proxy = new UUPSProxy(
            address(_stakingContract),
            abi.encodeWithSignature(
                "initialize(address,uint256,uint32,uint32)",
                owner,
                rewardPerBlock,
                delay,
                delay
            )
        );
        stakingContract = StakingTask(address(proxy));
    }

    function test_StateVariableCheck() public {
        require(stakingContract.s_owner() == owner);
        require(stakingContract.s_rewardPerBlock() == rewardPerBlock);
        require(stakingContract.s_withdrawDelay() == 1 days);
        require(stakingContract.s_rewardsClaimDelay() == 1 days);
    }

    function test_StakeOneNFT() public {
        vm.startPrank(user);
        uint tokenId = nftContract.mint();
        nftContract.approve(address(stakingContract), tokenId);
        stakingContract.stakeNFT(address(nftContract), tokenId);
        (uint256 noOfNFTsStaked, uint32 rewardsClaimedAt) = stakingContract
            .s_userStakingData(user);

        require(noOfNFTsStaked == 1);
        require(rewardsClaimedAt == 0);
        uint256 index = stakingContract.s_nftIndex(
            user,
            address(nftContract),
            tokenId
        );
        (
            bool isStaked,
            address contractAddress,
            uint256 id,
            uint256 stakingBlockNumber,
            uint256 unstakingBlockNumber,
            uint32 unstakeTime,
            uint32 stakeTime
        ) = stakingContract.getNFTData(index);

        require(isStaked == true);
        require(contractAddress == address(nftContract));
        require(id == tokenId);
        require(stakingBlockNumber == block.number);
        require(unstakingBlockNumber == 0);
        require(unstakeTime == 0);
        require(stakeTime == block.timestamp);
        vm.stopPrank();
    }

    function test_UnstakeNFT() public {
        vm.startPrank(user);
        uint tokenId = nftContract.mint();
        nftContract.approve(address(stakingContract), tokenId);

        stakingContract.stakeNFT(address(nftContract), tokenId);
        vm.roll(100);
        vm.warp(1000);
        stakingContract.unstakeNFT(address(nftContract), tokenId);

        uint256 index = stakingContract.s_nftIndex(
            user,
            address(nftContract),
            tokenId
        );
        (
            bool isStaked,
            address contractAddress,
            uint256 id,
            uint256 stakingBlockNumber,
            uint256 unstakingBlockNumber,
            uint32 unstakeTime,
            uint32 stakeTime
        ) = stakingContract.getNFTData(index);

        require(isStaked == false);
        require(contractAddress == address(nftContract));
        require(id == tokenId);
        require(stakingBlockNumber == 1);
        require(unstakingBlockNumber == 100);
        require(unstakeTime == 1000);
        require(stakeTime == 1);

        vm.stopPrank();
    }

    function test_WithdrawNFTBeforeDelay() public {
        vm.startPrank(user);
        uint tokenId = nftContract.mint();
        nftContract.approve(address(stakingContract), tokenId);

        stakingContract.stakeNFT(address(nftContract), tokenId);
        vm.roll(100);
        vm.warp(1000);
        stakingContract.unstakeNFT(address(nftContract), tokenId);

        vm.expectRevert("NFT Withdraw Delay");
        stakingContract.withdrawNFT(address(nftContract), tokenId);
    }

    function test_WithdrawNFTAfterDelay() public {
        vm.startPrank(user);
        uint tokenId = nftContract.mint();
        nftContract.approve(address(stakingContract), tokenId);

        stakingContract.stakeNFT(address(nftContract), tokenId);
        vm.roll(100);
        vm.warp(1000);
        stakingContract.unstakeNFT(address(nftContract), tokenId);
        vm.warp(1 days + 1000);

        stakingContract.withdrawNFT(address(nftContract), tokenId);
    }

    function test_ClaimRewardifStaked() public {
        vm.startPrank(user);
        uint tokenId = nftContract.mint();
        nftContract.approve(address(stakingContract), tokenId);
        stakingContract.stakeNFT(address(nftContract), tokenId);

        vm.roll(100);
        vm.warp(1 days);
        // adding rewards eth to staking contract
        vm.deal(address(stakingContract), 1 ether);

        // rewards = (100 - 1) * rewardPerBlock
        // 100 -> block.number
        // 1 -> stakingBlockNumber;

        console.log(user.balance);
        stakingContract.claimReward();
        require(user.balance == (100 - 1) * rewardPerBlock);
    }

    function test_ClaimRewardifNotStaked() public {
        vm.startPrank(user);
        uint tokenId = nftContract.mint();
        nftContract.approve(address(stakingContract), tokenId);
        vm.roll(100);
        stakingContract.stakeNFT(address(nftContract), tokenId);

        vm.roll(120);
        vm.warp(1 days + 1);

        stakingContract.unstakeNFT(address(nftContract), tokenId);
        vm.roll(150);

        // adding rewards eth to staking contract
        vm.deal(address(stakingContract), 1 ether);

        console.log(user.balance);
        stakingContract.claimReward();
        require(user.balance == (120 - 100) * rewardPerBlock);
    }

    function test_StakeMulitpleNFTsOfSameContract() public {
        vm.startPrank(user);
        uint[] memory ids = new uint[](10);
        for (uint i = 0; i < 10; i++) {
            uint tokenId = nftContract.mint();
            nftContract.approve(address(stakingContract), tokenId);
            ids[i] = tokenId;
        }

        stakingContract.stakeNFT(address(nftContract), ids);
        (uint256 noOfNFTsStaked, uint32 rewardsClaimedAt) = stakingContract
            .s_userStakingData(user);

        require(noOfNFTsStaked == 10);
        require(rewardsClaimedAt == 0);

        for (uint i = 0; i < 10; i++) {
            uint256 index = stakingContract.s_nftIndex(
                user,
                address(nftContract),
                ids[i]
            );
            (
                bool isStaked,
                address contractAddress,
                uint256 id,
                uint256 stakingBlockNumber,
                uint256 unstakingBlockNumber,
                uint32 unstakeTime,
                uint32 stakeTime
            ) = stakingContract.getNFTData(index);

            require(isStaked == true);
            require(contractAddress == address(nftContract));
            require(id == ids[i]);
            require(stakingBlockNumber == block.number);
            require(unstakingBlockNumber == 0);
            require(unstakeTime == 0);
            require(stakeTime == block.timestamp);
        }

        vm.stopPrank();
    }

    function test_StakeMulitpleNFTsOfDifferentContract() public {
        vm.startPrank(user);
        address[] memory nftContracts = new address[](10);
        uint[] memory ids = new uint[](10);

        for (uint i = 0; i < 10; i++) {
            MockNFT _contract = new MockNFT();
            uint tokenId = _contract.mint();
            nftContracts[i] = address(_contract);
            ids[i] = tokenId;
            _contract.approve(address(stakingContract), tokenId);
        }
        stakingContract.stakeNFT(nftContracts, ids);
        for (uint i = 0; i < 10; i++) {
            uint256 index = stakingContract.s_nftIndex(
                user,
                nftContracts[i],
                ids[i]
            );
            (
                bool isStaked,
                address contractAddress,
                uint256 id,
                uint256 stakingBlockNumber,
                uint256 unstakingBlockNumber,
                uint32 unstakeTime,
                uint32 stakeTime
            ) = stakingContract.getNFTData(index);

            require(isStaked == true);
            require(contractAddress == nftContracts[i]);
            require(id == ids[i]);
            require(stakingBlockNumber == block.number);
            require(unstakingBlockNumber == 0);
            require(unstakeTime == 0);
            require(stakeTime == block.timestamp);
        }

        vm.stopPrank();
    }

    function test_StakeAndUnstakeRandomly() public {
        vm.startPrank(user);
        console.log(block.timestamp);
        console.log(block.number);
        uint tokenId1 = nftContract.mint();
        nftContract.approve(address(stakingContract), tokenId1);
        stakingContract.stakeNFT(address(nftContract), tokenId1);

        vm.roll(100);
        vm.warp(1000);

        uint tokenId2 = nftContract.mint();
        nftContract.approve(address(stakingContract), tokenId2);
        stakingContract.stakeNFT(address(nftContract), tokenId2);

        vm.roll(150);
        vm.warp(1500);

        uint tokenId3 = nftContract.mint();
        nftContract.approve(address(stakingContract), tokenId3);
        stakingContract.stakeNFT(address(nftContract), tokenId3);

        vm.roll(200);
        vm.warp(2000);

        stakingContract.unstakeNFT(address(nftContract), tokenId2);

        vm.roll(500);
        vm.warp(1 days);
        vm.deal(address(stakingContract), 1 ether);
        stakingContract.claimReward();
        // (500 - 1) * rewardPerBlock
        // (200 - 100) * rewardPerBlock
        // (500 - 150) * rewardPerBlock
        require(
            user.balance ==
                ((500 - 1) + (200 - 100) + (500 - 150)) * rewardPerBlock
        );
        vm.stopPrank();
    }

    function test_ClaimRewardDoSCheck() public {
        vm.startPrank(user);

        uint totalBlocks;
        for (uint i = 0; i < 1000; i++) {
            uint tokenId = nftContract.mint();
            nftContract.approve(address(stakingContract), tokenId);
            stakingContract.stakeNFT(address(nftContract), tokenId);
            uint previousBlockNumber = block.number;
            vm.roll(block.number + 100);
        }

        for (uint i = 0; i < 1000; i++) {
            (, , , uint stakingBlockNumber, , , ) = stakingContract.getNFTData(
                i
            );
            totalBlocks += block.number - stakingBlockNumber;
        }

        vm.expectRevert("Claim Delay");
        stakingContract.claimReward();

        vm.warp(1 days);

        vm.deal(address(stakingContract), totalBlocks * rewardPerBlock);
        console.log(totalBlocks);
        console.log(address(stakingContract).balance);
        uint gasBefore = gasleft();
        stakingContract.claimReward();
        console.log(gasBefore - gasleft());
        require(address(stakingContract).balance == 0);
        require(user.balance == totalBlocks * rewardPerBlock);

        vm.stopPrank();
    }
    function test_IfAlreadyClaimed() public {
        vm.startPrank(user);
        uint tokenId = nftContract.mint();
        nftContract.approve(address(stakingContract), tokenId);
        stakingContract.stakeNFT(address(nftContract), tokenId);

        vm.deal(address(stakingContract), 1 ether);

        vm.roll(100);
        vm.warp(1 days);
        stakingContract.claimReward();
        uint balanceBefore = user.balance;

        require(user.balance == (100 - 1) * rewardPerBlock);

        vm.roll(250);
        vm.warp(block.timestamp + 10000);

        stakingContract.unstakeNFT(address(nftContract), tokenId);

        vm.roll(450);
        vm.warp(block.timestamp + 1 days);

        stakingContract.claimReward();

        require(user.balance - balanceBefore == (250 - 100) * rewardPerBlock);

        balanceBefore = user.balance;
        vm.roll(650);
        vm.warp(block.timestamp + 1 days);

        stakingContract.claimReward();
        require(user.balance == balanceBefore);
    }
}
