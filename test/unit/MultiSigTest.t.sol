// SPDX-License-Identifier: MIT

pragma solidity 0.8.30;

import {Test} from "forge-std/Test.sol";
import {MultiSig} from "src/MultiSig.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";

contract MultiSigTest is Test {
    MultiSig public wallet;
    HelperConfig public config;

    address[] owners;
    address public to = makeAddr("to");

    address public constant ADDRESS_ZERO = address(0);
    uint256 public constant ZERO = 0;
    uint256 public constant ONE = 1;
    uint256 public constant TX_ID = 1;
    uint256 public constant TWO = 2;
    uint256 public constant TEN = 10;
    uint256 public constant SUBMIT_VALUE = 1 ether;
    uint256 public constant WALLET_FOUNDS = 10 ether;
    bytes public EMPTY_BYTES;

    modifier submitTransaction() {
        vm.prank(owners[ONE]);
        wallet.submit(to, SUBMIT_VALUE, EMPTY_BYTES);
        _;
    }

    modifier addFoundToWallet() {
        vm.prank(owners[ZERO]);
        (bool success, ) = payable(address(wallet)).call{value: WALLET_FOUNDS}("");
        assert(success);
        _;
    }

    function setUp() public {
        config = new HelperConfig();
        wallet = config.run();

        owners = wallet.getOwners();
    }

    // constructor
    /// validateThreshold
    //// revert ThresholdCanNotBeZero
    function test__constructor__revertThresholdCanNotBeZero() public {
        vm.expectRevert(MultiSig.MultiSig__ThresholdCanNotBeZero.selector);
        new MultiSig(owners, ZERO);
    }

    //// revert OwnersCanNotBeEmpty
    function test__constructor__revertOwnersCanNotBeEmpty() public {
        address[] memory emptyOwners;
        vm.expectRevert(MultiSig.MultiSig__OwnersCanNotBeEmpty.selector);
        new MultiSig(emptyOwners, ONE);
    }

    //// revert ThresholdExceedsOwners
    function test__constructor__revertThresholdExceedsOwners() public {
        vm.expectRevert(MultiSig.MultiSig__ThresholdExceedsOwners.selector);
        new MultiSig(owners, TEN);
    }

    /// validateOwner
    //// revert OwnerAddressCanNotBeZero
    function test__constructor__revertOwnerAddressCanNotBeZero() public {
        owners.push(address(0));
        vm.expectRevert(MultiSig.MultiSig__OwnerAddressCanNotBeZero.selector);
        new MultiSig(owners, TWO);
    }

    //// revert OwnersAddressCanNotBeTheSame
    function test__constructor__revertOwnersAddressCanNotBeTheSame() public {
        owners.push(owners[ZERO]);
        vm.expectRevert(MultiSig.MultiSig__OwnersAddressCanNotBeTheSame.selector);
        new MultiSig(owners, TWO);
    }

    // sumbit
    /// revert YouAreNotOwner
    function test__submit__revertYouAreNotOwner() public {
        vm.prank(makeAddr("marc"));
        vm.expectRevert(MultiSig.MultiSig__YouAreNotOwner.selector);
        wallet.submit(to, SUBMIT_VALUE, EMPTY_BYTES);

        assertEq(wallet.getCurrentTxId(), ZERO);
    }

    /// revert EmptyTransaction
    function test__submit__revertEmptyTransaction() public {
        vm.prank(owners[ZERO]);
        vm.expectRevert(MultiSig.MultiSig__EmptyTransaction.selector);
        wallet.submit(to, ZERO, EMPTY_BYTES);

        assertEq(wallet.getCurrentTxId(), ZERO);
    }

    /// revert AddressToCanNotBeZero
    function test__submit__revertAddressToCanNotBeZero() public {
        vm.prank(owners[ONE]);
        vm.expectRevert(MultiSig.MultiSig__AddressToCanNotBeZero.selector);
        wallet.submit(ADDRESS_ZERO, SUBMIT_VALUE, EMPTY_BYTES);

        assertEq(wallet.getCurrentTxId(), ZERO);
    }

    /// success
    function test__submit() public {
        vm.prank(owners[TWO]);
        wallet.submit(to, SUBMIT_VALUE, EMPTY_BYTES);

        assertEq(wallet.getCurrentTxId(), ONE);

        MultiSig.Transaction memory transaction = wallet.getTransactionByTxId(TX_ID);
        assertEq(transaction.to, to);
        assertEq(transaction.value, SUBMIT_VALUE);
        assertEq(transaction.data, EMPTY_BYTES);
        assertEq(transaction.executed, false);
        assertEq(transaction.numConfirmations, ZERO);
        assertEq(transaction.revoked, false);
        assertEq(transaction.numRevokes, ZERO);
        assertEq(transaction.createdAt, block.timestamp);
        assertEq(transaction.endAt, ZERO);
    }

    // confirm
    /// revert YouAreNotOwner
    function test__confirm__revertYouAreNotOwner() public {
        vm.prank(makeAddr("marc"));
        vm.expectRevert(MultiSig.MultiSig__YouAreNotOwner.selector);
        wallet.confirm(TX_ID);

        MultiSig.Transaction memory transaction = wallet.getTransactionByTxId(TX_ID);
        assertEq(transaction.numConfirmations, ZERO);
    }

    /// revert TransactionIdCanNotBeZero
    function test__confirm__revertTransactionIdCanNotBeZero() public {
        vm.prank(owners[ZERO]);
        vm.expectRevert(MultiSig.MultiSig__TransactionIdCanNotBeZero.selector);
        wallet.confirm(ZERO);

        MultiSig.Transaction memory transaction = wallet.getTransactionByTxId(TX_ID);
        assertEq(transaction.numConfirmations, ZERO);
    }

    /// revert TransactionNotExist
    function test__confirm__revertTransactionNotExist() public {
        vm.prank(owners[ONE]);
        vm.expectRevert(MultiSig.MultiSig__TransactionNotExist.selector);
        wallet.confirm(TWO);

        MultiSig.Transaction memory transaction = wallet.getTransactionByTxId(TX_ID);
        assertEq(transaction.numConfirmations, ZERO);
    }

    /// revert AlreadyVoted
    function test__confirm__revertAlreadyVoted() public submitTransaction {
        vm.prank(owners[ONE]);
        wallet.confirm(ONE);

        vm.prank(owners[ONE]);
        vm.expectRevert(MultiSig.MultiSig__AlreadyVoted.selector);
        wallet.confirm(ONE);

        MultiSig.Transaction memory transaction = wallet.getTransactionByTxId(TX_ID);
        assertEq(transaction.numConfirmations, ONE);
    }

    /// revert AlreadyExecutedOrRevoked
    function test__confirm__alreadyExectuedOrRevoked() public submitTransaction addFoundToWallet {
        vm.prank(owners[ZERO]);
        wallet.confirm(ONE);
    
        vm.prank(owners[ONE]);
        wallet.confirm(ONE);

        vm.prank(owners[TWO]);
        wallet.execute(ONE);

        MultiSig.Transaction memory transaction = wallet.getTransactionByTxId(TX_ID);
        assertEq(transaction.executed, true);

        vm.prank(owners[TWO]);
        vm.expectRevert(MultiSig.MultiSig__AlreadyExecutedOrRevoked.selector);
        wallet.confirm(ONE);
    }

    /// success
    function test__confirm() public submitTransaction {
        vm.prank(owners[ZERO]);
        wallet.confirm(ONE);
        
        MultiSig.Transaction memory transaction = wallet.getTransactionByTxId(TX_ID);
        assertEq(transaction.numConfirmations, ONE);
    }

    // revoke
    /// revert YouAreNotOwner
    function test__revoke__revertYouAreNotOwner() public {
        vm.prank(makeAddr("marc"));
        vm.expectRevert(MultiSig.MultiSig__YouAreNotOwner.selector);
        wallet.revoke(TX_ID);

        MultiSig.Transaction memory transaction = wallet.getTransactionByTxId(TX_ID);
        assertEq(transaction.numRevokes, ZERO);
    }

    /// revert TransactionIdCanNotBeZero
    function test__revoke__revertTransactionIdCanNotBeZero() public {
        vm.prank(owners[ZERO]);
        vm.expectRevert(MultiSig.MultiSig__TransactionIdCanNotBeZero.selector);
        wallet.revoke(ZERO);

        MultiSig.Transaction memory transaction = wallet.getTransactionByTxId(TX_ID);
        assertEq(transaction.numRevokes, ZERO);
    }

    /// revert TransactionNotExist
    function test__revoke__revertTransactionNotExist() public {
        vm.prank(owners[ZERO]);
        vm.expectRevert(MultiSig.MultiSig__TransactionNotExist.selector);
        wallet.revoke(TWO);

        MultiSig.Transaction memory transaction = wallet.getTransactionByTxId(TX_ID);
        assertEq(transaction.numRevokes, ZERO);
    }
    
    /// revert AlreadyVoted
    function test__revoke__revertAlreadyVoted() public submitTransaction {
        vm.prank(owners[ZERO]);
        wallet.revoke(TX_ID);

        vm.prank(owners[ZERO]);
        vm.expectRevert(MultiSig.MultiSig__AlreadyVoted.selector);
        wallet.revoke(TX_ID);

        MultiSig.Transaction memory transaction = wallet.getTransactionByTxId(TX_ID);
        assertEq(transaction.numRevokes, ONE);
    }

    /// revert AlreadyExecutedOrRevoked
    function test__revoke__alreadyExectuedOrRevoked() public submitTransaction addFoundToWallet {
        vm.prank(owners[ZERO]);
        wallet.revoke(TX_ID);
    
        vm.prank(owners[ONE]);
        wallet.revoke(TX_ID);

        vm.prank(owners[TWO]);
        wallet.execute(TX_ID);

        MultiSig.Transaction memory transaction = wallet.getTransactionByTxId(TX_ID);
        assertEq(transaction.revoked, true);

        vm.prank(owners[TWO]);
        vm.expectRevert(MultiSig.MultiSig__AlreadyExecutedOrRevoked.selector);
        wallet.revoke(TX_ID);
    }

    /// success
    function test__revoke() public submitTransaction {
        vm.prank(owners[ONE]);
        wallet.revoke(TX_ID);

        MultiSig.Transaction memory transaction = wallet.getTransactionByTxId(TX_ID);
        assertEq(transaction.numRevokes, ONE);
    }

    // execute
    /// revert YouAreNotOwner
    function test__execute__revertYouAreNotOwner() public {
        vm.prank(makeAddr("marc"));
        vm.expectRevert(MultiSig.MultiSig__YouAreNotOwner.selector);
        wallet.execute(TX_ID);

        MultiSig.Transaction memory transaction = wallet.getTransactionByTxId(TX_ID);
        assertEq(transaction.executed, false);
        assertEq(transaction.revoked, false);
    }

    /// revert TransactionIdCanNotBeZero
    function test__execute__revertTransactionIdCanNotBeZero() public {
        vm.prank(owners[TWO]);
        vm.expectRevert(MultiSig.MultiSig__TransactionIdCanNotBeZero.selector);
        wallet.execute(ZERO);

        MultiSig.Transaction memory transaction = wallet.getTransactionByTxId(TX_ID);
        assertEq(transaction.executed, false);
        assertEq(transaction.revoked, false);
    }

    /// revert TransactionNotExist
    function test__execute__revertTransactionNotExist() public {
        vm.prank(owners[TWO]);
        vm.expectRevert(MultiSig.MultiSig__TransactionNotExist.selector);
        wallet.execute(TWO);

        MultiSig.Transaction memory transaction = wallet.getTransactionByTxId(TX_ID);
        assertEq(transaction.executed, false);
        assertEq(transaction.revoked, false);
    }
    
    /// revert AlreadyExecutedOrRevoked
    function test__execute__revertAlreadyExecutedOrRevoked() public submitTransaction {
        vm.prank(owners[ZERO]);
        wallet.revoke(TX_ID);

        vm.prank(owners[ONE]);
        wallet.revoke(TX_ID);

        vm.prank(owners[ONE]);
        wallet.execute(TX_ID);

        MultiSig.Transaction memory transaction = wallet.getTransactionByTxId(TX_ID);
        assertEq(transaction.executed, false);
        assertEq(transaction.revoked, true);

        vm.prank(owners[TWO]);
        vm.expectRevert(MultiSig.MultiSig__AlreadyExecutedOrRevoked.selector);
        wallet.execute(TX_ID);
    }

    /// revert NotEnoughApprovals
    function test__execute__revertNotEnoughApprovals() public submitTransaction {
        vm.prank(owners[ZERO]);
        wallet.revoke(TX_ID);

        vm.prank(owners[ONE]);
        vm.expectRevert(MultiSig.MultiSig__NotEnoughApprovals.selector);
        wallet.execute(TX_ID);

        MultiSig.Transaction memory transaction = wallet.getTransactionByTxId(TX_ID);
        assertEq(transaction.executed, false);
        assertEq(transaction.revoked, false);
    }

    /// success NumConfirmations >= threshold
    function test__execute__executed() public submitTransaction addFoundToWallet {
        vm.prank(owners[ZERO]);
        wallet.confirm(TX_ID);

        vm.prank(owners[TWO]);
        wallet.confirm(TX_ID);

        vm.prank(owners[ONE]);
        wallet.execute(TX_ID);

        assertEq(address(wallet).balance, WALLET_FOUNDS - SUBMIT_VALUE);
        assertEq(to.balance, SUBMIT_VALUE);

        MultiSig.Transaction memory transaction = wallet.getTransactionByTxId(TX_ID);
        assertEq(transaction.executed, true);
        assertEq(transaction.revoked, false);
    }

    /// success numRevoks >= threshold
    function test__execute__revoked() public submitTransaction addFoundToWallet {
        vm.prank(owners[ZERO]);
        wallet.revoke(TX_ID);

        vm.prank(owners[TWO]);
        wallet.revoke(TX_ID);

        vm.prank(owners[ONE]);
        wallet.execute(TX_ID);

        assertEq(address(wallet).balance, WALLET_FOUNDS);
        assertEq(to.balance, ZERO);

        MultiSig.Transaction memory transaction = wallet.getTransactionByTxId(TX_ID);
        assertEq(transaction.executed, false);
        assertEq(transaction.revoked, true);
    }

    // getFunctions 

}