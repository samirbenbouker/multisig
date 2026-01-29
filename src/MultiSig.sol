// SPDX-License-Identifier: MIT

pragma solidity 0.8.30;

contract MultiSig {
    // -------------------------
    // ERRORS
    // -------------------------
    error MultiSig__OwnerAddressCanNotBeZero();
    error MultiSig__OwnersAddressCanNotBeTheSame();
    error MultiSig__ThresholdCanNotBeZero();
    error MultiSig__EmptyTransaction();
    error MultiSig__AddressToCanNotBeZero();
    error MultiSig__TransactionIdCanNotBeZero();
    error MultiSig__YouAreNotOwner();
    error MultiSig__AlreadyVoted();
    error MultiSig__AlreadyExecuted();
    error MultiSig__TransactionFailed();

    // -------------------------
    // ENUMS
    // -------------------------
    enum Status {
        NO_RESPONSE,
        CONFIRM,
        REVOKE
    }

    // -------------------------
    // STRUCTS
    // -------------------------
    struct Transaction {
        address to;
        uint256 value;
        bytes data;
        bool executed;
        uint256 numConfirmations;
        uint256 numRevokes;
        uint256 createdAt;
        uint256 endAt;
    }

    // -------------------------
    // STORAGE
    // -------------------------
    address[] private s_owners;
    uint256 private s_threshold;
    uint256 private s_txId;
    mapping(uint256 txId => Transaction transaction) private s_txs;
    mapping(uint256 txId => mapping(address owner => Status status)) private s_responses;

    // -------------------------
    // EVENTS
    // -------------------------
    event Submit(uint256 indexed txId, address indexed to, uint256 indexed value, bytes data);
    event Confirm(uint256 indexed txId, address indexed owner);
    event Revoke(uint256 indexed txId, address indexed owner);
    event Execute(address indexed owner, uint256 indexed txId);

    // -------------------------
    // MODIFIERS
    // -------------------------
    modifier onlyOwners(address sender) {
        _checkOwners(sender);
        _;
    }

    constructor(address[] memory _owners, uint256 _threshold) {
        _validateOwner(_owners);
        _validateThreshold(_threshold);

        s_owners = _owners;
        s_threshold = _threshold;
        s_txId = 0;
    }

    receive() external payable {}

    // -------------------------
    // EXTERNAL FUNCTIONS
    // -------------------------
    function submit(address _to, uint256 _value, bytes memory _data) external {
        if (_value == 0 && _data.length == 0) {
            revert MultiSig__EmptyTransaction();
        }

        if (_to == address(0)) {
            revert MultiSig__AddressToCanNotBeZero();
        }

        s_txId++;

        s_txs[s_txId] = Transaction({
            to: _to,
            value: _value,
            data: _data,
            executed: false,
            numConfirmations: 0,
            numRevokes: 0,
            createdAt: block.timestamp,
            endAt: 0
        });

        emit Submit(s_txId, _to, _value, _data);
    }

    function confirm(uint256 _txId) external onlyOwners(msg.sender) {
        Transaction storage transaction = _checkTransactionExecuted(_txId);
        transaction.numConfirmations++;
        s_responses[_txId][msg.sender] = Status.CONFIRM;

        emit Confirm(_txId, msg.sender);
    }

    function revoke(uint256 _txId) external onlyOwners(msg.sender) {
        Transaction storage transaction = _checkTransactionExecuted(_txId);
        transaction.numRevokes++;
        s_responses[_txId][msg.sender] = Status.REVOKE;

        emit Revoke(_txId, msg.sender);
    }

    function execute(uint256 _txId) external onlyOwners(msg.sender) {
        _checkTransactionId(_txId);

        Transaction storage transaction = s_txs[_txId];
        transaction.executed = true;
        transaction.endAt = block.timestamp;

        if (transaction.numConfirmations >= s_threshold) {
            (bool success, ) = payable(msg.sender).call{value: transaction.value}(transaction.data);
            if(!success) {
                revert MultiSig__TransactionFailed();
            }
        } 
        
        emit Execute(msg.sender, _txId);
    }

    // -------------------------
    // INTERNAL FUNCTIONS
    // -------------------------
    function _validateOwner(address[] memory owners) internal pure {
        uint256 length = owners.length;
        for (uint256 i = 0; i < length - 1; i++) {
            for (uint256 j = i + 1; j < length; j++) {
                if (owners[i] == address(0)) {
                    revert MultiSig__OwnerAddressCanNotBeZero();
                }

                if (owners[i] == owners[j]) {
                    revert MultiSig__OwnersAddressCanNotBeTheSame();
                }
            }
        }
    }

    function _validateThreshold(uint256 threshold) internal pure {
        if (threshold == 0) {
            revert MultiSig__ThresholdCanNotBeZero();
        }
    }

    function _checkOwners(address sender) internal view {
        if (!_onlyOwners(sender)) {
            revert MultiSig__YouAreNotOwner();
        }
    }

    function _onlyOwners(address sender) internal view returns (bool) {
        uint256 length = s_owners.length;
        for (uint256 i = 0; i < length; i++) {
            if (s_owners[i] == sender) {
                return true;
            }
        }

        return false;
    }

    function _checkTransactionId(uint256 txId) internal pure {
        if (txId == 0) {
            revert MultiSig__TransactionIdCanNotBeZero();
        }
    }

    function _checkTransactionStatus(uint256 txId) internal view {
        if (s_responses[txId][msg.sender] != Status.NO_RESPONSE) {
            revert MultiSig__AlreadyVoted();
        }
    }

    function _checkTransaction(uint256 txId) internal view {
        _checkTransactionId(txId);
        _checkTransactionStatus(txId);
    }

    function _checkTransactionExecuted(uint256 txId) internal view returns (Transaction storage) {
        _checkTransaction(txId);

        Transaction storage transaction = s_txs[txId];
        if (transaction.executed != false) {
            revert MultiSig__AlreadyExecuted();
        }

        return transaction;
    }

    // -------------------------
    // GET FUNCTIONS
    // -------------------------
    function getOwners() external view returns (address[] memory) {
        return s_owners;
    }

    function getIfIsOwner(address owner) external view returns (bool) {
        uint256 length = s_owners.length;
        for(uint256 i = 0; i < length; i++) {
            if(owner == s_owners[i]) {
                return true;
            }
        }

        return false;
    }

    function getThreshold() external view returns (uint256) {
        return s_threshold;
    }

    function getCurrentTxId() external view returns (uint256) {
        return s_txId;
    }

    function getTransactionByTxId(uint256 _txId) external view returns (Transaction memory) {
        return s_txs[_txId];
    }

    function getResponsesByOwnerAndTxId(uint256 _txId, address _owner) external view returns (Status) {
        return s_responses[_txId][_owner];
    }

}
