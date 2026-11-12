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
///
/// 关键修复（v0.1.19）：原实现直接 `seed.reinterpret_as_uint64()`，导致
/// **相邻小整数种子**（如 1672 / 1679）的 xorshift 早期输出高度相关——
/// 低位异或移位后低 7 位仍由种子的原始低比特决定，使相邻 seed 的点阵落点
/// 大量重叠，`trace_dots` 在噪声下会把 1672 误指向 1679。
///
/// 现先经 **splitmix64 finalizer** 充分扩散（avalanche），相邻整数种子得到
/// 完全独立、不相关的 PRNG 序列与点阵落点，真种子的 contrast 唯一最大、
/// 不会被相邻 seed 抢锁。embed / extract / 对照 seed / null seed 全部经本函数，
/// 两侧一致，可复现。
pub fn seed_to_state(seed : Int64) -> UInt64 {
  let mut z = seed.reinterpret_as_uint64() + 0x9E37_79B9_7F4A_7C15UL
  z = (z ^ (z >> 30)) * 0xBF58_476D_1CE4_E5B9UL
  z = (z ^ (z >> 27)) * 0x94D0_49BB_1331_11EBUL
  z = z ^ (z >> 31)
  if z == 0UL {
    1UL
  } else {
    z
  }
}
