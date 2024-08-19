// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.0;

/**
 * @title UnorderedMemoryArray
 * @author Lyra
 * @notice util functions for in-memory unordered array operations
 */
library UnorderedMemoryArray {
  /**
   * @dev Add unique element to existing "array" if and increase max index array memory will be updated in place
   * Assumes that the array is not full (i.e. arrayLen < array.length)
   * @param array array of number
   * @param newElement number to check
   * @param arrayLen previously recorded array length with non-zero value
   * @return newArrayLen new length of array
   * @return index index of the added element
   */
  function addUniqueToArray(uint[] memory array, uint newElement, uint arrayLen)
    internal
    pure
    returns (uint newArrayLen, uint index)
  {
    int foundIndex = findInArray(array, newElement, arrayLen);
    if (foundIndex == -1) {
      array[arrayLen] = newElement;
      unchecked {
        return (arrayLen + 1, arrayLen);
      }
    }
    return (arrayLen, uint(foundIndex));
  }

  /**
   * @dev Add unique element to existing "array" if and increase max index array memory will be updated in place
   * Assumes that the array is not full (i.e. arrayLen < array.length)
   * @param array array of address
   * @param newElement address to check
   * @param arrayLen previously recorded array length with non-zero value
   * @return newArrayLen new length of array
   */
  function addUniqueToArray(address[] memory array, address newElement, uint arrayLen)
    internal
    pure
    returns (uint newArrayLen)
  {
    if (findInArray(array, newElement, arrayLen) == -1) {
      unchecked {
        array[arrayLen++] = newElement;
      }
    }
    return arrayLen;
  }

  /**
   * @dev return if a number exists in an array of numbers
   * @param array array of number
   * @param toFind  numbers to find
   * @return index index of the found element. -1 if not found
   */
  function findInArray(uint[] memory array, uint toFind, uint arrayLen) internal pure returns (int index) {
    unchecked {
      for (uint i; i < arrayLen; ++i) {
        if (array[i] == 0) {
          return -1;
        }
        if (array[i] == toFind) {
          return int(i);
        }
      }
      return -1;
    }
  }

  /**
   * @dev return if an address exists in an array of address
   * @param array array of address
   * @param toFind  address to find
   * @return index index of the found element. -1 if not found
   */
  function findInArray(address[] memory array, address toFind, uint arrayLen) internal pure returns (int index) {
    unchecked {
      for (uint i; i < arrayLen; ++i) {
        if (array[i] == address(0)) {
          return -1;
        }
        if (array[i] == toFind) {
          return int(i);
        }
      }
      return -1;
    }
  }

  /**
   * @dev Shorten a memory array length in place. Will produce an invalid result if finalLength > array.length
   */
  function trimArray(uint[] memory array, uint finalLength) internal pure {
    assembly {
      mstore(array, finalLength)
    }
  }

  /**
   * @dev Shorten a memory array length in place. Will produce an invalid result if finalLength > array.length
   */
  function trimArray(address[] memory array, uint finalLength) internal pure {
    assembly {
      mstore(array, finalLength)
    }
  }
}
