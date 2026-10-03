///|
/// 确定性 64 位 PRNG（xorshift64）。
///
/// 相同种子产生完全相同序列，保证点阵水印可复现、可提取；
/// 种子 0 会被替换为 1，避免全零状态死循环。
pub fn xorshift64_next(state : UInt64) -> UInt64 {
  let mut x = if state == 0UL { 1UL } else { state }
  x = x ^ (x << 13)
  x = x ^ (x >> 7)
  x = x ^ (x << 17)
  x
}

///|
/// 将 `seed`（Int64）转换为 PRNG 初始状态。
pub fn seed_to_state(seed : Int64) -> UInt64 {
  seed.reinterpret_as_uint64()
}
