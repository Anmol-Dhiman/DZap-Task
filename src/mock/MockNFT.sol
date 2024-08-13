// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;
import {ERC721} from "openzeppelin-contracts/token/ERC721/ERC721.sol";

contract MockNFT is ERC721 {
    uint256 public tokenId;
    constructor() ERC721("mock NFT contract", "MNFT") {}

    function mint() external returns (uint256) {
        tokenId++;
        _mint(msg.sender, tokenId);
        return tokenId;
    }
}
