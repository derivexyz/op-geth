//SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.0;

// Libraries
import "src/decimals/SignedDecimalMath.sol";
import "src/decimals/DecimalMath.sol";
import "./FixedPointMathLib.sol";

/**
 * @title SVI
 * @author Lyra
 * @notice Contract to compute the vol for a given strike and set of SVI parameters
 */
library SVI {
  using DecimalMath for uint;
  using SignedDecimalMath for int;
  using FixedPointMathLib for uint;
  using FixedPointMathLib for int;

  error SVI_InvalidParameters();
  error SVI_NoForwardPrice();

  /// @dev Upper bound of of w in SVI
  int internal constant MAX_TOTAL_VAR = 144e18;

  /// @dev scaler used to calculate the upper bound and lower bound of k in SVI
  int internal constant TOTAL_VOL_SCALAR = 4e18;

  /**
   * @dev compute the vol for a given strike and set of SVI parameters
   * @param strike desired strike for which to get vol for, in range [0, inf)
   * @param a SVI parameter in range (-inf, inf)
   * @param b SVI parameter in range [0, inf)
   * @param rho SVI parameter in range (-1, 1)
   * @param m SVI parameter in range (-inf, inf)
   * @param sigma SVI parameter in range (0, inf)
   * @param forwardPrice forward price in range [0, inf)
   * @param tau time to expiry (in years) in range [0, inf)
   * @return vol
   */
  function getVol(uint strike, int a, uint b, int rho, int m, uint sigma, uint forwardPrice, uint64 tau)
    internal
    pure
    returns (uint)
  {
    if (strike == 0) return 0;
    if (forwardPrice == 0) revert SVI_NoForwardPrice();

    // k = ln(strike / fwd) but with some bounds
    int k = getK(strike, a, b, sigma, forwardPrice);
    int k_sub_m = int(k) - m;

    // any number squared is positive, so we can cast to uint
    uint k_sub_m_sq = uint(k_sub_m.multiplyDecimal(k_sub_m)); // (k - m)^2
    uint sigma_sq = sigma.multiplyDecimal(sigma); // sigma^2

    // b * (sqrt((k - m)^2 + sigma^2) + rho * (k - m))
    int bPortion =
      int(b).multiplyDecimal(int(FixedPointMathLib.sqrt(k_sub_m_sq + sigma_sq)) + rho.multiplyDecimal(k_sub_m));

    // a + b * (sqrt((k - m)^2 + sigma^2) + rho * (k - m))
    int w = a + bPortion;

    if (w < 0) {
      revert SVI_InvalidParameters();
    } else if (w > MAX_TOTAL_VAR) {
      w = MAX_TOTAL_VAR;
    }

    // sqrt((a + b * (sqrt((k - m)^2 + sigma^2) + rho * (k - m)))/tau)
    return FixedPointMathLib.sqrt(uint(w).divideDecimal(uint(tau)));
  }

  /**
   * @dev k = ln(strike / fwd), but being bounded by B: -B < k < B
   * where B = TOTAL_VOL_SCALAR x sqrt(a + b * sig)
   */
  function getK(uint strike, int a, uint b, uint sigma, uint forwardPrice) internal pure returns (int k) {
    // calculate the bounds
    int volFactor = int(FixedPointMathLib.sqrt(toUintSafe(a + toIntSafe(b.multiplyDecimal(sigma)))));
    int k_bound = volFactor.multiplyDecimal(TOTAL_VOL_SCALAR);
    int sk = int(strike.divideDecimal(forwardPrice));

    if (sk == 0) return -k_bound;

    // k = ln (strike / fwd)
    k = FixedPointMathLib.ln(sk);

    // make sure -B < k < B
    if (k > k_bound) return k_bound;
    if (k < -k_bound) return -k_bound;
  }

  function toIntSafe(uint value) internal pure returns (int) {
    if (int(value) < 0) revert("SVI: invalid uint cast");
    return int(value);
  }

  function toUintSafe(int value) internal pure returns (uint) {
    if (value < 0) revert("SVI: value must be positive");
    return uint(value);
  }
}
