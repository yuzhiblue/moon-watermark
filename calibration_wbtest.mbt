///|
/// 标定回归测试：多对照与自标定（v0.1.18）。
/// 数据背景见 `cmd/calibrate`：单对照判据在渐变 / 棋盘 / 色块等结构图型上
/// 存在 ≥0.4 虚警（1024 样本实测 13 例）；多对照（k=8 median）压至 5 例，
/// 自标定显著性检验进一步压至 1 例。本文件固化关键修复样本。

///|
/// 水平渐变 128×128（0→255），标定实验中的虚警图型
fn gradient_image() -> RgbaImage {
  let img = RgbaImage::new(128, 128, 0xFF00_0000)
  for y in 0..<128 {
    for x in 0..<128 {
      let v = x * 255 / 127
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
/// 渐变图上的候选配置（density/dot_size 与标定实验一致）。
fn grad_cfg(s : Int64) -> DotConfig {
  DotConfig::new(0.05, 3, s, 1.0, 0, 0)
}

///|
test "multi-control suppresses gradient false positives (seed-agnostic)" {
  let grad = gradient_image()
  // 单对照（k=1）在渐变图上仍可能虚警：搜寻一枚「单对照虚警、多对照被压回」
  // 的 seed（v0.1.19：splitmix64 重映射了所有 seed 的落点，故不再写死 12/39，
  // 改为动态定位，仍固化「多对照抑制」这一关键修复）
  let mut fp = 0L
  let mut found = false
  for s in 1..<400 {
    let cs = grad_cfg(Int64::from_int(s))
    let c1 = dot_contrast(grad, cs, controls=1)
    let c8 = dot_contrast(grad, cs, controls=8)
    if c1 >= 0.4 && c8 < 0.4 {
      fp = Int64::from_int(s)
      found = true
      break
    }
  }
  assert_true(found)
  // 单对照虚警存在（弱点证据）
  assert_true(dot_contrast(grad, grad_cfg(fp), controls=1) >= 0.4)
  // 多对照（现行默认）压回阈值以下 → verify_dots 判 false
  assert_false(verify_dots(grad, grad_cfg(fp)))
}

///|
test "calibrated verify rejects residual grid-aligned false positive (seed-agnostic)" {
  let grad = gradient_image()
  // 搜寻一枚「多对照仍虚警（k=8 ≥ 0.4，目标点位自身偏斜）」的 seed，验证
  // 自标定显著性检验将其拒判（v0.1.19：落点重映射后动态定位，不再写死 8）
  let mut fp = 0L
  let mut found = false
  for s in 1..<400 {
    let cs = grad_cfg(Int64::from_int(s))
    if dot_contrast(grad, cs, controls=8) >= 0.4 &&
      !verify_dots(grad, cs, calibrated=true) {
      fp = Int64::from_int(s)
      found = true
      break
    }
  }
  assert_true(found)
  // 多对照仍虚警（证据）
  assert_true(dot_contrast(grad, grad_cfg(fp), controls=8) >= 0.4)
  // 自标定显著性检验：未显著高于本图本底 → 拒判
  assert_false(verify_dots(grad, grad_cfg(fp), calibrated=true))
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
    candidates.push(
      DotConfig::new(0.05, 3, 777L + Int64::from_int(k), 1.0, 0, 0),
    )
  }
  assert_eq(trace_dots(img, candidates, calibrated=true), 0)
}

///|
test "default trace locks true seed 1672 among adjacent seed 1679 (v0.1.19)" {
  // 评委复现样本：相邻小整数种子（1672 / 1679）曾因 xorshift 早期输出相关
  // 导致点阵重叠、默认溯源误指向 1679。splitmix64 混淆 + 默认开启纹理拒绝域
  // 后，真种子 1672 的 contrast 唯一最大，默认（不传 calibrated）即锁定 0。
  let img = RgbaImage::new(128, 128, 0xFFC8_C8C8)
  let target = DotConfig::new(0.05, 3, 1672L, 1.0, 0, 0)
  let _ = img.embed_dots(target)
  let candidates = [
    DotConfig::new(0.05, 3, 1672L, 1.0, 0, 0),
    DotConfig::new(0.05, 3, 1679L, 1.0, 0, 0),
  ]
  assert_eq(trace_dots(img, candidates), 0)
}

///|
test "default trace on jpeg-roundtripped adjacent seeds (v0.1.19)" {
  // JPEG 重压后仍需正确锁定真种子（无损与 JPEG 样本均不得误指）
  let img = RgbaImage::new(128, 128, 0xFFC8_C8C8)
  let target = DotConfig::new(0.05, 3, 1672L, 1.0, 0, 0)
  let _ = img.embed_dots(target)
  match img.encode_jpeg(85) {
    Ok(jpg) =>
      match decode_jpeg(jpg) {
        Ok(back) => {
          let candidates = [
            DotConfig::new(0.05, 3, 1672L, 1.0, 0, 0),
            DotConfig::new(0.05, 3, 1679L, 1.0, 0, 0),
          ]
          assert_eq(trace_dots(back, candidates), 0)
        }
        Err(_) => assert_true(false)
      }
    Err(_) => assert_true(false)
  }
}
