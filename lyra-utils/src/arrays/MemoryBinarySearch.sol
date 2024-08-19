// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.0;

/**
 * @title MemoryBinarySearch
 * @author Lyra
 * @notice Binary search utilities for memory arrays.
 * Close copy of OZ/Arrays.sol storage binary search.
 */
library MemoryBinarySearch {
  /**
   * @dev Searches a sorted `array` and returns the first index that contains
   * a value greater or equal to `element`. If no such index exists (i.e. all
   * values in the array are strictly less than `element`), the array length is
   * returned. Time complexity O(log n).
   *
   * `array` is expected to be sorted in ascending order, and to contain no
   * repeated elements.
   */
  function findUpperBound(uint[] memory array, uint element) internal pure returns (uint) {
    if (array.length == 0) {
      return 0;
    }

    uint low = 0;
    uint high = array.length;

    while (low < high) {
      uint mid = (low + high) / 2;

      // Note that mid will always be strictly less than high (i.e. it will be a valid array index)
      // because `(low + high) / 2` rounds down.
      if (array[mid] > element) {
        high = mid;
      } else {
        low = mid + 1;
      }
    }

    // At this point `low` is the exclusive upper bound. We will return the inclusive upper bound.
    if (low > 0 && array[low - 1] == element) {
      return low - 1;
    } else {
      return low;
    }
  }
}
