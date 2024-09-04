use num_bigfloat::BigFloat;

pub const ZERO_BYTES: [u8; 16] = (0 as u128).to_be_bytes();

pub fn f64_to_bytes(input: f64, exponent: i8) -> [u8; 16] {
    let mult = BigFloat::from_u8(10).pow(&BigFloat::from_i8(exponent));
    let val = BigFloat::from_f64(input).mul(&mult).to_u128().unwrap_or(u128::MAX);
    val.to_be_bytes()
}
