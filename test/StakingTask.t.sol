// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import {MockNFT} from "../src/mock/MockNFT.sol";
import {MockProxyV1, MockProxyV2} from "../src/mock/MockProxy.sol";
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

    /**
     * @dev test initializer values have been set corretly or not
     */
    function test_StateVariableCheck() public {
        require(stakingContract.s_owner() == owner);
        require(stakingContract.s_noOfTimeRewardChanged() == 1);
        (uint changeBlockNumber, uint rewardsValue) = stakingContract
            .s_rewardPerBlock(0);

        require(changeBlockNumber == block.number);
        require(rewardsValue == rewardPerBlock);
        require(stakingContract.s_withdrawDelay() == 1 days);
        require(stakingContract.s_rewardsClaimDelay() == 1 days);
    }

    /**
     * @dev test function accessible only by owner address
     */
    function test_OwnerFunctions() public {
        vm.startPrank(user);
        vm.expectRevert("Not Owner");
        stakingContract.changeRewardsClaimDelay(2 days);
        vm.expectRevert("Not Owner");
        stakingContract.changeRewardsPerBlock(1 ether);
        vm.expectRevert("Not Owner");
        stakingContract.changeWithdrawDelay(2 days);
        vm.stopPrank();

        vm.startPrank(owner);
        stakingContract.changeRewardsClaimDelay(2 days);
        stakingContract.changeRewardsPerBlock(1 ether);
        stakingContract.changeWithdrawDelay(2 days);
        vm.stopPrank();
    }

    /**
     * @dev test staking function with passing one nft only
     */
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
            uint32 unstakeTime
        ) = stakingContract.getNFTData(index);

        require(isStaked == true);
        require(contractAddress == address(nftContract));
        require(id == tokenId);
        require(stakingBlockNumber == block.number);
        require(unstakingBlockNumber == 0);
        require(unstakeTime == 0);

        vm.stopPrank();
    }

    /**
     * @dev test staking function with passing multiple nfts of same contract
     */
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
                uint32 unstakeTime
            ) = stakingContract.getNFTData(index);

            require(isStaked == true);
            require(contractAddress == address(nftContract));
            require(id == ids[i]);
            require(stakingBlockNumber == block.number);
            require(unstakingBlockNumber == 0);
            require(unstakeTime == 0);
        }

        vm.stopPrank();
    }

    /**
     * @dev test staking function with passing multiple nfts of different contracts
     */
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
                uint32 unstakeTime
            ) = stakingContract.getNFTData(index);

            require(isStaked == true);
            require(contractAddress == nftContracts[i]);
            require(id == ids[i]);
            require(stakingBlockNumber == block.number);
            require(unstakingBlockNumber == 0);
            require(unstakeTime == 0);
        }

        vm.stopPrank();
    }
    /**
     *@dev no of contract != no of ids while staking
     */
    function test_StakeImbalancNumberOfContractAndIds() public {
        vm.startPrank(user);
        address[] memory nftContracts = new address[](10);
        uint[] memory ids = new uint[](11);

        for (uint i = 0; i < 10; i++) {
            MockNFT _contract = new MockNFT();
            uint tokenId = _contract.mint();
            nftContracts[i] = address(_contract);
            ids[i] = tokenId;
            _contract.approve(address(stakingContract), tokenId);
        }
        vm.expectRevert("invalid number of ids or contract address provided");
        stakingContract.stakeNFT(nftContracts, ids);
    }

    /**
     * @dev test unstaking nft and check the storage values are set corretly or not
     */
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
            uint32 unstakeTime
        ) = stakingContract.getNFTData(index);

        require(isStaked == false);
        require(contractAddress == address(nftContract));
        require(id == tokenId);
        require(stakingBlockNumber == 1);
        require(unstakingBlockNumber == 100);
        require(unstakeTime == 1000);

        vm.stopPrank();
    }
    /**
     * @dev test unstaking multiple nft of same contract
     */
    function test_UnstakeMultipleNFTSameContract() public {
        vm.startPrank(user);
        vm.deal(address(stakingContract), 1 ether);
        uint[] memory ids = new uint[](10);
        for (uint i = 0; i < 10; i++) {
            uint tokenId = nftContract.mint();
            nftContract.approve(address(stakingContract), tokenId);
            ids[i] = tokenId;
        }

        stakingContract.stakeNFT(address(nftContract), ids);
        (uint256 noOfNFTsStakedBefore, ) = stakingContract.s_userStakingData(
            user
        );

        require(noOfNFTsStakedBefore == 10);

        vm.roll(1000);
        stakingContract.unstakeNFT(address(nftContract), ids);
        (uint256 noOfNFTsStakedAfter, ) = stakingContract.s_userStakingData(
            user
        );
        vm.warp(1 days);
        require(noOfNFTsStakedAfter == 0);
        stakingContract.claimReward();
        (, uint32 rewardsCalimedAt) = stakingContract.s_userStakingData(user);

        require(user.balance == (1000 - 1) * 10 * rewardPerBlock);
        require(rewardsCalimedAt == uint32(1 days));
        vm.stopPrank();
    }

    /**
     *@dev test unstaking multiple nft of different contract
     */
    function test_UnstakeMultipleNFTDifferentContract() public {
        vm.startPrank(user);
        vm.deal(address(stakingContract), 1 ether);
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
        (uint256 noOfNFTsStakedBefore, ) = stakingContract.s_userStakingData(
            user
        );
        require(noOfNFTsStakedBefore == 10);
        vm.roll(1000);
        stakingContract.unstakeNFT(nftContracts, ids);
        (uint256 noOfNFTsStakedAfter, ) = stakingContract.s_userStakingData(
            user
        );
        require(noOfNFTsStakedAfter == 0);
        vm.warp(block.timestamp + 1 days);

        stakingContract.claimReward();
        (, uint32 rewardsCalimedAt) = stakingContract.s_userStakingData(user);

        require(user.balance == (1000 - 1) * 10 * rewardPerBlock);
        require(rewardsCalimedAt == uint32(1 days + 1));
        vm.stopPrank();
    }

    /**
     *@dev no of contract != no of ids while unstaking
     */
    function test_UnstakeImbalancNumberOfContractAndIds() public {
        vm.startPrank(user);
        address[] memory nftContracts = new address[](10);
        uint[] memory ids = new uint[](10);
        uint[] memory _ids = new uint[](11);

        for (uint i = 0; i < 10; i++) {
            MockNFT _contract = new MockNFT();
            uint tokenId = _contract.mint();
            nftContracts[i] = address(_contract);
            ids[i] = tokenId;
            _ids[i] = tokenId;
            _contract.approve(address(stakingContract), tokenId);
        }
        stakingContract.stakeNFT(nftContracts, ids);

        vm.roll(100);
        vm.expectRevert("invalid number of ids or contract address provided");
        stakingContract.unstakeNFT(nftContracts, _ids);
    }

    function test_UnStakeWithoutStaking() public {
        vm.startPrank(user);
        // array out of bound
        vm.expectRevert();
        stakingContract.unstakeNFT(address(nftContract), 1);

        uint[] memory ids = new uint[](10);
        for (uint i = 0; i < 10; i++) {
            uint tokenId = nftContract.mint();
            nftContract.approve(address(stakingContract), tokenId);
            ids[i] = tokenId;
        }

        stakingContract.stakeNFT(address(nftContract), ids);
        MockNFT _nftcontract = new MockNFT();
        uint tokenId = _nftcontract.mint();
        _nftcontract.approve(address(stakingContract), tokenId);
        // index will be zero for these arguments
        vm.expectRevert();
        stakingContract.unstakeNFT(address(stakingContract), tokenId);
    }

    /**
     * @dev test withdraw nft require statments
     */
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

    /**
     * @dev test withdraw nft logic after delay time spend
     */
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

    /**
     * @dev test rewards claim logic when nft is staked
     */
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

    /**
     * @dev test claim rewards logic when nft is unstakedF
     */
    function test_ClaimRewardUnStaked() public {
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

    /**
     * @dev test staking and unstaking logic with random values and checking rewards calculation logic
     */
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

    /**
     * @dev test gas requirements in claim rewards function for checking DoS attakcs
     */
    function test_ClaimRewardDoSCheck() public {
        vm.startPrank(user);

        uint totalBlocks;
        for (uint i = 0; i < 1000; i++) {
            uint tokenId = nftContract.mint();
            nftContract.approve(address(stakingContract), tokenId);
            stakingContract.stakeNFT(address(nftContract), tokenId);
            vm.roll(block.number + 100);
        }

        for (uint i = 0; i < 1000; i++) {
            (, , , uint stakingBlockNumber, , ) = stakingContract.getNFTData(i);
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

    /**
     * @dev doing multiple rewards claims after unstaking the nft
     */
    function test_MultipleClaimAfterUnstake() public {
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

    /**
     * @dev withdraw nft logic logic checks
     */
    function test_WithdrawRequireChecks() public {
        vm.startPrank(user);
        uint tokenId = nftContract.mint();
        nftContract.approve(address(stakingContract), tokenId);
        stakingContract.stakeNFT(address(nftContract), tokenId);

        vm.expectRevert("NFT is staked");
        stakingContract.withdrawNFT(address(nftContract), tokenId);

        stakingContract.unstakeNFT(address(nftContract), tokenId);

        vm.expectRevert("NFT Withdraw Delay");
        stakingContract.withdrawNFT(address(nftContract), tokenId);
        // 1 -> current block.timestamp

        vm.warp(1 days + 1);
        stakingContract.withdrawNFT(address(nftContract), tokenId);

        require(nftContract.ownerOf(tokenId) == user);

        vm.stopPrank();
    }

    /**
     * @dev pausable function checks
     */
    function test_PausableFunction() public {
        // staking process should be pausable and unpausable
        vm.startPrank(user);
        vm.expectRevert("Not Owner");
        stakingContract.pause();
        vm.stopPrank();

        vm.startPrank(owner);
        stakingContract.pause();

        uint _tokenId = nftContract.mint();
        nftContract.approve(address(stakingContract), _tokenId);
        vm.expectRevert();
        stakingContract.stakeNFT(address(nftContract), _tokenId);

        uint[] memory _ids = new uint[](10);
        for (uint i = 0; i < 10; i++) {
            uint tokenId = nftContract.mint();
            nftContract.approve(address(stakingContract), tokenId);
            _ids[i] = tokenId;
        }

        vm.expectRevert();
        stakingContract.stakeNFT(address(nftContract), _ids);

        address[] memory nftContracts = new address[](10);
        uint[] memory ids = new uint[](10);

        for (uint i = 0; i < 10; i++) {
            MockNFT _contract = new MockNFT();
            uint tokenId = _contract.mint();
            nftContracts[i] = address(_contract);
            ids[i] = tokenId;
            _contract.approve(address(stakingContract), tokenId);
        }
        vm.expectRevert();
        stakingContract.stakeNFT(nftContracts, ids);

        stakingContract.unpause();

        stakingContract.stakeNFT(address(nftContract), _tokenId);
        stakingContract.stakeNFT(address(nftContract), _ids);
        stakingContract.stakeNFT(nftContracts, ids);

        vm.stopPrank();
    }

    /**
     * @dev proxy implementation check
     */
    function test_ProxyImplementation() public {
        vm.startPrank(user);
        MockProxyV1 impV1 = new MockProxyV1();
        UUPSProxy proxy = new UUPSProxy(
            address(impV1),
            abi.encodeWithSignature("initialize(address)", user)
        );

        impV1 = MockProxyV1(address(proxy));
        require(
            keccak256(abi.encodePacked(impV1.version())) == keccak256("V1"),
            "invalid implementation"
        );
        require(impV1.owner() == user, "Invalid owner");

        MockProxyV2 impV2 = new MockProxyV2();
        impV1.upgradeToAndCall(
            address(impV2),
            abi.encodeWithSignature("initialize(address,uint256)", owner, 123)
        );

        impV2 = MockProxyV2(address(proxy));

        require(
            keccak256(abi.encodePacked(impV2.version())) == keccak256("V2"),
            "invalid implementation"
        );
        require(impV2.owner() == owner, "Invalid owner");
        require(impV2.counter() == 123, "Invalid counter value");
        vm.stopPrank();
    }

    /**
     * @dev nft index for quick access, update logic check
     */
    function test_NFTIndex() public {
        vm.startPrank(user);
        uint[] memory ids = new uint[](10);
        for (uint i = 0; i < 10; i++) {
            uint tokenId = nftContract.mint();
            nftContract.approve(address(stakingContract), tokenId);
            ids[i] = tokenId;
        }
        stakingContract.stakeNFT(address(nftContract), ids);
        (uint noOfNFTsStaked, ) = stakingContract.s_userStakingData(user);
        require(noOfNFTsStaked == 10);

        uint indexBefore = stakingContract.s_nftIndex(
            user,
            address(nftContract),
            ids[5]
        );

        require(indexBefore == 5);

        vm.roll(100);
        stakingContract.unstakeNFT(address(nftContract), ids[5]);

        vm.warp(block.timestamp + 1 days);
        stakingContract.withdrawNFT(address(nftContract), ids[5]);

        uint indexAfter = stakingContract.s_nftIndex(
            user,
            address(nftContract),
            ids[5]
        );

        uint lastNFTIndex = stakingContract.s_nftIndex(
            user,
            address(nftContract),
            ids[9]
        );

        require(indexAfter == type(uint256).max);
        require(lastNFTIndex == 5);

        vm.stopPrank();
    }

    /**
     * @dev try to claim rewards after withdrawing the nft
     */
    function test_ClaimAfterWithdraw() public {
        vm.startPrank(user);
        uint tokenId = nftContract.mint();
        nftContract.approve(address(stakingContract), tokenId);
        stakingContract.stakeNFT(address(nftContract), tokenId);

        vm.roll(100);
        stakingContract.unstakeNFT(address(nftContract), tokenId);

        vm.warp(block.timestamp + delay);
        stakingContract.withdrawNFT(address(nftContract), tokenId);

        stakingContract.claimReward();

        require(user.balance == 0);
        (uint noOfNFTsStaked, uint32 rewardsClaimedAt) = stakingContract
            .s_userStakingData(user);
        require(noOfNFTsStaked == 0);
        require(rewardsClaimedAt == uint32(block.timestamp));
        vm.stopPrank();
    }

    /**
     * @dev test on ERC721 receieve require statement
     */
    function test_OnERC721Receive() public {
        vm.startPrank(user);
        //only nft contracts can call this function
        vm.expectRevert("invalid operator");
        stakingContract.onERC721Received(address(this), user, 1, "");
    }

    /**
     * @dev test reinitializer modifier
     */
    function test_InvalidImplementationVersion() public {
        vm.startPrank(user);
        StakingTask _stakingContract = new StakingTask();
        vm.expectRevert();
        stakingContract.upgradeToAndCall(
            address(_stakingContract),
            abi.encodeWithSignature(
                "initialize(address,uint256,uint32,uint32)",
                owner,
                rewardPerBlock,
                delay,
                delay
            )
        );
    }

    function test_ClaimRewardIfStatementsCheck() public {
        vm.startPrank(user);
        vm.deal(address(stakingContract), 1 ether);

        uint tokenId = nftContract.mint();
        nftContract.approve(address(stakingContract), tokenId);

        stakingContract.stakeNFT(address(nftContract), tokenId);

        vm.roll(100);
        vm.warp(1 days);
        stakingContract.claimReward();
        // if statement check
        require(user.balance == (100 - 1) * rewardPerBlock);
        uint balanceBefore = user.balance;

        vm.roll(400);
        vm.warp(3 days);
        stakingContract.unstakeNFT(address(nftContract), tokenId);
        stakingContract.claimReward();
        // else if statement check
        require(user.balance == (400 - 100) * rewardPerBlock + balanceBefore);
        balanceBefore = user.balance;

        vm.roll(600);
        vm.warp(5 days);
        stakingContract.claimReward();
        require(user.balance == balanceBefore);
    }

    function test_dynamicRewardsAfterStakingOnly() external {
        vm.startPrank(user);
        uint tokenId = nftContract.mint();
        nftContract.approve(address(stakingContract), tokenId);
        console.log(block.number);
        vm.roll(100);
        stakingContract.stakeNFT(address(nftContract), tokenId);
        vm.stopPrank();

        vm.roll(150);
        vm.startPrank(owner);
        stakingContract.changeRewardsPerBlock(0.01 ether);

        vm.roll(374);
        stakingContract.changeRewardsPerBlock(1 ether);
        vm.stopPrank();

        vm.roll(564);
        require(user.balance == 0);

        vm.deal(address(stakingContract), 200 ether);
        vm.warp(block.timestamp + 1 days);
        vm.startPrank(user);
        require(stakingContract.s_noOfTimeRewardChanged() == 3);
        stakingContract.claimReward();

        uint totalReward = ((150 - 100) * rewardPerBlock) +
            ((374 - 150) * 0.01 ether) +
            ((564 - 374) * 1 ether);

        require(user.balance == totalReward);
    }

    function test_dynamicRewardsAfterUnstaking() external {
        vm.startPrank(user);
        uint tokenId = nftContract.mint();
        nftContract.approve(address(stakingContract), tokenId);
        console.log(block.number);
        vm.roll(100);
        stakingContract.stakeNFT(address(nftContract), tokenId);
        vm.stopPrank();

        vm.roll(150);
        vm.startPrank(owner);
        stakingContract.changeRewardsPerBlock(0.01 ether);
        vm.stopPrank();

        vm.roll(220);
        vm.startPrank(user);
        stakingContract.unstakeNFT(address(nftContract), tokenId);
        vm.stopPrank();

        vm.roll(374);
        vm.startPrank(owner);
        stakingContract.changeRewardsPerBlock(1 ether);
        vm.stopPrank();

        vm.roll(564);
        require(user.balance == 0);

        vm.deal(address(stakingContract), 200 ether);
        vm.warp(block.timestamp + 1 days);
        vm.startPrank(user);
        require(stakingContract.s_noOfTimeRewardChanged() == 3);
        stakingContract.claimReward();

        uint totalReward = ((150 - 100) * rewardPerBlock) +
            ((220 - 150) * 0.01 ether);

        require(user.balance == totalReward);
    }

    function test_dyanmicRewardsAfterStakingMultipleNFT() external {
        vm.startPrank(user);
        uint tokenId = nftContract.mint();
        nftContract.approve(address(stakingContract), tokenId);
        console.log(block.number);
        vm.roll(100);
        stakingContract.stakeNFT(address(nftContract), tokenId);
        vm.stopPrank();

        vm.roll(150);
        vm.startPrank(owner);
        stakingContract.changeRewardsPerBlock(0.01 ether);
        vm.stopPrank();

        vm.roll(180);
        vm.startPrank(user);
        uint tokenId2 = nftContract.mint();
        nftContract.approve(address(stakingContract), tokenId2);
        stakingContract.stakeNFT(address(nftContract), tokenId2);
        vm.stopPrank();

        vm.roll(220);
        vm.startPrank(user);
        stakingContract.unstakeNFT(address(nftContract), tokenId);
        vm.stopPrank();

        vm.roll(374);
        vm.startPrank(owner);
        stakingContract.changeRewardsPerBlock(1 ether);
        vm.stopPrank();

        vm.roll(564);
        require(user.balance == 0);

        vm.deal(address(stakingContract), 200 ether);
        vm.warp(block.timestamp + 1 days);
        vm.startPrank(user);
        require(stakingContract.s_noOfTimeRewardChanged() == 3);
        stakingContract.claimReward();

        uint firstNFTReward = ((150 - 100) * rewardPerBlock) +
            ((220 - 150) * 0.01 ether);

        uint secondNFTReward = ((374 - 180) * 0.01 ether) +
            ((564 - 374) * 1 ether);

        require(user.balance == firstNFTReward + secondNFTReward);
    }

    function test_dynamicRewardElseStatementCheck() external {
        vm.roll(150);
        vm.startPrank(owner);
        stakingContract.changeRewardsPerBlock(0.01 ether);
        vm.stopPrank();

        vm.roll(374);
        vm.startPrank(owner);
        stakingContract.changeRewardsPerBlock(1 ether);
        vm.stopPrank();

        vm.roll(564);
        vm.startPrank(user);
        uint tokenId = nftContract.mint();
        nftContract.approve(address(stakingContract), tokenId);
        stakingContract.stakeNFT(address(nftContract), tokenId);
        vm.stopPrank();
        require(user.balance == 0);

        vm.deal(address(stakingContract), 200 ether);
        vm.warp(block.timestamp + 1 days);
        vm.startPrank(user);
        require(stakingContract.s_noOfTimeRewardChanged() == 3);
        vm.roll(720);
        stakingContract.claimReward();

        require(user.balance == ((720 - 564) * 1 ether));
    }

    
}
