// SPDX-License-Identifier: MIT
pragma solidity >0.5.0 <0.8.0;

/* Library Imports */
import { Lib_RLPReader } from "./libraries/Lib_RLPReader.sol";
import { Lib_SecureMerkleTrie } from "./libraries/Lib_SecureMerkleTrie.sol";
import { Lib_EIP155Tx } from "./libraries/Lib_EIP155Tx.sol";

import { console } from "hardhat/console.sol";

contract ETHMaxiToken {
    using Lib_EIP155Tx for Lib_EIP155Tx.EIP155Tx;

    event Transfer(
        address indexed _from,
        address indexed _to,
        uint256 _value
    );

    event Approval(
        address indexed _owner,
        address indexed _spender,
        uint256 _value
    );

    event Claimed(
        address indexed _owner,
        uint256 _value
    );

    event Slashed(
        address indexed _owner,
        address indexed _slasher,
        uint256 _value
    );

    // Just convenient for interfaces.
    string public constant name = 'Maxi ETH';
    string public constant symbol = 'mETH';
    uint256 public constant decimals = 18;

    // Will be dynamic, depends on total ETH supply at time of snapshot. Will increase as more
    // people claim.
    uint256 public totalSupply;

    // Balance/allowance mappings.
    mapping (address => uint256) public balances;
    mapping (address => mapping (address => uint256)) public allowed;
    
    // Make sure people can't claim more than once.
    mapping (address => bool) public claimed;

    // Make sure people can't get slashed more than once.
    mapping (address => bool) public slashed;

    // When the lockup ends.
    uint256 public lockupEndTime;

    // Hashes that people will use to prove their balances.
    uint256 public snapshotBlockNumber;
    bytes32 public snapshotBlockHash;
    bytes32 public snapshotStateRoot;

    constructor(
        uint256 _lockupPeriod,
        uint256 _snapshotBlockNumber,
        bytes memory _snapshotBlockHeader
    ) {
        lockupEndTime = block.timestamp + _lockupPeriod;
        snapshotBlockNumber = _snapshotBlockNumber;
        snapshotBlockHash = blockhash(_snapshotBlockNumber);

        console.logBytes32(keccak256(_snapshotBlockHeader));
        console.logBytes32(snapshotBlockHash);

        // // Just a safety measure.
        // require(
        //     keccak256(_snapshotBlockHeader) == snapshotBlockHash,
        //     "ETHMaxiToken: block header does not match snapshot block hash"
        // );

        // Decode the block header in order to pull out the state root.
        Lib_RLPReader.RLPItem[] memory blockHeader = Lib_RLPReader.readList(
            _snapshotBlockHeader
        );
        snapshotStateRoot = Lib_RLPReader.readBytes32(blockHeader[3]);
    }

    /**
     * We use a lockup period to prevent people from claiming and then transferring their tokens to
     * avoid getting slashed. Simple modifier for checking this condition.
     */
    modifier onlyAfterLockup() {
        require(
            block.timestamp > lockupEndTime,
            "ETHMaxiToken: lockup hasn't ended yet, nerd"
        );
        _;
    }

    /**
     * Function for redeeming tokens at a 1:1 ratio to ETH at the snapshot block. If you had 1 ETH
     * (= 10^18 wei) at the snapshot, you have 10^18 tokens. I.e., you have the same amount of
     * tokens. Also allows you to claim on behalf of someone else (*you* do the proof, *they* get
     * the money). Perhaps useful if you want to quickly claim and slash.
     * @param _owner Address to claim tokens for.
     * @param _proof RLP-encoded merkle trie inclusion proof for the address's account at the
     *               snapshot block height.
     * @return `true` if the function succeeded.
     */
    function claim(
        address _owner,
        bytes memory _proof
    )
        public
        returns (
            bool
        )
    {
        // You can only claim once per address.
        require(
            claimed[_owner] == false,
            "ETHMaxiToken: balance for address has already been claimed"
        );

        // Pull out the encoded account from the merkle trie proof.
        (bool exists, bytes memory encodedAccount) = Lib_SecureMerkleTrie.get(
            abi.encodePacked(_owner),
            _proof,
            snapshotStateRoot
        );

        require(
            exists == true,
            "ETHMaxiToken: bad eth merkle proof"
        );

        // Decode account to get its balance.
        Lib_RLPReader.RLPItem[] memory account = Lib_RLPReader.readList(
            encodedAccount
        );
        uint256 amount = Lib_RLPReader.readUint256(account[1]);

        // Mark as claimed and give out the balance.
        claimed[_owner] = true;
        balances[_owner] = amount;

        emit Transfer(address(0), _owner, amount);
        emit Claimed(_owner, amount);
        return true;
    }

    /**
     * Slashes an account based on a signed EIP155 transaction with a chain ID other than 1. Simply
     * provide the encoded signed transaction and be rewarded with the heretic's entire (claimed)
     * balance! Will *not* work if the user you're slashing hasn't claimed a balance yet. But you
     * can also claim on behalf of other users if you want to do some slashin'.
     * @param _encodedEIP155Tx RLP-encoded signed EIP155 transaction.
     * @return `true` if the slashin' was successful.
     */
    function slash(
        bytes memory _encodedEIP155Tx
    )
        public
        returns (
            bool
        )
    {
        Lib_EIP155Tx.EIP155Tx memory transaction = Lib_EIP155Tx.decode(
            _encodedEIP155Tx,
            1 // chain id of ethereum
        );

        address owner = transaction.sender();

        require(
            claimed[owner] == true,
            "ETHMaxiToken: can't slash because the user hasn't claimed"
        );

        require(
            slashed[owner] == false,
            "ETHMaxiToken: address has already been slashed"
        );

        uint256 amount = balances[owner];

        slashed[owner] = true;
        balances[msg.sender] += amount;
        balances[owner] = 0;
        emit Transfer(owner, msg.sender, amount);
        emit Slashed(owner, msg.sender, amount);
        return true;
    }

    function transfer(
        address _to,
        uint256 _value
    )
        public
        onlyAfterLockup
        returns (
            bool
        )
    {
        require(
            balances[msg.sender] >= _value,
            "ETHMaxiToken: you don't have enough balance to make this transfer"
        );

        balances[msg.sender] -= _value;
        balances[_to] += _value;
        emit Transfer(msg.sender, _to, _value);
        return true;
    }

    function transferFrom(
        address _from,
        address _to,
        uint256 _value
    )
        public
        onlyAfterLockup
        returns (
            bool
        )
    {
        require(
            allowed[_from][msg.sender] >= _value,
            "ETHMaxiToken: not enough allowance"
        );

        require(
            balances[_from] >= _value,
            "ETHMaxiToken: owner account doesn't have enough balance to make this transfer"
        );

        balances[_to] += _value;
        balances[_from] -= _value;
        allowed[_from][msg.sender] -= _value;
        emit Transfer(_from, _to, _value);
        return true;
    }

    function balanceOf(
        address _owner
    )
        public
        view
        returns (
            uint256
        )
    {
        return balances[_owner];
    }

    function approve(
        address _spender,
        uint256 _value
    )
        public
        returns (
            bool
        )
    {
        allowed[msg.sender][_spender] = _value;
        emit Approval(msg.sender, _spender, _value);
        return true;
    }

    function allowance(
        address _owner,
        address _spender
    )
        public
        view
        returns (
            uint256
        )
    {
        return allowed[_owner][_spender];
    }
}
