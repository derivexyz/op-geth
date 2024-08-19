//SPDX-License-Identifier: GPL-3.0-only

pragma solidity ^0.8.0;

/**
 * @title UintLib
 * @author Lyra
 * @notice util functions for uint
 */
library UintLib {
  function min(uint a, uint b) internal pure returns (uint minVal) {
    return a < b ? a : b;
  }

  function max(uint a, uint b) internal pure returns (uint maxVal) {
    return a > b ? a : b;
  }
}
