// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {Pausable} from "openzeppelin-contracts/utils/Pausable.sol";
import {IERC721Receiver} from "openzeppelin-contracts/token/ERC721/IERC721Receiver.sol";
import {IERC721} from "openzeppelin-contracts/token/ERC721/IERC721.sol";
import {UUPSProxiable} from "./proxy/UUPSProxiable.sol";
import {Initializable} from "./proxy/Initializable.sol";

contract StakingTask is
    Pausable,
    IERC721Receiver,
    UUPSProxiable,
    Initializable
{
    struct NFTStakingData {
        bool isStaked;
        address contractAddress;
        uint256 id;
        uint256 stakingBlockNumber;
        uint256 unstakingBlockNumber;
        uint32 unstakeTime;
        uint32 stakeTime;
    }

    struct UserStakingData {
        uint256 noOfNFTsStaked;
        uint32 rewardsClaimedAt;
        NFTStakingData[] nftData;
    }
    address public s_owner;
    uint256 public s_rewardPerBlock;
    uint32 public s_withdrawDelay;
    uint32 public s_rewardsClaimDelay;

    mapping(address user => mapping(address nftContractAddress => mapping(uint256 tokenId => uint256)))
        public s_nftIndex;
    mapping(address => UserStakingData) public s_userStakingData;

    function initialize(
        address _owner,
        uint256 _rewardsPerBlock,
        uint32 _withdrawDelay,
        uint32 _rewardsClaimDelay
    ) external reinitializer(1) {
        s_owner = _owner;
        s_rewardPerBlock = _rewardsPerBlock;
        s_withdrawDelay = _withdrawDelay;
        s_rewardsClaimDelay = _rewardsClaimDelay;
    }

    modifier onlyOwner() {
        require(_msgSender() == s_owner, "Not Owner");
        _;
    }

    /*//////////////////////////////////////////////////////////////
                           CONTROL MECHANICS
    //////////////////////////////////////////////////////////////*/

    function _authorizeUpgrade(address) internal view override onlyOwner {
        // NOP
    }

    function changeRewardsPerBlock(
        uint256 _rewardsPerBlock
    ) external onlyOwner {
        s_rewardPerBlock = _rewardsPerBlock;
    }

    function changeWithdrawDelay(uint32 _withdrawDelay) external onlyOwner {
        s_withdrawDelay = _withdrawDelay;
    }

    function changeRewardsClaimDelay(
        uint32 _rewardsClaimDelay
    ) external onlyOwner {
        s_rewardsClaimDelay = _rewardsClaimDelay;
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    /*//////////////////////////////////////////////////////////////
                             USER CONTROLS
    //////////////////////////////////////////////////////////////*/

    function stakeNFT(address _nftContractAddress, uint256 _id) external {
        _stakeNFT(_nftContractAddress, _id);
    }
    function stakeNFT(
        address[] memory _contractAddress,
        uint256[] memory _ids
    ) external {
        require(
            _contractAddress.length == _ids.length,
            "invalid number of ids or contract address provided"
        );
        for (
            uint256 i = 0;
            i < _contractAddress.length && i < _ids.length;
            i++
        ) {
            _stakeNFT(_contractAddress[i], _ids[i]);
        }
    }

    function stakeNFT(
        address _nftContractAddress,
        uint256[] memory _ids
    ) external {
        for (uint256 i = 0; i < _ids.length; i++) {
            _stakeNFT(_nftContractAddress, _ids[i]);
        }
    }

    function unstakeNFT(address _contractAddress, uint _id) external {
        address user = _msgSender();
        uint256 index = s_nftIndex[user][_contractAddress][_id];
        s_userStakingData[user].nftData[index].isStaked = false;
        s_userStakingData[user].nftData[index].unstakingBlockNumber = block
            .number;
        s_userStakingData[user].nftData[index].unstakeTime = uint32(
            block.timestamp
        );
    }

    function withdrawNFT(address _contractAddress, uint256 _id) external {
        address user = _msgSender();
        uint256 index = s_nftIndex[user][_contractAddress][_id];
        NFTStakingData memory nftData = s_userStakingData[user].nftData[index];
        require(!nftData.isStaked, "NFT is staked");
        require(
            block.timestamp >= nftData.unstakeTime + s_withdrawDelay,
            "NFT Withdraw Delay"
        );
        IERC721(nftData.contractAddress).safeTransferFrom(
            address(this),
            user,
            _id
        );
        uint length = s_userStakingData[user].nftData.length;
        s_userStakingData[user].nftData[index] = s_userStakingData[user]
            .nftData[length - 1];
        delete s_userStakingData[user].nftData[length - 1];
    }

    function claimReward() external {
        address user = _msgSender();
        require(
            block.timestamp >=
                s_userStakingData[user].rewardsClaimedAt + s_rewardsClaimDelay,
            "Claim Delay"
        );
        uint length = s_userStakingData[user].nftData.length;
        uint totalRewards;
        for (uint i = 0; i < length; i++) {
            if (s_userStakingData[user].nftData[i].isStaked) {
                totalRewards +=
                    (block.number -
                        s_userStakingData[user].nftData[i].stakingBlockNumber) *
                    s_rewardPerBlock;

                s_userStakingData[user].nftData[i].stakingBlockNumber = block
                    .number;
            } else {
                if (
                    s_userStakingData[user].nftData[i].unstakingBlockNumber != 0
                ) {
                    totalRewards +=
                        (s_userStakingData[user]
                            .nftData[i]
                            .unstakingBlockNumber -
                            s_userStakingData[user]
                                .nftData[i]
                                .stakingBlockNumber) *
                        s_rewardPerBlock;
                    s_userStakingData[user].nftData[i].unstakingBlockNumber = 0;
                }
            }
        }
        s_userStakingData[user].rewardsClaimedAt = uint32(block.timestamp);
        bool success = payable(user).send(totalRewards);
        require(success, "Rewards Not Claimed");
    }

    /*//////////////////////////////////////////////////////////////
                           INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function _stakeNFT(address _contractAddress, uint256 _id) internal {
        IERC721 nftContract = IERC721(_contractAddress);
        address user = _msgSender();
        nftContract.safeTransferFrom(user, address(this), _id);
        s_userStakingData[user].noOfNFTsStaked++;
        s_userStakingData[user].nftData.push(
            NFTStakingData(
                true,
                _contractAddress,
                _id,
                block.number,
                0,
                0,
                uint32(block.timestamp)
            )
        );
        s_nftIndex[user][_contractAddress][_id] =
            s_userStakingData[user].nftData.length -
            1;
    }

    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external returns (bytes4) {
        require(operator == address(this), "invalid operator");
        return IERC721Receiver.onERC721Received.selector;
    }

    /*//////////////////////////////////////////////////////////////
                             VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function getNFTData(
        uint256 index
    )
        external
        view
        returns (bool, address, uint256, uint256, uint256, uint32, uint32)
    {
        NFTStakingData memory _nftStakingData = s_userStakingData[_msgSender()]
            .nftData[index];
        return (
            _nftStakingData.isStaked,
            _nftStakingData.contractAddress,
            _nftStakingData.id,
            _nftStakingData.stakingBlockNumber,
            _nftStakingData.unstakingBlockNumber,
            _nftStakingData.unstakeTime,
            _nftStakingData.stakeTime
        );
    }
}
