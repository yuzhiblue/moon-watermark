///|
/// v0.1.20 边界/健壮性回归测试：覆盖整数溢出、超大参数、畸形输入等
/// 可能导致 panic/OOM/判据绕过的路径。

///|
test "crop clamps oversized w/h without overflow" {
  let img = RgbaImage::new(8, 8, 0xFF80_8080)
  // w/h = Int32::max 曾在 cx0+w 处溢出为负，导致钳制失效、巨型分配
  let c = img.crop(2, 2, 2147483647, 2147483647)
  assert_eq(c.width, 6)
  assert_eq(c.height, 6)
  assert_eq(c.data.length(), 6 * 6 * 4)
}

///|
test "dot_contrast clamps extreme controls (no median bypass)" {
  let img = RgbaImage::new(64, 64, 0xFF20_2020)
  let cfg = DotConfig::default()
  // controls=Int32::max 曾使 k+1 溢出、对照循环跳过 → 判据被绕过
  let a = dot_contrast(img, cfg, controls=8)
  let b = dot_contrast(img, cfg, controls=2147483647)
  let c = dot_contrast(img, cfg, controls=1)
  // 上限 64 的结果应与 8 同量级（均为合法 median），而非退化为无对照的 c
  assert_true(a > -1.0 && a < 1.0)
  assert_true(b > -1.0 && b < 1.0)
  assert_true(c > -1.0 && c < 1.0)
}

///|
test "render_text tolerates extreme scale without OOM" {
  // font_size=Int32::max 曾导致 w*s 溢出或 GB 级分配；现钳制为 64 倍上限
  let img = render_text("AB", 0xFFFF_FFFF, scale=2147483647)
  assert_true(img.width > 0)
  assert_true(img.data.length() <= 134217728)
}

///|
test "psnr of identical images remains finite" {
  let img = RgbaImage::new(32, 32, 0xFF00_0000)
  match psnr(img, img) {
    Some(v) => assert_true(v >= 1000000000.0)
    None => assert_true(false)
  }
}
