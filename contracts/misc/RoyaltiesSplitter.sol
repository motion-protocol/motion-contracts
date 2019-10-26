/**
 * Copyright (c) 2018-present, Leap DAO (leapdao.org)
 *
 * This source code is licensed under the Mozilla Public License, version 2,
 * found in the LICENSE file in the root directory of this source tree.
 */
pragma solidity 0.5.2;

import "openzeppelin-solidity/contracts/token/ERC20/IERC20.sol";
import "../IERC1948.sol";

contract RoyaltiesSplitter {

  address constant RIGHTS_REGISTRY = 0x1231111111111111111111111111111111111123;

  function _sort(uint256[] memory data) internal pure returns(uint256[] memory) {
    // only sort player hands
    if (data.length > 1) {
      _quickSort(data, int(0), int(data.length - 1));
    }
    return data;
  }

  function _quickSort(uint256[] memory arr, int left, int right) internal pure {
    int i = left;
    int j = right;
    if (i==j) return;
    uint pivot = arr[uint(left + (right - left) / 2)];
    while (i <= j) {
      while (arr[uint(i)] < pivot) i++;
      while (pivot < arr[uint(j)]) j--;
      if (i <= j) {
        (arr[uint(i)], arr[uint(j)]) = (arr[uint(j)], arr[uint(i)]);
        i++;
        j--;
      }
    }
    if (left < j)
      _quickSort(arr, left, j);
    if (i < right)
      _quickSort(arr, i, right);
  }

  function sortAndHash(address[] memory _addr, uint256[] memory _amount) public view returns (bytes32) {
    require(_addr.length == _amount.length, "unequal length");
    uint256[] memory rightsholders = new uint256[](_addr.length);
    for (uint256 i = 0; i < _addr.length; i++) {
      rightsholders[i] = _pack(_addr[i], _amount[i]);
    }
    return keccak256(abi.encode(_sort(rightsholders)));
  }

  function _pack(address _addr, uint256 _share) internal pure returns (uint256) {
    return (uint256(uint160(_addr)) << 96) | uint256(uint96(_share));
  }

  function _unpack(uint256 _packed) internal pure returns (address addr, uint256 amount) {
    addr = address(uint160(_packed >> 96));
    amount = uint256(uint32(_packed));
  }

  function split(
    uint256 rightId,
    uint256[] memory _rightsholders
  ) public {
    // todo
  }

  function addOwner(
    uint256 rightId,
    uint256[] memory _rightsholders,
    address _newAddr,
    uint32 _newAmount
  ) public {
    
    // check cards
    uint256[] memory sorted = _sort(_rightsholders);
    bytes32 hash = keccak256(abi.encode(sorted));

    IERC1948 registry = IERC1948(RIGHTS_REGISTRY);
    require(hash == registry.readData(rightId), "hash doesn't match");

    uint256[] memory newHolders = new uint256[](sorted.length + 1);
    // todo: run through it and insert at right spot
    for (uint256 i = 0; i <= sorted.length; i++) {
      if (i == sorted.length) {
        newHolders[i] = _pack(_newAddr, _newAmount);
      } else {
        newHolders[i] = sorted[i];  
      }
    }
    registry.writeData(rightId, keccak256(abi.encode(newHolders)));
  }

}