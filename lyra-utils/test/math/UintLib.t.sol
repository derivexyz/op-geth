// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.0;

import "forge-std/Test.sol";

import "src/math/UintLib.sol";

/**
 * @dev for current `forge coverage` to work, it needs to call an external contract then invoke internal library
 */
contract UintLibTester {
  function min(uint a, uint b) external pure returns (uint) {
    uint res = UintLib.min(a, b);
    return res;
  }

  function max(uint a, uint b) external pure returns (uint) {
    uint res = UintLib.max(a, b);
    return res;
  }
}

contract UintLibTest is Test {
  UintLibTester tester;

  function setUp() public {
    tester = new UintLibTester();
  }

  function testMin() public {
    assertEq(tester.min(0, type(uint).max), 0);
    assertEq(tester.min(10, 1000), 10);
    assertEq(tester.min(1000, 10), 10);
    assertEq(tester.min(type(uint).max, 0), 0);
  }

  function testMax() public {
    assertEq(tester.max(0, type(uint).max), type(uint).max);
    assertEq(tester.max(10, 1000), 1000);
    assertEq(tester.max(1000, 10), 1000);
    assertEq(tester.max(type(uint).max, 0), type(uint).max);
  }
}
