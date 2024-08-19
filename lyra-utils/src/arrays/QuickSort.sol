// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.0;

/**
 * @title QuickSort
 * @author Lyra
 * @notice using quick-sort to sort memory arrays.
 */
library QuickSort {
  /**
   * @dev Sort both array and return sorted array of indexes
   * The data is not sorted in-memory due to recursion - a new array is returned.
   * E.g. [100, 10, 500] -> sorted indices: [1, 0, 2]
   * @param data array of values to sort
   * @return sortedData new array with sorted data
   * @return sortedIndices array of sorted indices
   */
  function sort(uint[] memory data) internal view returns (uint[] memory sortedData, uint[] memory sortedIndices) {
    sortedIndices = initIndices(data.length);
    sort(data, sortedIndices, int(0), int(data.length - 1));
    return (data, sortedIndices);
  }

  /**
   * @dev Use quicksort to sort array of values and indices
   * Inspired by: https://gist.github.com/subhodi/b3b86cc13ad2636420963e692a4d896f
   * @param arr array of values to sort
   * @param indices array of indices
   * @param left left bound
   * @param right right bound
   */
  function sort(uint[] memory arr, uint[] memory indices, int left, int right) internal view {
    int i = left;
    int j = right;
    if (i == j) {
      return;
    }
    uint pivot = arr[uint(left + (right - left) / 2)];
    while (i <= j) {
      while (arr[uint(i)] < pivot) {
        i++;
      }
      while (pivot < arr[uint(j)]) {
        j--;
      }
      if (i <= j) {
        (arr[uint(i)], arr[uint(j)]) = (arr[uint(j)], arr[uint(i)]);
        (indices[uint(i)], indices[uint(j)]) = (indices[uint(j)], indices[uint(i)]);
        i++;
        j--;
      }
    }
    if (left < j) {
      sort(arr, indices, left, j);
    }
    if (i < right) {
      sort(arr, indices, i, right);
    }
  }

  /**
   * @dev Creates an array of ordered indices, used when beginnin quickSort
   * E.g. with length 3 will generate array: [0, 1, 2]
   * @param length number of values to sort
   * @return initialIndices array of ordered indices
   */
  function initIndices(uint length) internal pure returns (uint[] memory initialIndices) {
    initialIndices = new uint[](length);
    for (uint i; i < length; i++) {
      initialIndices[i] = i;
    }
  }
}
