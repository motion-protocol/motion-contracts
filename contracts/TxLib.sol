/**
 * Copyright (c) 2018-present, Leap DAO (leapdao.org)
 *
 * This source code is licensed under the Mozilla Public License, version 2,
 * found in the LICENSE file in the root directory of this source tree.
 */

pragma solidity 0.5.2;

library TxLib {

  uint constant internal WORD_SIZE = 32;
  uint constant internal ONES = ~uint(0);
  enum TxType { None0, None1, Deposit, Transfer, None4, None5,
  None6, None7, None8, None9, None10, None11, None12, SpendCond }

  struct Outpoint {
    bytes32 hash;
    uint8 pos;
  }

  struct Input {
    Outpoint outpoint;
    bytes32 r;
    bytes32 s;
    uint8 v;
    bytes script;
    bytes msgData;
  }

  struct Output {
    uint256 value;
    uint16 color;
    address owner;
    bytes32 stateRoot;
  }

  struct Tx {
    TxType txType;
    Input[] ins;
    Output[] outs;
  }

  function parseInput(
    TxType _type, bytes memory _txData, uint256 _pos, uint256 offset, Input[] memory _ins
  ) internal pure returns (uint256 newOffset) {
    bytes32 inputData;
    uint8 index;
    if (_type == TxType.Deposit) {
      assembly {
        // load the depositId (4 bytes) starting from byte 2 of tx
        inputData := mload(add(add(offset, 4), _txData))
      }
      inputData = bytes32(uint256(uint32(uint256(inputData))));
      index = 0;
      newOffset = offset + 4;
    } else {
      assembly {
        // load the prevHash (32 bytes) from input
        inputData := mload(add(add(offset, 32), _txData))
        // load the output index (1 byte) from input
        index := mload(add(add(offset, 33), _txData))
      }
      newOffset = offset + 33;
    }
    Outpoint memory outpoint = Outpoint(inputData, index);
    bytes memory data = new bytes(0);
    Input memory input = Input(outpoint, 0, 0, 0, data, data); // solium-disable-line arg-overflow
    if (_type == TxType.SpendCond) {
      uint16 len;
      assembly {
        len := mload(add(add(offset, 35), _txData)) 
      }
      // read msgData
      data = new bytes(len);  
      uint src;
      uint dest;
      assembly {  
        src := add(add(add(offset, 35), 0x20), _txData) 
        dest := add(data, 0x20) 
      }
      memcopy(src, dest, len);  
      input.msgData = data;  
      newOffset = offset + 37 + len;

      assembly {
        len := mload(add(newOffset, _txData)) 
      }

      // read script
      data = new bytes(len);
      assembly {  
        src := add(add(add(newOffset, 0), 0x20), _txData) 
        dest := add(data, 0x20) 
      }
      memcopy(src, dest, len);  
      input.script = data;
      newOffset = newOffset + len;
    }
    if (_type == TxType.Transfer) {
      bytes32 r;
      bytes32 s;
      uint8 v;
      assembly {
        r := mload(add(add(offset, 65), _txData))
        s := mload(add(add(offset, 97), _txData))
        v := mload(add(add(offset, 98), _txData))
      }
      input.r = r;
      input.s = s;
      input.v = v;
      newOffset = offset + 33 + 65;
    }
    _ins[_pos] = input;
  }

  // Copies 'len' bytes from 'srcPtr' to 'destPtr'.
  // NOTE: This function does not check if memory is allocated, it only copies the bytes.
  function memcopy(uint srcPtr, uint destPtr, uint len) internal pure {
    uint offset = 0;
    uint size = len / WORD_SIZE;
    // Copy word-length chunks while possible.
    for (uint i = 0; i < size; i++) {
      offset = i * WORD_SIZE;
      assembly {
        mstore(add(destPtr, offset), mload(add(srcPtr, offset)))
      }
    }
    offset = size*WORD_SIZE;
    uint mask = ONES << 8*(32 - len % WORD_SIZE);
    assembly {
      let nSrc := add(srcPtr, offset)
      let nDest := add(destPtr, offset)
      mstore(nDest, or(and(mload(nSrc), mask), and(mload(nDest), not(mask))))
    }
  }

  function parseOutput(
    bytes memory _txData, uint256 _pos, uint256 offset, Output[] memory _outs
  ) internal pure returns (uint256) {
    uint256 value;
    uint16 color;
    address owner;
    bytes32 data;

    assembly {
      offset := add(offset, 32)
      value := mload(add(offset, _txData))

      offset := add(offset, 2)
      color := and(mload(add(offset, _txData)), 0xffff)

      offset := add(offset, 20)
      owner := mload(add(offset, _txData))

      // NST - data
      // (2 ** 15) + (2 ** 14);
      if gt(color, 49152) {
        offset := add(offset, 32)
        data := mload(add(offset, _txData))
      }
    }

    Output memory output = Output(value, color, owner, data);  // solium-disable-line arg-overflow
    _outs[_pos] = output;

    return offset;
  }

  function parseTx(bytes memory _txData) internal pure returns (Tx memory txn) {
    // read type
    TxType txType;
    uint256 a;
    assembly {
      a := mload(add(0x20, _txData))
    }
    a = a >> 248; // get first byte
    if (a == 2) {
      txType = TxType.Deposit;
    } else if (a == 3) {
      txType = TxType.Transfer;
    } else if (a == 13) {
      txType = TxType.SpendCond;
    } else {
      revert("unknown tx type");
    }
    // read ins and outs
    assembly {
        a := mload(add(0x21, _txData))
    }
    a = a >> 252; // get ins-length nibble
    Input[] memory ins = new Input[](a);
    uint256 offset = 2;
    for (uint i = 0; i < ins.length; i++) {
      offset = parseInput(txType, _txData, i, offset, ins); // solium-disable-line arg-overflow
    }
    assembly {
        a := mload(add(0x21, _txData))
    }
    a = (a >> 248) & 0x0f; // get outs-length nibble
    Output[] memory outs = new Output[](a);
    for (uint256 i = 0; i < outs.length; i++) {
      offset = parseOutput(_txData, i, offset, outs); // solium-disable-line arg-overflow
    }
    txn = Tx(txType, ins, outs);
  }

  function getSigHash(bytes memory _txData) internal pure returns (bytes32 sigHash) {
    uint256 a;
    assembly {
      a := mload(add(0x20, _txData))
    }
    a = a >> 248;
    // if not transfer, sighash is just tx hash
    require(a == 3);
    // read ins
    assembly {
        a := mload(add(0x21, _txData))
    }
    a = a >> 252; // get ins-length nibble
    bytes memory sigData = new bytes(_txData.length);
    assembly {
      // copy type
      mstore8(add(sigData, 32), byte(0, mload(add(_txData, 32))))
      // copy #inputs / #outputs
      mstore8(add(sigData, 33), byte(1, mload(add(_txData, 32))))
      let offset := 0
      for
        { let i := 0 }
        lt(i, a)
        { i := add(i, 1) }
        {
          mstore(add(sigData, add(34, offset)), mload(add(_txData, add(34, offset))))
          mstore8(add(sigData, add(66, offset)), byte(0, mload(add(_txData, add(66, offset)))))
          offset := add(offset, add(33, 65))
        }
      for
        { let i := add(34, offset) }
        lt(i, add(64, mload(_txData)))
        { i := add(i, 0x20) }
        {
          mstore(add(sigData, i), mload(add(_txData, i)))
        }
    }

    return keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n", uint2str(_txData.length), sigData));
  }

  // solium-disable-next-line security/no-assign-params
  function getMerkleRoot(
    bytes32 _leaf, uint256 _index, uint256 _offset, bytes32[] memory _proof
  ) internal pure returns (bytes32) {
    bytes32 temp;
    for (uint256 i = _offset; i < _proof.length; i++) {
      temp = _proof[i];
      if (_index % 2 == 0) {
        assembly {
          mstore(0, _leaf)
          mstore(0x20, temp)
          _leaf := keccak256(0, 0x40)
        }
      } else {
        assembly {
          mstore(0, temp)
          mstore(0x20, _leaf)
          _leaf := keccak256(0, 0x40)
        }
      }
      _index = _index / 2;
    }
    return _leaf;
  }

  //validate that transaction is included to the period (merkle proof)
  function validateProof(
    uint256 _cdOffset, bytes32[] memory _proof
  ) internal pure returns (uint64 txPos, bytes32 txHash, bytes memory txData) {
    uint256 offset = uint8(uint256(_proof[1] >> 248));
    uint256 txLength = uint16(uint256(_proof[1] >> 224));

    txData = new bytes(txLength);
    assembly {
      calldatacopy(add(txData, 0x20), add(68, add(offset, _cdOffset)), txLength)
    }
    txHash = keccak256(txData);
    txPos = uint64(uint256(_proof[1] >> 160));
    bytes32 root = getMerkleRoot(
      txHash, 
      txPos, 
      uint8(uint256(_proof[1] >> 240)),
      _proof
    ); 
    require(root == _proof[0]);
  }

  function recoverTxSigner(uint256 offset, bytes32[] memory _proof) internal pure returns (address dest) {
    uint16 txLength = uint16(uint256(_proof[1] >> 224));
    bytes memory txData = new bytes(txLength);
    bytes32 r;
    bytes32 s;
    uint8 v;
    assembly {
      calldatacopy(add(txData, 32), add(114, offset), 43)
      r := calldataload(add(157, offset))
      s := calldataload(add(189, offset))
      v := calldataload(add(190, offset))
      calldatacopy(add(txData, 140), add(222, offset), 28) // 32 + 43 + 65
    }
    dest = ecrecover(getSigHash(txData), v, r, s); // solium-disable-line arg-overflow
  }

  // https://github.com/oraclize/ethereum-api/blob/master/oraclizeAPI_0.5.sol#L886
  // solium-disable-next-line security/no-assign-params
  function uint2str(uint _i) internal pure returns (string memory _uintAsString) {
    if (_i == 0) {
      return "0";
    }
    uint j = _i;
    uint len;
    while (j != 0) {
      len++;
      j /= 10;
    }
    bytes memory bstr = new bytes(len);
    uint k = len - 1;
    while (_i != 0) {
      bstr[k--] = byte(uint8(48 + _i % 10));
      _i /= 10;
    }
    return string(bstr);
  }
}
