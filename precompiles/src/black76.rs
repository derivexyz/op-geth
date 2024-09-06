use num_bigfloat::BigFloat;
use statrs::function::erf::erf;
use core::slice;

use crate::{utils, Error, Result};

const FRAC_1_SQRT_PI: f64 = 0.564189583547756286948079451560772586_f64;
const FRAC_1_SQRT_2_PI: f64 = FRAC_1_SQRT_PI * std::f64::consts::FRAC_1_SQRT_2;
const SEC_PER_YEAR: f64 = 365.0 * 24.0 * 60.0 * 60.0;
const BLACK76_GAS: u64 = 300;

#[no_mangle]
pub extern "C" fn __precompile_black76_gas(_data_ptr: *const u8, _data_len: usize) -> u64 {
    BLACK76_GAS
}

#[no_mangle]
#[allow(clippy::not_unsafe_ptr_arg_deref)]
pub extern "C" fn __precompile_black76(
    data_ptr: *const u8,
    data_len: usize,
    ret_val: *mut u8,
    ret_len: *mut usize,
) -> u8 {
    let data = unsafe { slice::from_raw_parts(data_ptr, data_len) };

    match compute(data) {
        Ok(v) => {
            let ret = unsafe { slice::from_raw_parts_mut(ret_val, v.len()) };
            ret.copy_from_slice(&v);
            unsafe {
                *ret_len = v.len();
            };
            0
        },
        Err(e) => e.code(),
    }
}

pub fn normcdf(x: f64) -> f64 {
    0.5 * (1.0 + erf(x * std::f64::consts::FRAC_1_SQRT_2))
}

pub fn normpdf(x: f64) -> f64 {
    (-0.5 * x.powi(2)).exp() * FRAC_1_SQRT_2_PI
}

fn d1(sigma: f64, strike: f64, fwd: f64, tau: f64) -> f64 {
    (-f64::ln(strike / fwd) + (0.5 * sigma.powi(2)) * tau) / (sigma * tau.sqrt())
}

fn d2(d1: f64, sigma: f64, tau: f64) -> f64 {
    d1 - sigma * tau.sqrt()
}

#[derive(Debug, Clone)]
pub struct Black76 {
    pub strike: f64,
    pub expiry_sec: f64,
    pub is_call: bool,
}

impl Black76 {
    pub fn price_expired(&self, fwd: f64) -> f64 {
        if self.is_call {
            (fwd - self.strike).max(0.0)
        } else {
            (self.strike - fwd).max(0.0)
        }
    }

    pub fn price(&self, fwd: f64, vol: f64) -> f64 {
        let tau = self.expiry_sec / SEC_PER_YEAR;
        if tau <= 0.0 {
            return self.price_expired(fwd);
        }

        let d1 = d1(vol, self.strike, fwd, tau);
        let d2 = d2(d1, vol, tau);
        let price = if self.is_call {
            fwd * normcdf(d1) - self.strike * normcdf(d2)
        } else {
            self.strike * normcdf(-d2) - fwd * normcdf(-d1)
        };
        price
    }

    pub fn delta(&self, fwd: f64, vol: f64) -> f64 {
        let tau = self.expiry_sec / SEC_PER_YEAR;
        if tau <= 0.0 {
            return 0.0;
        }
        let d1 = d1(vol, self.strike, fwd, tau);
        if self.is_call {
            normcdf(d1)
        } else {
            normcdf(d1) - 1.0
        }
    }
}

fn extract_arguments(args: &[u8]) -> (i8, f64, f64, f64, f64, f64) {
    let exponent = i8::from_be_bytes(args[60..].try_into().unwrap());
    let multiplier = BigFloat::from_u8(10).pow(&BigFloat::from_i8(-exponent));
    let expiry_sec = u32::from_be_bytes(args[..4].try_into().unwrap());
    let expiry_sec = BigFloat::from_u32(expiry_sec).to_f64();
    let discount = u64::from_be_bytes(args[4..12].try_into().unwrap());
    let discount = BigFloat::from_u64(discount).mul(&multiplier).to_f64();
    let vol = u128::from_be_bytes(args[12..28].try_into().unwrap());
    let vol = BigFloat::from_u128(vol).mul(&multiplier).to_f64();
    let fwd = u128::from_be_bytes(args[28..44].try_into().unwrap());
    let fwd = BigFloat::from_u128(fwd).mul(&multiplier).to_f64();
    let strike = u128::from_be_bytes(args[44..60].try_into().unwrap());
    let strike = BigFloat::from_u128(strike).mul(&multiplier).to_f64();
    (exponent, expiry_sec, discount, vol, fwd, strike)
}

