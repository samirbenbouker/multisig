// SPDX-License-Identifier: MIT

pragma solidity 0.8.30;

import {Script} from "forge-std/Script.sol";
import {MultiSig} from "src/MultiSig.sol";

contract HelperConfig is Script {

    address public bob = makeAddr("bob");
    address public alice = makeAddr("alice");
    address public pep = makeAddr("pep");

    address[] public owners;

    uint256 public constant INITIAL_AMOUNT = 100 ether;

    function run() public returns (MultiSig) {
        addFoundToOwners();
        uint256 threshold = 2;
        return deployMultiSig(owners, threshold);
    }

    function deployMultiSig(address[] memory _owners, uint256 _threshold) public returns (MultiSig) {
        vm.startBroadcast();
        MultiSig wallet = new MultiSig(_owners, _threshold);
        vm.stopBroadcast();

        return wallet;
    }

    function addFoundToOwners() internal {
        owners = [bob, alice, pep];
        for(uint256 i = 0; i < owners.length; i++) {
            vm.deal(owners[i], INITIAL_AMOUNT);
        }
    }
    
}