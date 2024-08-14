// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

/// @custom:authors: [@anmol-dhiman]

import {Initializable} from "openzeppelin-contracts/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "openzeppelin-contracts/proxy/utils/UUPSUpgradeable.sol";

/**
@title Mock implementations for testing the proxy contracts
@notice test associated StakingTask.t.sol:test_ProxyImplementation
 */

contract MockProxyV1 is UUPSUpgradeable, Initializable {
    address public owner;

    function initialize(address _owner) external reinitializer(1) {
        owner = _owner;
    }

    function _authorizeUpgrade(address newImplementation) internal override {
        require(msg.sender == owner, "Not Owner");
    }

    function version() external pure returns (string memory) {
        return "V1";
    }
}

contract MockProxyV2 is UUPSUpgradeable, Initializable {
    address public owner;
    uint public counter;

    function initialize(
        address _owner,
        uint256 _counter
    ) external reinitializer(2) {
        owner = _owner;
        counter = _counter;
    }

    function _authorizeUpgrade(address newImplementation) internal override {
        require(msg.sender == owner, "Not Owner");
    }

    function version() external pure returns (string memory) {
        return "V2";
    }
}
