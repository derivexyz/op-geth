package lyraprecompiles

import (
	"errors"
	"fmt"
	"math"
	"math/big"

	"gonum.org/v1/gonum/stat/distuv"
)

type Black76 struct{}
 
func (c *Black76) RequiredGas(input []byte) uint64 {
    return uint64(300)
}

const minExponent int64 = 32
 
var (
    errBlack76InvalidInputLength = errors.New("invalid input length")
	bigMinExponent = big.NewInt(minExponent)
	decimalPrecision = new(big.Int).Exp(big.NewInt(10), bigMinExponent, nil)
	floatPrecision = new(big.Float).SetInt(decimalPrecision)
	zero = big.NewInt(0)
	one = big.NewInt(1)
)

func (c *Black76) Run(input []byte) ([]byte, error) {
	defer func() {
		if err := recover(); err != nil {
			fmt.Println("Black 76 panicked", err)
		}
	}()

	// fmt.Println("RECEIVED INPUT OF LEN", len(input))
	if len(input) > 61 {
		input = input[4:]
	}
	if len(input) != 61 {
        return nil, errBlack76InvalidInputLength
	}
	output := make([]byte, 96)

	var (
		timeToExpirySec = new(big.Int).SetBytes(input[:4])
		discount = new(big.Int).SetBytes(input[4:12])
		volatility = new(big.Int).SetBytes(input[12:28])
		fwdPrice = new(big.Int).SetBytes(input[28:44])
		strikePrice = new(big.Int).SetBytes(input[44:60])
		exponent = new(big.Int).SetBytes(input[60:61])
	)

	expCmp := exponent.Cmp(bigMinExponent)
	if expCmp > 0 {
		decimalPrecision = new(big.Int).Exp(big.NewInt(10), exponent, nil)
		floatPrecision = new(big.Float).SetInt(decimalPrecision)
	} else if expCmp < 0 {
		expDiff := new(big.Int).Sub(bigMinExponent, exponent)
		diffMultiplier := new(big.Int).Exp(big.NewInt(10), expDiff, nil)
		discount = new(big.Int).Mul(discount, diffMultiplier)
		volatility = new(big.Int).Mul(volatility, diffMultiplier)
		fwdPrice = new(big.Int).Mul(fwdPrice, diffMultiplier)
		strikePrice = new(big.Int).Mul(strikePrice, diffMultiplier)
	}

	tAnnualised := annualise(timeToExpirySec)

	annualisedSqrt := new(big.Int).Mul(new(big.Int).Sqrt(tAnnualised), new(big.Int).Sqrt(decimalPrecision))
	totalVol := new(big.Int).Div(new(big.Int).Mul(volatility, annualisedSqrt), decimalPrecision)
	fwdDiscounted := new(big.Int).Div(new(big.Int).Mul(fwdPrice, discount), decimalPrecision)
	if strikePrice.Cmp(zero) == 0 {
		if expCmp < 0 {
			expDiff := new(big.Int).Sub(bigMinExponent, exponent)
			diffMultiplier := new(big.Int).Exp(big.NewInt(10), expDiff, nil)
			fwdDiscounted = new(big.Int).Div(fwdDiscounted, diffMultiplier)
			discount = new(big.Int).Div(discount, diffMultiplier)
		}
		// fmt.Printf("Call - %s | Put - %s | Delta - %s\n", new(big.Float).SetInt(fwdDiscounted).String(), "0", new(big.Float).SetInt(discount).String())
		fwdDiscounted.FillBytes(output[0:32])
		zero.FillBytes(output[32:64])
		discount.FillBytes(output[64:96])
		return output, nil
	}

	strikeDiscounted := new(big.Int).Div(new(big.Int).Mul(strikePrice, discount), decimalPrecision)
	if fwdPrice.Cmp(zero) == 0 {
		if expCmp < 0 {
			expDiff := new(big.Int).Sub(bigMinExponent, exponent)
			diffMultiplier := new(big.Int).Exp(big.NewInt(10), expDiff, nil)
			strikeDiscounted = new(big.Int).Div(strikeDiscounted, diffMultiplier)
		}
		// fmt.Printf("Call - %s | Put - %s | Delta - %s\n", "0", new(big.Float).SetInt(strikeDiscounted).String(), "0")
		zero.FillBytes(output[0:32])
		strikeDiscounted.FillBytes(output[32:64])
		zero.FillBytes(output[64:96])
		return output, nil
	}

	moneyness := new(big.Int).Div(new(big.Int).Mul(strikePrice, decimalPrecision), fwdPrice)

	stdCallPrice, stdCallDelta := standardCall(moneyness, totalVol)

	stdPutPrice := new(big.Int).Add(stdCallPrice, moneyness)
	if stdPutPrice.Cmp(decimalPrecision) >= 0 {
		stdPutPrice = new(big.Int).Sub(stdPutPrice, decimalPrecision)
	} else {
		stdPutPrice = zero
	}

	stdCallPrice = new(big.Int).Div(new(big.Int).Mul(stdCallPrice, fwdDiscounted), decimalPrecision)
	stdPutPrice = new(big.Int).Div(new(big.Int).Mul(stdPutPrice, fwdDiscounted), decimalPrecision)
	stdCallDelta = new(big.Int).Div(new(big.Int).Mul(stdCallDelta, discount), decimalPrecision)

	if stdCallPrice.Cmp(fwdDiscounted) > 0 {
		stdCallPrice = fwdDiscounted
	}
	if stdPutPrice.Cmp(strikeDiscounted) > 0 {
		stdPutPrice = strikeDiscounted
	}

	if expCmp < 0 {
		expDiff := new(big.Int).Sub(bigMinExponent, exponent)
		diffMultiplier := new(big.Int).Exp(big.NewInt(10), expDiff, nil)
		stdCallPrice = new(big.Int).Div(stdCallPrice, diffMultiplier)
		stdPutPrice = new(big.Int).Div(stdPutPrice, diffMultiplier)
		stdCallDelta = new(big.Int).Div(stdCallDelta, diffMultiplier)
	}

	// fmt.Printf("Call - %s | Put - %s | Delta - %s\n", new(big.Float).SetInt(stdCallPrice).String(), new(big.Float).SetInt(stdPutPrice).String(), new(big.Float).SetInt(stdCallDelta).String())
	stdCallPrice.FillBytes(output[0:32])
	stdPutPrice.FillBytes(output[32:64])
	stdCallDelta.FillBytes(output[64:96])
    return output, nil
}

