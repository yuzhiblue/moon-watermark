///|
/// 标定回归测试：多对照与自标定（v0.1.18）。
/// 数据背景见 `cmd/calibrate`：单对照判据在渐变 / 棋盘 / 色块等结构图型上
/// 存在 ≥0.4 虚警（1024 样本实测 13 例）；多对照（k=8 median）压至 5 例，
/// 自标定显著性检验进一步压至 1 例。本文件固化关键修复样本。

/// 水平渐变 128×128（0→255），标定实验中的虚警图型
fn gradient_image() -> RgbaImage {
  let img = RgbaImage::new(128, 128, 0xFF00_0000)
  for y in 0..<128 {
    for x in 0..<128 {
      let v = (x * 255) / 127
      img.set_pixel(x, y, (0xFF << 24) | (v << 16) | (v << 8) | v)
    }
  }
  img
}

///|
test "multi-control matches single-control on embedded uniform image" {
  let img = RgbaImage::new(128, 128, 0xFFC8_C8C8)
  let cfg = DotConfig::default()
  let _ = img.embed_dots(cfg)
  let c1 = dot_contrast(img, cfg, controls=1)
  let c8 = dot_contrast(img, cfg, controls=8)
  assert_true(c1 > 0.9)
  assert_true(c8 > 0.9)
}

///|
test "multi-control suppresses gradient false positives (seeds 12/39)" {
  let grad = gradient_image()
  // seed=12 单对照 0.444 ≥ 0.4（虚警，保留弱点证据）
  assert_true(
    dot_contrast(grad, DotConfig::new(0.05, 3, 12L, 1.0, 0, 0), controls=1) >= 0.4,
  )
  // 多对照（现行默认）下两枚 seed 均回到阈值以下
  assert_false(verify_dots(grad, DotConfig::new(0.05, 3, 12L, 1.0, 0, 0)))
  assert_false(verify_dots(grad, DotConfig::new(0.05, 3, 39L, 1.0, 0, 0)))
}

///|
test "calibrated verify rejects residual grid-aligned false positive (seed 8)" {
  let grad = gradient_image()
  // seed=8：多对照仍 0.483 ≥ 0.4（目标点位自身偏斜，多对照无法消除）
  assert_true(
    dot_contrast(grad, DotConfig::new(0.05, 3, 8L, 1.0, 0, 0), controls=8) >= 0.4,
  )
  // 自标定显著性检验：0.483 未显著高于本图本底 → 拒判
  assert_false(
    verify_dots(grad, DotConfig::new(0.05, 3, 8L, 1.0, 0, 0), calibrated=true),
  )
}

///|
test "calibrated verify keeps true positive on embedded uniform image" {
  let img = RgbaImage::new(128, 128, 0xFFC8_C8C8)
  let cfg = DotConfig::new(0.05, 3, 777L, 1.0, 0, 0)
  let _ = img.embed_dots(cfg)
  assert_true(verify_dots(img, cfg, calibrated=true))
}

///|
test "calibrated trace locks true seed among adjacent-seed candidates" {
  let img = RgbaImage::new(128, 128, 0xFFC8_C8C8)
  let cfg = DotConfig::new(0.05, 3, 777L, 1.0, 0, 0)
  let _ = img.embed_dots(cfg)
  let candidates = []
  for k in 0..<9 {
    candidates.push(DotConfig::new(0.05, 3, 777L + Int64::from_int(k), 1.0, 0, 0))
  }
  assert_eq(trace_dots(img, candidates, calibrated=true), 0)
}
