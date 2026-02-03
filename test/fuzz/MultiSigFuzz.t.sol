// SPDX-License-Identifier: MIT

pragma solidity 0.8.30;

import {Test} from "forge-std/Test.sol";
import {MultiSig} from "src/MultiSig.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";

contract MultiSigFuzz is Test {
    MultiSig public wallet;
    HelperConfig public config;

    address[] public owners;
    uint256 public constant SUBMIT_VALUE = 1 ether;
    bytes public EMPTY_BYTES;

    function setUp() public {
        config = new HelperConfig();
        wallet = config.run();

        owners = wallet.getOwners();
    }

    function testFuzz__constructor__revertOwnersCanNotBeEmpty(uint256 threshold) public {
        threshold = bound(threshold, 1, type(uint256).max);

        address[] memory emptyOwners;
        vm.expectRevert(MultiSig.MultiSig__OwnersCanNotBeEmpty.selector);
        new MultiSig(emptyOwners, threshold);
    }

    function testFuzz__constructor__revertThresholdExceedsOwners(uint256 threshold) public {
        threshold = bound(threshold, owners.length + 1, type(uint256).max);

        vm.expectRevert(MultiSig.MultiSig__ThresholdExceedsOwners.selector);
        new MultiSig(owners, threshold);
    }

    function testFuzz__submit__revertYouAreNotOwner(address user, uint256 submitValue, bytes memory bytesValue) public {
        assumeOwnerAddress(user);

        vm.prank(user);
        vm.expectRevert();
        wallet.submit(user, submitValue, bytesValue);
    }

    function testFuzz__submit__revertAddressToCanNotBeZero(uint256 submitValue, bytes memory bytesValue) public {
        vm.prank(owners[0]);
        vm.expectRevert();
        wallet.submit(address(0), submitValue, bytesValue);
    }

    function testFuzz__submit(address to, uint256 submitValue, bytes memory bytesValue) public {
        assumeOwnerAddress(to);
        vm.assume(submitValue != 0 && bytesValue.length != 0);

        vm.prank(owners[0]);
        wallet.submit(to, submitValue, bytesValue);

        assertEq(wallet.getCurrentTxId(), 1);

        MultiSig.Transaction memory transaction = wallet.getTransactionByTxId(1);
        assertEq(transaction.to, to);
        assertEq(transaction.value, submitValue);
        assertEq(transaction.data, bytesValue);
        assertEq(transaction.executed, false);
        assertEq(transaction.numConfirmations, 0);
        assertEq(transaction.revoked, false);
        assertEq(transaction.numRevokes, 0);
        assertEq(transaction.createdAt, block.timestamp);
        assertEq(transaction.endAt, 0);
    }

    function testFuzz__confirm__revertYouAreNotOwner(address user, uint256 txId) public {
        assumeOwnerAddress(user);

        vm.prank(user);
        vm.expectRevert();
        wallet.confirm(txId);
    }

    function testFuzz__revoke__revertYouAreNotOwner(address user, uint256 txId) public {
        assumeOwnerAddress(user);

        vm.prank(user);
        vm.expectRevert();
        wallet.revoke(txId);
    }

    function testFuzz__execute__revertYouAreNotOwner(address user, uint256 txId) public {
        assumeOwnerAddress(user);

        vm.prank(user);
        vm.expectRevert();
        wallet.revoke(txId);
    }

    function testFuzz__execute__confirm(uint256 submitValue, bytes memory dataValue) public {
        // why dont use address to from fuzzing, because if comes address 
        // to 0...01 to 0...09 will be recive a evm precompile error
        address x = makeAddr("x");
        vm.assume(submitValue != 0 && dataValue.length != 0);
        
        // put submitValue input to wallet
        vm.deal(address(wallet), submitValue);

        // create a tx
        vm.prank(owners[0]);
        wallet.submit(x, submitValue, dataValue );

        // vote to confirm
        vm.prank(owners[0]);
        wallet.confirm(1);

        vm.prank(owners[1]);
        wallet.confirm(1);

        // execute tx
        vm.prank(owners[2]);
        wallet.execute(1);

        assertEq(address(wallet).balance, 0);
        assertEq(x.balance, submitValue);

        MultiSig.Transaction memory transaction = wallet.getTransactionByTxId(1);
        assertEq(transaction.executed, true);
        assertEq(transaction.revoked, false);
        assertEq(transaction.endAt, block.timestamp);
    }

    function testFuzz__execute__revoke(uint256 submitValue, bytes memory dataValue) public {
        // why dont use address to from fuzzing, because if comes address 
        // to 0...01 to 0...09 will be recive a evm precompile error
        address x = makeAddr("x");
        vm.assume(submitValue != 0 && dataValue.length != 0);
        
        // put submitValue input to wallet
        vm.deal(address(wallet), submitValue);

        // create a tx
        vm.prank(owners[0]);
        wallet.submit(x, submitValue, dataValue );

        // vote to confirm
        vm.prank(owners[0]);
        wallet.revoke(1);

        vm.prank(owners[1]);
        wallet.revoke(1);

        // execute tx
        vm.prank(owners[2]);
        wallet.execute(1);

        assertEq(address(wallet).balance, submitValue);
        assertEq(x.balance, 0);

        MultiSig.Transaction memory transaction = wallet.getTransactionByTxId(1);
        assertEq(transaction.executed, false);
        assertEq(transaction.revoked, true);
        assertEq(transaction.endAt, block.timestamp);
    }

    // helpers
    function assumeOwnerAddress(address randomAddress) internal view {
        vm.assume(randomAddress != address(0));
        for (uint256 i = 0; i < owners.length; i++) {
            vm.assume(randomAddress != owners[i]);
        }
    }
}
