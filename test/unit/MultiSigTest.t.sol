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
        (bool success,) = payable(address(wallet)).call{value: WALLET_FOUNDS}("");
        assert(success);
        _;
    }

    modifier confirmTransaction(address owner, uint256 txId) {
        vm.prank(owner);
        wallet.confirm(txId);
        _;
    }

    modifier revokeTransaction(address owner, uint256 txId) {
        vm.prank(owner);
        wallet.revoke(txId);
        _;
    }

    modifier executeTransaction(uint256 txId) {
        vm.prank(owners[ONE]);
        wallet.execute(txId);
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
    function test__submit() public submitTransaction {
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
    function test__confirm__revertAlreadyVoted() public submitTransaction confirmTransaction(owners[ONE], TX_ID) {
        vm.prank(owners[ONE]);
        vm.expectRevert(MultiSig.MultiSig__AlreadyVoted.selector);
        wallet.confirm(ONE);

        MultiSig.Transaction memory transaction = wallet.getTransactionByTxId(TX_ID);
        assertEq(transaction.numConfirmations, ONE);
    }

    /// revert AlreadyExecutedOrRevoked
    function test__confirm__alreadyExectuedOrRevoked()
        public
        submitTransaction
        addFoundToWallet
        confirmTransaction(owners[ZERO], TX_ID)
        confirmTransaction(owners[ONE], TX_ID)
        executeTransaction(TX_ID)
    {
        MultiSig.Transaction memory transaction = wallet.getTransactionByTxId(TX_ID);
        assertEq(transaction.executed, true);

        vm.prank(owners[TWO]);
        vm.expectRevert(MultiSig.MultiSig__AlreadyExecutedOrRevoked.selector);
        wallet.confirm(ONE);
    }

    /// success
    function test__confirm() public submitTransaction confirmTransaction(owners[ZERO], TX_ID) {
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
    function test__revoke__revertAlreadyVoted() public submitTransaction revokeTransaction(owners[ZERO], TX_ID) {
        vm.prank(owners[ZERO]);
        vm.expectRevert(MultiSig.MultiSig__AlreadyVoted.selector);
        wallet.revoke(TX_ID);

        MultiSig.Transaction memory transaction = wallet.getTransactionByTxId(TX_ID);
        assertEq(transaction.numRevokes, ONE);
    }

    /// revert AlreadyExecutedOrRevoked
    function test__revoke__alreadyExectuedOrRevoked()
        public
        submitTransaction
        addFoundToWallet
        revokeTransaction(owners[ZERO], TX_ID)
        revokeTransaction(owners[ONE], TX_ID)
        executeTransaction(TX_ID)
    {
        MultiSig.Transaction memory transaction = wallet.getTransactionByTxId(TX_ID);
        assertEq(transaction.revoked, true);

        vm.prank(owners[TWO]);
        vm.expectRevert(MultiSig.MultiSig__AlreadyExecutedOrRevoked.selector);
        wallet.revoke(TX_ID);
    }

    /// success
    function test__revoke() public submitTransaction revokeTransaction(owners[ONE], TX_ID) {
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
    function test__execute__revertAlreadyExecutedOrRevoked()
        public
        submitTransaction
        revokeTransaction(owners[ZERO], TX_ID)
        revokeTransaction(owners[ONE], TX_ID)
        executeTransaction(TX_ID)
    {
        MultiSig.Transaction memory transaction = wallet.getTransactionByTxId(TX_ID);
        assertEq(transaction.executed, false);
        assertEq(transaction.revoked, true);

        vm.prank(owners[TWO]);
        vm.expectRevert(MultiSig.MultiSig__AlreadyExecutedOrRevoked.selector);
        wallet.execute(TX_ID);
    }

    /// revert NotEnoughApprovals
    function test__execute__revertNotEnoughApprovals() public submitTransaction revokeTransaction(owners[ZERO], TX_ID) {
        vm.prank(owners[ONE]);
        vm.expectRevert(MultiSig.MultiSig__NotEnoughApprovals.selector);
        wallet.execute(TX_ID);

        MultiSig.Transaction memory transaction = wallet.getTransactionByTxId(TX_ID);
        assertEq(transaction.executed, false);
        assertEq(transaction.revoked, false);
    }

    /// success NumConfirmations >= threshold
    function test__execute__executed()
        public
        submitTransaction
        addFoundToWallet
        confirmTransaction(owners[ZERO], TX_ID)
        confirmTransaction(owners[ONE], TX_ID)
        executeTransaction(TX_ID)
    {
        assertEq(address(wallet).balance, WALLET_FOUNDS - SUBMIT_VALUE);
        assertEq(to.balance, SUBMIT_VALUE);

        MultiSig.Transaction memory transaction = wallet.getTransactionByTxId(TX_ID);
        assertEq(transaction.executed, true);
        assertEq(transaction.revoked, false);
    }

    /// success numRevoks >= threshold
    function test__execute__revoked()
        public
        submitTransaction
        addFoundToWallet
        revokeTransaction(owners[ZERO], TX_ID)
        revokeTransaction(owners[ONE], TX_ID)
        executeTransaction(TX_ID)
    {
        assertEq(address(wallet).balance, WALLET_FOUNDS);
        assertEq(to.balance, ZERO);

        MultiSig.Transaction memory transaction = wallet.getTransactionByTxId(TX_ID);
        assertEq(transaction.executed, false);
        assertEq(transaction.revoked, true);
    }

    // getFunctions
    function test__getOwners() public view {
        assertEq(wallet.getOwners(), owners);
    }

    function test__getIfIsOwner() public view {
        assertEq(wallet.getIfIsOwner(owners[ZERO]), true);
        assertEq(wallet.getIfIsOwner(ADDRESS_ZERO), false);
    }

    function test__getThreshold() public view {
        assertEq(wallet.getThreshold(), TWO);
    }

    function test__getTransacionByTxId() public submitTransaction {
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

    function test__getResponsesByOwnerAndTxId()
        public
        submitTransaction
        confirmTransaction(owners[ZERO], TX_ID)
        revokeTransaction(owners[ONE], TX_ID)
    {
        assertEq(uint256(wallet.getResponsesByOwnerAndTxId(TX_ID, owners[ZERO])), ONE);
        assertEq(uint256(wallet.getResponsesByOwnerAndTxId(TX_ID, owners[ONE])), TWO);
    }
}
