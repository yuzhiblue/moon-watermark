///|
test "verify dots true after embed" {
  let img = RgbaImage::new(64, 64, 0xFFFF_FFFF)
  let cfg = DotConfig::default()
  let _ = img.embed_dots(cfg)
  assert_true(verify_dots(img, cfg))
}

///|
test "verify dots false on clean image" {
  let img = RgbaImage::new(64, 64, 0xFFFF_FFFF)
  let cfg = DotConfig::default()
  assert_true(!verify_dots(img, cfg))
}

///|
test "verify invisible true after embed" {
  let img = RgbaImage::new(32, 32, 0xFFFF_FFFF)
  let _ = img.embed_invisible(Bytes::from_array([b'I', b'D']), key=7L)
  assert_true(verify_invisible(img, key=7L))
  assert_true(!verify_invisible(img, key=8L))
}

///|
test "trace dots finds matching seed" {
  let img = RgbaImage::new(64, 64, 0xFFFF_FFFF)
  let target = DotConfig::default() // seed = 42
  let _ = img.embed_dots(target)
  let cfg1 : DotConfig = {
    density: 0.05,
    dot_size: 1,
    seed: 1L,
    opacity: 1.0,
    grid_offset_x: 0,
    grid_offset_y: 0,
  }
  let cfg2 : DotConfig = {
    density: 0.05,
    dot_size: 1,
    seed: 2L,
    opacity: 1.0,
    grid_offset_x: 0,
    grid_offset_y: 0,
  }
  let idx = trace_dots(img, [cfg1, cfg2, target])
  assert_eq(idx, 2)
}

///|
test "trace dots returns -1 when no match" {
  let img = RgbaImage::new(64, 64, 0xFFFF_FFFF)
  let cfg1 : DotConfig = {
    density: 0.05,
    dot_size: 1,
    seed: 1L,
    opacity: 1.0,
    grid_offset_x: 0,
    grid_offset_y: 0,
  }
  assert_eq(trace_dots(img, [cfg1]), -1)
  assert_eq(trace_dots(img, []), -1)
}

///|
test "dark original image is not false positive (v0.1.15)" {
  // 回归：绝对命中率在暗色原图上天然≈1（假阳性）。
  // 成对对照（目标命中率−对照命中率）应自动扣除原图暗区干扰。
  let black = RgbaImage::new(64, 64, 0xFF00_0000)
  let cfg = DotConfig::default()
  assert_true(!verify_dots(black, cfg))
  // 亮暗混合纹理（20 暗 / 150 亮）同样不应误报
  let tex = RgbaImage::new(64, 64, 0xFF40_4040)
  let mut st = 42L
  for i in 0..<4096 {
    st = st * 6364136223846793005L + 1442695040888963407L
    let v = if ((st >> 33) & 1) == 1 { 20 } else { 150 }
    tex.set_pixel(i % 64, i / 64, (0xFF << 24) | (v << 16) | (v << 8) | v)
  }
  assert_true(!verify_dots(tex, cfg))
  // 暗纹理原图 trace 应返回 -1（未嵌入），此前会误锁某个候选
  let c1 : DotConfig = {
    density: 0.05, dot_size: 3, seed: 41L, opacity: 1.0, grid_offset_x: 0, grid_offset_y: 0,
  }
  let c2 : DotConfig = {
    density: 0.05, dot_size: 3, seed: 42L, opacity: 1.0, grid_offset_x: 0, grid_offset_y: 0,
  }
  assert_eq(trace_dots(tex, [c1, c2]), -1)
}

///|
test "embed produces positive contrast and unique trace (v0.1.15)" {
  // 亮底图嵌入后：目标点位命中率显著高于对照点位 → contrast 接近 1
  let img = RgbaImage::new(64, 64, 0xFF80_8080)
  let cfg = DotConfig::new(0.05, 3, 42L, 1.0, 0, 0)
  let _ = img.embed_dots(cfg)
  let contrast = dot_contrast(img, cfg)
  assert_true(contrast >= 0.5)
  assert_true(verify_dots(img, cfg))
  // 错误 seed 的 contrast 应显著更低（候选歧义被 contrast 区分）
  let wrong = DotConfig::new(0.05, 3, 43L, 1.0, 0, 0)
  assert_true(dot_contrast(img, wrong) < 0.3)
}

///|
test "trace dots reports ambiguity via -2 (v0.1.15)" {
  // 两候选信号相同（不可区分）→ 最高−次高 < margin → 返回 -2 而非误锁
  let img = RgbaImage::new(64, 64, 0xFF80_8080)
  let cfg = DotConfig::new(0.05, 3, 42L, 1.0, 0, 0)
  let _ = img.embed_dots(cfg)
  assert_eq(trace_dots(img, [cfg, cfg]), -2)
}
