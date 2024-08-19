// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.0;

import "forge-std/Test.sol";

import "src/arrays/MemoryBinarySearch.sol";

/**
 * @dev for current `forge coverage` to work, it needs to call an external contract then invoke internal library
 */
contract MemoryBinarySearchTester {
  function findUpperBound(uint[] memory array, uint element) external pure returns (uint index) {
    uint res = MemoryBinarySearch.findUpperBound(array, element);
    return res;
  }
}

contract MemoryBinarySearchTest is Test {
  MemoryBinarySearchTester tester;

  function setUp() public {
    tester = new MemoryBinarySearchTester();
  }

  function testEdgeCases() public {
    uint[] memory orderedArray = new uint[](6);
    orderedArray[0] = 1006;
    orderedArray[1] = 2045;
    orderedArray[2] = 100045;
    orderedArray[3] = 132340;
    orderedArray[4] = 1e10;
    orderedArray[5] = 123e18;

    // test value below range
    uint index = tester.findUpperBound(orderedArray, 100);
    assertEq(index, 0);

    // test value above range
    index = tester.findUpperBound(orderedArray, 125e18);
    assertEq(index, 6);

    // test find exact value
    index = tester.findUpperBound(orderedArray, 100045);
    assertEq(index, 2);
  }

  function testSeveralExamples() public {
    uint[] memory orderedArray = new uint[](7);
    orderedArray[0] = 0;
    orderedArray[1] = 1;
    orderedArray[2] = 10;
    orderedArray[3] = 154;
    orderedArray[4] = 2645;
    orderedArray[5] = 12e18;
    orderedArray[6] = 12.34e18;

    uint index = tester.findUpperBound(orderedArray, 150);
    assertEq(index, 3);

    index = tester.findUpperBound(orderedArray, 9);
    assertEq(index, 2);

    index = tester.findUpperBound(orderedArray, 12.1e18);
    assertEq(index, 6);

    index = tester.findUpperBound(orderedArray, 200);
    assertEq(index, 4);
  }
}
