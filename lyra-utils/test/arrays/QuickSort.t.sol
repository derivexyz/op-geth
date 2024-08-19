// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.0;

import "forge-std/Test.sol";

import "src/arrays/QuickSort.sol";

/**
 * @dev for current `forge coverage` to work, it needs to call an external contract then invoke internal library
 */
contract QuickSortTester {
  function sort(uint[] memory data) external view returns (uint[] memory, uint[] memory) {
    (uint[] memory sortedData, uint[] memory sortedIndices) = QuickSort.sort(data);
    return (sortedData, sortedIndices);
  }
}

contract QuickSortTest is Test {
  QuickSortTester tester;

  function setUp() public {
    tester = new QuickSortTester();
  }

  function testSortEven() public {
    uint[] memory data = new uint[](6);
    data[0] = 10;
    data[1] = 5;
    data[2] = 3;
    data[3] = 100;
    data[4] = 7;
    data[5] = 1;

    uint[] memory sortedIndices;
    (data, sortedIndices) = tester.sort(data);

    // confirm indices
    assertEq(sortedIndices[0], 5);
    assertEq(sortedIndices[1], 2);
    assertEq(sortedIndices[2], 1);
    assertEq(sortedIndices[3], 4);
    assertEq(sortedIndices[4], 0);
    assertEq(sortedIndices[5], 3);

    // confirm data
    assertEq(data[0], 1);
    assertEq(data[1], 3);
    assertEq(data[2], 5);
    assertEq(data[3], 7);
    assertEq(data[4], 10);
    assertEq(data[5], 100);
  }

  function testSortOdd() public {
    uint[] memory data = new uint[](5);
    data[0] = 567;
    data[1] = 243;
    data[2] = 1;
    data[3] = 0;
    data[4] = 1456;

    uint[] memory sortedIndices;
    (data, sortedIndices) = tester.sort(data);

    // confirm indices
    assertEq(sortedIndices[0], 3);
    assertEq(sortedIndices[1], 2);
    assertEq(sortedIndices[2], 1);
    assertEq(sortedIndices[3], 0);
    assertEq(sortedIndices[4], 4);

    // confirm data
    assertEq(data[0], 0);
    assertEq(data[1], 1);
    assertEq(data[2], 243);
    assertEq(data[3], 567);
    assertEq(data[4], 1456);
  }

  function testSortWithDuplicates() public {
    uint[] memory data = new uint[](4);
    data[0] = 243;
    data[1] = 243;
    data[2] = 1;
    data[3] = 243;

    uint[] memory sortedIndices;
    (data, sortedIndices) = tester.sort(data);

    // confirm indices - duplicates will not be stable
    assertEq(sortedIndices[0], 2);
    assertEq(sortedIndices[1], 3);
    assertEq(sortedIndices[2], 0);
    assertEq(sortedIndices[3], 1);

    // confirm data
    assertEq(data[0], 1);
    assertEq(data[1], 243);
    assertEq(data[2], 243);
    assertEq(data[3], 243);
  }

  // useful for gas estimates for board sorting
  function testWrostCaseGasArrayOf30() public view {
    // using sorted array as this is worst time complexity
    uint[] memory data = new uint[](30);
    for (uint i; i < data.length; i++) {
      data[i] = i;
    }

    tester.sort(data);
  }
}
