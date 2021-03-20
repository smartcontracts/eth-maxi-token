// SPDX-License-Identifier: MIT
pragma solidity >0.5.0 <0.8.0;

import { Lib_RLPReader } from "./libraries/Lib_RLPReader.sol";
import { Lib_SecureMerkleTrie } from "./libraries/Lib_SecureMerkleTrie.sol";

contract ETHMaxiToken {
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
    bytes32 public snapshotBlockHash;
    bytes32 public snapshotStateRoot;

    constructor(
        uint256 _lockupPeriod
    ) {
        lockupEndTime = block.timestamp + _lockupPeriod;
        snapshotBlockHash = blockhash(block.number - 1);
    }

    modifier onlyAfterLockup() {
        require(
            block.timestamp > lockupEndTime,
            "ETHMaxiToken: lockup hasn't ended yet, nerd"
        );
        _;
    }

    function setStateRoot(
        bytes memory _encodedBlockHeader
    )
        public
    {
        require(
            snapshotStateRoot == bytes32(0),
            "ETHMaxiToken: state root has already been set"
        );

        require(
            keccak256(_encodedBlockHeader) == snapshotBlockHash,
            "ETHMaxiToken: block header does not match snapshot block hash"
        );

        Lib_RLPReader.RLPItem[] memory blockHeader = Lib_RLPReader.readList(
            _encodedBlockHeader
        );

        snapshotStateRoot = Lib_RLPReader.readBytes32(blockHeader[3]);
    }

    function claim(
        address _owner,
        bytes memory _proof
    )
        public
        returns (
            bool
        )
    {
        require(
            claimed[_owner] == false,
            "ETHMaxiToken: balance for address has already been claimed"
        );

        (bool exists, bytes memory encodedAccount) = Lib_SecureMerkleTrie.get(
            abi.encodePacked(_owner),
            _proof,
            snapshotStateRoot
        );

        require(
            exists == true,
            "ETHMaxiToken: bad eth merkle proof"
        );

        Lib_RLPReader.RLPItem[] memory account = Lib_RLPReader.readList(
            encodedAccount
        );

        uint256 amount = Lib_RLPReader.readUint256(account[1]);

        claimed[_owner] = true;
        balances[_owner] = amount;
        emit Transfer(address(0), _owner, amount);
        return true;
    }

    function slash(
        bytes memory _encodedUnsignedTransaction,
        uint8 _v,
        bytes32 _r,
        bytes32 _s
    )
        public
        returns (
            bool
        )
    {
        Lib_RLPReader.RLPItem[] memory transaction = Lib_RLPReader.readList(
            _encodedUnsignedTransaction
        );

        uint256 chainId = Lib_RLPReader.readUint256(transaction[6]);

        require(
            chainId != 1,
            "ETHMaxiToken: chain id cannot be 1 (reserved for ethereum)"
        );

        address owner = ecrecover(
            keccak256(_encodedUnsignedTransaction),
            uint8(_v - 2 * chainId - 35),
            _r,
            _s
        );

        require(
            claimed[owner] == true,
            "ETHMaxiToken: can't slash because the user hasn't claimed"
        );

        require(
            slashed[owner] == false,
            "ETHMaxiToken: address has already been slashed"
        );

        slashed[owner] = true;
        balances[msg.sender] += balances[owner];
        balances[owner] = 0;
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
