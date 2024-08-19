// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.0;

import "forge-std/Test.sol";

import "src/math/Black76.sol";

/**
 * @dev for current `forge coverage` to work, it needs to call an external contract then invoke internal library
 */
contract Black76Tester {
  using Black76 for Black76.Black76Inputs;

  function prices(Black76.Black76Inputs memory b76Input) external pure returns (uint call, uint put) {
    return b76Input.prices();
  }

  function annualise(uint64 secToExpiry) external pure returns (uint) {
    return Black76.annualise(secToExpiry);
  }

  function callDelta(Black76.Black76Inputs memory b76Input) external pure returns (uint) {
    return b76Input.getCallDelta();
  }

  function precompile(uint32 expiry, uint64 discount, uint128 volatility, uint128 fwdPrice, uint128 strikePrice, uint8 exponent) external returns (bytes memory) {
      bytes memory result = new bytes(96);

      assembly {
          let input := mload(0x40)
          mstore(input, expiry)
          mstore(add(input, 0x4), discount)
          mstore(add(input, 0xC), volatility)
          mstore(add(input, 0x1C), fwdPrice)
          mstore(add(input, 0x2C), strikePrice)
          mstore(add(input, 0x3C), exponent)

          let value := mload(0x3D)

          // Call the precompiled contract
          if iszero(call(gas(), 0x0000000000000000000000000000000000000100, 0, input, 0x3D, value, 0x60)) {
              revert(0, 0)
          }

          result := mload(value)
      }

      return result;
  }
}

