// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

/// @custom:authors: [@anmol-dhiman]

import {Pausable} from "openzeppelin-contracts/utils/Pausable.sol";
import {IERC721Receiver} from "openzeppelin-contracts/token/ERC721/IERC721Receiver.sol";
import {IERC721} from "openzeppelin-contracts/token/ERC721/IERC721.sol";
import {Initializable} from "./proxy/Initializable.sol";
import {UUPSProxiable} from "./proxy/UUPSProxiable.sol";

/**
@title Smart Contract Development Task for Dzap
StakingTask is the contract where user can stake NFT and can get rewards per block 
*/
contract StakingTask is
    Pausable,
    IERC721Receiver,
    UUPSProxiable,
    Initializable
{
    struct NFTStakingData {
        bool isStaked; //NFT staked or not
        address contractAddress; // NFT contract address
        uint256 id; // token id
        uint256 stakingBlockNumber; // block.number at which nft is staked
        uint256 unstakingBlockNumber; // block.number at which nft is unstaked
        uint32 unstakeTime; //block.timestamp at which nft is unstaked
        uint32 stakeTime;
    }

    struct UserStakingData {
        uint256 noOfNFTsStaked; // no of nft staked
        uint32 rewardsClaimedAt; // last rewards claimed at which block.timestamp
        NFTStakingData[] nftData;
    }

    struct RewardPerBlock {
        uint256 changeBlockNumber;
        uint256 rewards;
    }
    address public s_owner; // owner address for governance work
    // uint256 public s_rewardPerBlock; // rewards per block
    uint32 public s_withdrawDelay; // delay after which user can withdraw the nft
    uint32 public s_rewardsClaimDelay; // delay after which user can claim his rewards
    uint256 public s_noOfTimeRewardChanged;

    mapping(address user => mapping(address nftContractAddress => mapping(uint256 tokenId => uint256)))
        public s_nftIndex; // mapping for storing index of nft for quick access
    mapping(address => UserStakingData) public s_userStakingData; // mapping for storing the staking data for particular user
    mapping(uint => RewardPerBlock) public s_rewardPerBlock;

    modifier onlyOwner() {
        require(_msgSender() == s_owner, "Not Owner");
        _;
    }

    constructor() {
        _disableInitializers();
    }

    /*//////////////////////////////////////////////////////////////
                              INITIALIZER
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev initializer the contract with initial values thorugh proxy contract
     * @param _owner external EOA or multi-sig for governance
     * @param _rewardsPerBlock amount of eth user should get for each block for each nft staked.
     * @param _withdrawDelay delay time after which user can withdraw nft.
     * @param _rewardsClaimDelay delay time after which user can claim his accumulated reward
     */
    function initialize(
        address _owner,
        uint256 _rewardsPerBlock,
        uint32 _withdrawDelay,
        uint32 _rewardsClaimDelay
    ) external reinitializer(1) {
        s_owner = _owner;
        s_rewardPerBlock[s_noOfTimeRewardChanged] = RewardPerBlock(
            block.number,
            _rewardsPerBlock
        );
        s_noOfTimeRewardChanged++;
        s_withdrawDelay = _withdrawDelay;
        s_rewardsClaimDelay = _rewardsClaimDelay;
    }

    /*//////////////////////////////////////////////////////////////
                           CONTROL MECHANICS
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev authorize function to update the implementation storage.
     * @param _newImplementation  address for new logic contract.
     * @notice this function can only be use by owner and have internal call through Proxy function upgradeToAndCall
     */
    function _authorizeUpgrade(
        address _newImplementation
    ) internal view override onlyOwner {
        // NOP
    }

    /**
     * @dev update the rewards per block
     * @param _rewardsPerBlock new amount of rewards per block
     * @notice only owner can access this function.
     */
    function changeRewardsPerBlock(
        uint256 _rewardsPerBlock
    ) external onlyOwner {
        s_rewardPerBlock[s_noOfTimeRewardChanged] = RewardPerBlock(
            block.number,
            _rewardsPerBlock
        );
        s_noOfTimeRewardChanged++;
    }

    /**
     * @dev update the delay time for withdrawing nft
     * @param _withdrawDelay new delay time
     * @notice only owner can access this function.
     */
    function changeWithdrawDelay(uint32 _withdrawDelay) external onlyOwner {
        s_withdrawDelay = _withdrawDelay;
    }

    /**
     * @dev update the delay time for rewards collection
     * @param _rewardsClaimDelay new delay time
     * @notice only owner can access.
     */
    function changeRewardsClaimDelay(
        uint32 _rewardsClaimDelay
    ) external onlyOwner {
        s_rewardsClaimDelay = _rewardsClaimDelay;
    }

    /**
     * @dev pause the staking functionality
     * @notice only owner can access this function
     */
    function pause() external onlyOwner {
        _pause();
    }

    /**
     * @dev unpause the staking functionlaity
     * @notice only owner can access this function
     */
    function unpause() external onlyOwner {
        _unpause();
    }

    /*//////////////////////////////////////////////////////////////
                             USER CONTROLS
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev stake single nft
     * @param _nftContractAddress nft contract address
     * @param _id nft tokenId
     * @notice user have to approve before staking the nft.
     * @notice only accessable when not paused
     */
    function stakeNFT(
        address _nftContractAddress,
        uint256 _id
    ) external whenNotPaused {
        _stakeNFT(_nftContractAddress, _id);
    }
    /**
     * @dev stake multiple nfts of same contract
     * @param _nftContractAddress    nft contract addresses.
     * @param _ids array of nft tokenIds
     * @notice user have to approve all the nfts before staking
     * @notice only accessable when not paused
     */
    function stakeNFT(
        address _nftContractAddress,
        uint256[] memory _ids
    ) external whenNotPaused {
        for (uint256 i = 0; i < _ids.length; i++) {
            _stakeNFT(_nftContractAddress, _ids[i]);
        }
    }

    /**
     * @dev stake multiple nfts of different contract
     * @param _contractAddress  array of nft contract addresses.
     * @param _ids array of nft tokenIds
     * @notice user have to approve all the nfts from all different contract before staking
     * @notice only accessable when not paused
     */
    function stakeNFT(
        address[] memory _contractAddress,
        uint256[] memory _ids
    ) external whenNotPaused {
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

    /**
     * @dev unstake single nft
     * @param _nftContractAddress nft contract address
     * @param _id nft tokenId
     */
    function unstakeNFT(address _nftContractAddress, uint256 _id) external {
        _unstakeNFT(_nftContractAddress, _id);
    }

    /**
     * @dev unstake multiple nft of same contract
     * @param _nftContractAddress nft contract address
     * @param _ids array of nft tokenIds
     */
    function unstakeNFT(
        address _nftContractAddress,
        uint256[] memory _ids
    ) external {
        for (uint256 i = 0; i < _ids.length; i++) {
            _unstakeNFT(_nftContractAddress, _ids[i]);
        }
    }
    /**
     * @dev unstake nfts of differnet contracts
     * @param _contractAddress array of different nft contracts
     * @param _ids array of nft tokenIds
     */
    function unstakeNFT(
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
            _unstakeNFT(_contractAddress[i], _ids[i]);
        }
    }

    /**
     * @dev withdraw nft after unstaking
     * @param _contractAddress nft contract address
     * @param _id nft tokenId
     * @notice only after withdrawDelay nft can be withdrawn
     * @notice unstake nft before withdrawing
     * @notice user have to claim their rewards before withdrawing nft otherwise rewards will be lost
     */
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
        NFTStakingData memory data = s_userStakingData[user].nftData[index];
        s_nftIndex[user][data.contractAddress][data.id] = index;
        delete s_userStakingData[user].nftData[length - 1];
        s_nftIndex[user][_contractAddress][_id] = type(uint256).max;
    }

    /**
     * @dev claim the accumalted rewards for all the nfts staked by user
     * @notice only after claim delay user can claim his rewards
     * @notice renew the claim time to make user serve delay for claiming rewards
     */
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
                totalRewards += _calculateTotalRewards(
                    s_userStakingData[user].nftData[i].stakingBlockNumber,
                    block.number
                );

                s_userStakingData[user].nftData[i].stakingBlockNumber = block
                    .number;
            } else {
                // unstaked but does already claimed or not
                if (
                    s_userStakingData[user].nftData[i].unstakingBlockNumber != 0
                ) {
                    totalRewards += _calculateTotalRewards(
                        s_userStakingData[user].nftData[i].stakingBlockNumber,
                        s_userStakingData[user].nftData[i].unstakingBlockNumber
                    );
                    // if user claims once after unstaking then user cannot get anymore rewards
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

    /**
     *@dev calculate the total rewards for a user for a single nft
     *@param _stakeBlockNumber the block.number at which nft staked.
     *@param _unstakeBlockNumber the block.number at which nft is unstaked and if nft is not unstaked the value should be current block.number
     */
    function _calculateTotalRewards(
        uint256 _stakeBlockNumber,
        uint256 _unstakeBlockNumber
    ) internal view returns (uint256) {
        uint256 noOfTimeRewardChanged = s_noOfTimeRewardChanged;
        uint256 rewardCalculationStartIndex;
        uint256 left;
        uint256 right = noOfTimeRewardChanged - 1;
        uint256 totalRewards;

        // if there is reward value change only once i.e. during deployment
        if (noOfTimeRewardChanged == 1) {
            return
                (_unstakeBlockNumber - _stakeBlockNumber) *
                s_rewardPerBlock[0].rewards;
        }
        // if currently there is no new update in rewardsValue from owner
        else if (
            _stakeBlockNumber >=
            s_rewardPerBlock[noOfTimeRewardChanged - 1].changeBlockNumber
        ) {
            return
                (_unstakeBlockNumber - _stakeBlockNumber) *
                s_rewardPerBlock[noOfTimeRewardChanged - 1].rewards;
        }

        // using binary search for finding the index of rewardData i.e. blockNumber and rewardValue from which the calculation begans
        while (left <= right) {
            uint mid = left + (right - left) / 2;
            if (s_rewardPerBlock[mid].changeBlockNumber <= _stakeBlockNumber) {
                rewardCalculationStartIndex = mid;
                left = mid + 1;
            } else {
                right = mid - 1;
            }
        }

        // if nft is unstaked before any update in rewardsValue from owner
        if (
            _unstakeBlockNumber <=
            s_rewardPerBlock[rewardCalculationStartIndex + 1].changeBlockNumber
        ) {
            return
                (_unstakeBlockNumber - _stakeBlockNumber) *
                s_rewardPerBlock[rewardCalculationStartIndex].rewards;
        }

        while (
            _unstakeBlockNumber >
            s_rewardPerBlock[rewardCalculationStartIndex + 1].changeBlockNumber
        ) {
            RewardPerBlock memory rewardData = s_rewardPerBlock[
                rewardCalculationStartIndex
            ];
            RewardPerBlock memory nextRewarData = s_rewardPerBlock[
                rewardCalculationStartIndex + 1
            ];

            totalRewards +=
                (nextRewarData.changeBlockNumber - _stakeBlockNumber) *
                rewardData.rewards;
            _stakeBlockNumber = nextRewarData.changeBlockNumber;
            rewardCalculationStartIndex++;
            if (rewardCalculationStartIndex == noOfTimeRewardChanged - 1) {
                break;
            }
        }

        totalRewards +=
            (_unstakeBlockNumber - _stakeBlockNumber) *
            s_rewardPerBlock[rewardCalculationStartIndex].rewards;
        return totalRewards;
    }

    /**
     * @dev logic for staking one nft
     * @param _contractAddress nft contract address
     * @param _id nft tokenId
     */
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
        // 0 is reserved for null values
        s_nftIndex[user][_contractAddress][_id] =
            s_userStakingData[user].nftData.length -
            1;
    }

    /**
     * @dev logic for unstaking one nft
     * @param _contractAddress nft contract address
     * @param _id nft tokenId
     */
    function _unstakeNFT(address _contractAddress, uint _id) internal {
        require(
            address(this) == IERC721(_contractAddress).ownerOf(_id),
            "Invalid nft for unstaking"
        );
        address user = _msgSender();
        uint256 index = s_nftIndex[user][_contractAddress][_id];

        s_userStakingData[user].noOfNFTsStaked--;
        s_userStakingData[user].nftData[index].isStaked = false;
        s_userStakingData[user].nftData[index].unstakingBlockNumber = block
            .number;
        s_userStakingData[user].nftData[index].unstakeTime = uint32(
            block.timestamp
        );
    }

    /**
     * @dev Whenever an {IERC721} `tokenId` token is transferred to this contract via {IERC721-safeTransferFrom}
     * by `operator` from `from`, this function is called.
     *
     * It must return its Solidity selector to confirm the token transfer.
     * If any other value is returned or the interface is not implemented by the recipient, the transfer will be
     * reverted.
     *
     * The selector can be obtained in Solidity with `IERC721Receiver.onERC721Received.selector`.
     *  reference: https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC721/IERC721Receiver.sol
     */

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

    /**
     * @dev get nft data fields store in this contract
     * @param _index index at which nft data store in array in s_userStakingData:NFTStakingData
     * @return isStaked is nft staked or not unstaked
     * @return contractAddress nft contractAddress
     * @return id nft token id
     * @return stakingBlockNumber block.number at which nft staked
     * @return unstakingBlockNumber block.number at which nft unstaked
     * @return unstakeTime block.timestamp at which nft is unstaked
     */
    function getNFTData(
        uint256 _index
    ) external view returns (bool, address, uint256, uint256, uint256, uint32) {
        NFTStakingData memory _nftStakingData = s_userStakingData[_msgSender()]
            .nftData[_index];
        return (
            _nftStakingData.isStaked,
            _nftStakingData.contractAddress,
            _nftStakingData.id,
            _nftStakingData.stakingBlockNumber,
            _nftStakingData.unstakingBlockNumber,
            _nftStakingData.unstakeTime
        );
    }
}