fn calculate_black76(args: &[u8]) -> Result<([u8; 16], [u8; 16], [u8; 16])> {
    if args.len() != 61 {
        return Err(Error::WrongLengthOfArguments);
    }

    let (exponent, expiry_sec, discount, vol, fwd, strike) = extract_arguments(args);
    // println!("EXPONENT {} | EXPIRY_SEC {} | DISCOUNT {} | VOL {} | FWD {} | STRIKE {}", exponent, expiry_sec, discount, vol, fwd, strike);

    let fwd_discounted = fwd * discount;
    if strike <= 0.0 {
        return Ok((
            utils::f64_to_bytes(fwd_discounted, exponent),
            utils::ZERO_BYTES,
            utils::f64_to_bytes(discount, exponent),
        ));
    }

    let strike_discounted = strike * discount;
    if fwd <= 0.0 {
        return Ok((
            utils::ZERO_BYTES,
            utils::f64_to_bytes(strike_discounted, exponent),
            utils::ZERO_BYTES,
        ));
    }

    let mut black76 = Black76 {
        strike,
        expiry_sec,
        is_call: true,
    };

    let call_price = black76.price(fwd, vol);
    let call_delta = black76.delta(fwd, vol);
    black76.is_call = false;
    let put_price = black76.price(fwd, vol);

    // let call_price = call_price * fwd_discounted;
    // let put_price = put_price * fwd_discounted;
    let call_delta = call_delta * discount;

    let call_price = if call_price > fwd_discounted {
        fwd_discounted
    } else {
        call_price
    };
    let put_price = if put_price > strike_discounted {
        strike_discounted
    } else {
        put_price
    };

    Ok((
        utils::f64_to_bytes(call_price, exponent),
        utils::f64_to_bytes(put_price, exponent),
        utils::f64_to_bytes(call_delta, exponent),
    ))
}

fn prices_delta(args: &[u8]) -> Result<Vec<u8>> {
    let (call_price, put_price, call_delta) = calculate_black76(args)?;
    let mut res = call_price.to_vec();
    res.extend_from_slice(&put_price);
    res.extend_from_slice(&call_delta);

    Ok(res)
}

fn prices(args: &[u8]) -> Result<Vec<u8>> {
    let (call_price, put_price, _) = calculate_black76(args)?;
    let mut res = call_price.to_vec();
    res.extend_from_slice(&put_price);

    Ok(res)
}

fn delta(args: &[u8]) -> Result<Vec<u8>> {
    let (_, _, call_delta) = calculate_black76(args)?;
    let res = call_delta.to_vec();

    Ok(res)
}

// prices_delta(uint32,uint64,uint128,uint128,uint128,int8)(uint128,uint128,uint128) 0x5f53183d
pub const BLACK76_PRICES_DELTA_SELECTOR: [u8; 4] = [0x5f, 0x53, 0x18, 0x3d];
// prices(uint32,uint64,uint128,uint128,uint128,int8)(uint128,uint128) 0x10251f08
pub const BLACK76_PRICES_SELECTOR: [u8; 4] = [0x10, 0x25, 0x1f, 0x08];
// delta(uint32,uint64,uint128,uint128,uint128,int8)(uint128) 0x129ab31e
pub const BLACK76_DELTA_SELECTOR: [u8; 4] = [0x12, 0x9a, 0xb3, 0x1e];

pub fn compute(data: &[u8]) -> Result<Vec<u8>> {
    if data.len() < 4 {
        return Err(Error::WrongSelectorLength);
    }
    match [data[0], data[1], data[2], data[3]] {
        BLACK76_PRICES_DELTA_SELECTOR => prices_delta(&data[4..]),
        BLACK76_PRICES_SELECTOR => prices(&data[4..]),
        BLACK76_DELTA_SELECTOR => delta(&data[4..]),
        _ => return Err(Error::UnknownSelector),
    }
}