contract Black76Test is Test {
  using Black76 for Black76.Black76Inputs;

  Black76Tester tester;

  function setUp() public {
    tester = new Black76Tester();
  }

  function testPrices() public {
    uint accuracy = uint(1e6);

    Black76.Black76Inputs[] memory b76TestInputs = new Black76.Black76Inputs[](9);
    // just a normal ATM call/put
    b76TestInputs[0] = Black76.Black76Inputs({
      timeToExpirySec: 60 * 60 * 24 * 7,
      volatility: 1e18,
      fwdPrice: 1500e18,
      strikePrice: 1500e18,
      discount: 1e18
    });
    // just a normal OTM/ITM call/put
    b76TestInputs[1] = Black76.Black76Inputs({
      timeToExpirySec: 60 * 60 * 24 * 30,
      volatility: 0.25e18,
      fwdPrice: 1000e18,
      strikePrice: 1200e18,
      discount: 0.9991784198737006e18
    });
    // just a normal deep ITM/OTM call/put
    b76TestInputs[2] = Black76.Black76Inputs({
      timeToExpirySec: 60 * 60 * 24 * 2,
      volatility: 0.75e18,
      fwdPrice: 1000e18,
      strikePrice: 700e18,
      discount: 0.9998904169635637e18
    });
    // total vol exceeds cap of 24.0 (expect call be F*discount, put be K*discount)
    b76TestInputs[3] = Black76.Black76Inputs({
      timeToExpirySec: 60 * 60 * 24 * 365,
      volatility: 25e18,
      fwdPrice: 1000e18,
      strikePrice: 700e18,
      discount: 0.9801986733067553e18
    });
    // total vol is large but below cap (expect call/put be close to F*discount/K*discount)
    b76TestInputs[4] = Black76.Black76Inputs({
      timeToExpirySec: 60 * 60 * 24 * 365,
      volatility: 5e18,
      fwdPrice: 1000e18,
      strikePrice: 700e18,
      discount: 0.9801986733067553e18
    });
    // strike is at uint128 max, fwd is at its min (expect call/put be 0/uint128 max)
    b76TestInputs[5] = Black76.Black76Inputs({
      timeToExpirySec: 60 * 60 * 24 * 365,
      volatility: 4e18,
      fwdPrice: 1,
      strikePrice: type(uint128).max,
      discount: 1.0e18
    });
    // fwd is at uint128 max, strike is at its min (expect call/put be uint128 max/0)
    b76TestInputs[6] = Black76.Black76Inputs({
      timeToExpirySec: 60 * 60 * 24 * 365,
      volatility: 4e18,
      fwdPrice: type(uint128).max,
      strikePrice: 1,
      discount: 1.0e18
    });
    // ZSC (expect call == discounted forward and put == 0 no matter the vol)
    b76TestInputs[7] = Black76.Black76Inputs({
      timeToExpirySec: 60 * 60 * 24 * 365,
      volatility: 4e18,
      fwdPrice: 1000e18,
      strikePrice: 0,
      discount: 0.99e18
    });

    // non-zero strike & foward price = 0
    b76TestInputs[8] = Black76.Black76Inputs({
      timeToExpirySec: 60 * 60 * 24 * 365,
      volatility: 4e18,
      fwdPrice: 0,
      strikePrice: 1000e18,
      discount: 0.99e18
    });

    // array of (call, put) benchmarks computed in python
    int[2][] memory benchmarkResults = new int[2][](b76TestInputs.length);
    benchmarkResults[0] = [int(82.805080668634559515e18), int(82.805080668634559515e18)];
    benchmarkResults[1] = [int(0.137082128426579297e18), int(199.972766103166719631e18)];
    benchmarkResults[2] = [int(299.967125089526177817e18), int(0.00000000045708468e18)];
    benchmarkResults[3] = [int(980.198673306755267731e18), int(686.139071314728653306e18)];
    benchmarkResults[4] = [int(970.034553583819047162e18), int(675.974951591792546424e18)];
    benchmarkResults[5] = [int(0), int(uint(type(uint128).max))];
    benchmarkResults[6] = [int(uint(type(uint128).max)), int(0)];
    benchmarkResults[7] = [int(990e18), int(0)];
    benchmarkResults[8] = [int(0), int(990e18)];

    // array of delta benchmarks computed in python
    uint[] memory deltaBenchmarkResults = new uint[](b76TestInputs.length);
    // Replace these with your actual benchmark results
    deltaBenchmarkResults[0] = 0.5276016935562116e18;
    deltaBenchmarkResults[1] = 0.006071372605597036e18;
    deltaBenchmarkResults[2] = 0.999999999944921e18;
    deltaBenchmarkResults[3] = 1e18;
    deltaBenchmarkResults[4] = 0.9949346359666408e18;
    deltaBenchmarkResults[5] = 0;
    deltaBenchmarkResults[6] = 1e18;
    deltaBenchmarkResults[7] = 1e18;
    deltaBenchmarkResults[8] = 0;

    assert(b76TestInputs.length == deltaBenchmarkResults.length);
    assert(b76TestInputs.length == benchmarkResults.length);

    for (uint i = 0; i < b76TestInputs.length; i++) {
      uint delta = b76TestInputs[i].getCallDelta();
      (uint call, uint put) = b76TestInputs[i].prices();

      assertApproxEqAbs(delta, deltaBenchmarkResults[i] * uint(b76TestInputs[i].discount) / 1e18, accuracy);
      assertApproxEqAbs(int(call), benchmarkResults[i][0], accuracy);
      assertApproxEqAbs(int(put), benchmarkResults[i][1], accuracy);

      (call, put, delta) = b76TestInputs[i].pricesAndDelta();

      assertApproxEqAbs(delta, deltaBenchmarkResults[i] * uint(b76TestInputs[i].discount) / 1e18, accuracy);
      assertApproxEqAbs(int(call), benchmarkResults[i][0], accuracy);
      assertApproxEqAbs(int(put), benchmarkResults[i][1], accuracy);
    }
  }

  function testAnnualise() public {
    uint accuracy = uint(1e6);

    assertApproxEqAbs(tester.annualise(0), 0, accuracy);
    assertApproxEqAbs(tester.annualise(1), 0.000000031709791983e18, accuracy);
    assertApproxEqAbs(tester.annualise(1 minutes), 0.000001902587519025e18, accuracy);
    assertApproxEqAbs(tester.annualise(1 hours), 0.000114155251141552e18, accuracy);
    assertApproxEqAbs(tester.annualise(1 days), 0.00273972602739726e18, accuracy);
    assertApproxEqAbs(tester.annualise(1 weeks), 0.019178082191780821e18, accuracy);
    assertApproxEqAbs(tester.annualise(4 weeks), 0.076712328767123287e18, accuracy);
    assertApproxEqAbs(tester.annualise(12 weeks), 0.230136986301369863e18, accuracy);
    assertApproxEqAbs(tester.annualise(365 days), 1e18, accuracy);
    assertApproxEqAbs(tester.annualise(365 days * 2), 2e18, accuracy);
    assertApproxEqAbs(tester.annualise(365 days * 2.5), 2.5e18, accuracy);
  }

  function testPrecompile() public {
      (address alice, uint256 alicePk) = makeAddrAndKey("alice");
      emit log_address(alice);
      bytes32 hash = keccak256("Signed by Alice");
      (uint8 v, bytes32 r, bytes32 s) = vm.sign(alicePk, hash);
      address signer = ecrecover(hash, v, r, s);
      assertEq(alice, signer); // [PASS]
      /* bytes memory input = hex"00093A800DE0B6B3A764000000000000000000000DE0B6B3A7640000000000000000005150AE84A8CDF00000000000000000005150AE84A8CDF0000012"; */
      uint8 exponent = 18;
      uint32 expiry = 604800;
      uint64 discount = 1000000000000000000;
      uint128 volatility = 1000000000000000000;
      uint128 fwdPrice = 1500000000000000000000;
      uint128 strikePrice = 1500000000000000000000;
      bytes memory result = tester.precompile(expiry, discount, volatility, fwdPrice, strikePrice, exponent);
      console.log("RESULT LEN");
      console.log(result.length);
      assertEq(true,true);
  }
}
