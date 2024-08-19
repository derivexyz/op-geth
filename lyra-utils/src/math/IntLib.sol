//SPDX-License-Identifier: GPL-3.0-only

pragma solidity ^0.8.0;

/**
 * @title IntLib
 * @author Lyra
 * @notice util functions for Int
 */
library IntLib {
  /**
   * @notice Returns absolute value.
   * @param amount Positive or negative integer.
   * @return absAmount Absolute value.
   */
  function abs(int amount) internal pure returns (uint absAmount) {
    return amount >= 0 ? uint(amount) : uint(-amount);
  }

  /**
   * @notice Fist takes the absolute value then returns the minimum.
   * @param a First signed integer.
   * @param b Second signed integer.
   * @return absMinAmount Unsigned integer.
   */
  function absMin(int a, int b) internal pure returns (uint absMinAmount) {
    uint absA = abs(a);
    uint absB = abs(b);
    absMinAmount = (absA <= absB) ? absA : absB;
  }

  function min(int a, int b) internal pure returns (int minVal) {
    return a < b ? a : b;
  }

  function max(int a, int b) internal pure returns (int maxVal) {
    return a > b ? a : b;
  }
}