func getNormalFloat(number *big.Int) float64 {
	res, _ := new(big.Float).Quo(new(big.Float).SetInt(number), floatPrecision).Float64()
	return res
}

func getBigInt(number float64) *big.Int {
	res := new(big.Int)
	new(big.Float).Mul(new(big.Float).SetFloat64(number), floatPrecision).Int(res)

	return res
}

func annualise(seconds *big.Int) *big.Int {
	var secondsPerYear = big.NewInt(365 * 24 * 60 * 60)

	return new(big.Int).Div(new(big.Int).Mul(seconds, decimalPrecision), secondsPerYear)
}

func standardCall(moneyness *big.Int, totalVol *big.Int) (*big.Int, *big.Int) {
	var maxTotalVol = new(big.Int).Mul(big.NewInt(24), decimalPrecision)

	if totalVol.Cmp(maxTotalVol) >= 0 {
		return decimalPrecision, decimalPrecision
	}

	stdVol, stdMoneyness := totalVol, moneyness
	if totalVol.Cmp(zero) == 0 {
		stdVol = one
	}
	if moneyness.Cmp(zero) == 0 {
		stdMoneyness = one
	}

	k := getBigInt(math.Log(getNormalFloat(stdMoneyness)))
	halfV2t := new(big.Int).Div(new(big.Int).Mul(new(big.Int).Rsh(stdVol, 1), stdVol), decimalPrecision)

	d1 := new(big.Int).Div(new(big.Int).Mul(new(big.Int).Sub(halfV2t, k), decimalPrecision), stdVol)
	d2 := new(big.Int).Sub(d1, stdVol)

	// CDF calculations
	dist := distuv.Normal{
		Mu:    0,
		Sigma: 1,
	}
	d1 = getBigInt(dist.CDF(getNormalFloat(d1)))
	d2 = getBigInt(dist.CDF(getNormalFloat(d2)))
	d2 = new(big.Int).Div(new(big.Int).Mul(stdMoneyness, d2), decimalPrecision)

	res1 := big.NewInt(0)
	if d1.Cmp(d2) >= 0 {
		res1 = new(big.Int).Sub(d1, d2)
	}
	return res1, d1
}

