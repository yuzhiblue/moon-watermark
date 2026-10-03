///|
test "xorshift64 deterministic" {
  assert_eq(xorshift64_next(42UL), xorshift64_next(42UL))
  // 不同状态（大概率）产生不同输出
  assert_true(xorshift64_next(42UL) != xorshift64_next(43UL))
  // 零状态不死循环
  let z = xorshift64_next(0UL)
  assert_true(z != 0UL)
}

///|
test "embed_dots deterministic per seed" {
  // 同一配置、同一底图应产生逐像素一致的输出（用两张独立底图验证）
  let a = RgbaImage::new(64, 64, 0xFFFF_FFFF).embed_dots(DotConfig::default())
  let b = RgbaImage::new(64, 64, 0xFFFF_FFFF).embed_dots(DotConfig::default())
  for y in 0..<64 {
    for x in 0..<64 {
      assert_eq(a.get_pixel(x, y), b.get_pixel(x, y))
    }
  }
}

///|
test "embed_dots paints dark dots" {
  let img = RgbaImage::new(64, 64, 0xFFFF_FFFF)
  let _ = img.embed_dots(DotConfig::default())
  let mut dark = 0
  for y in 0..<64 {
    for x in 0..<64 {
      let p = img.get_pixel(x, y)
      // 深色判定按 RGB 亮度（alpha 恒 255，不计入）
      if ((p >> 24) & 0xFF) < 128 &&
        ((p >> 16) & 0xFF) < 128 &&
        ((p >> 8) & 0xFF) < 128 {
        dark += 1
      }
    }
  }
  assert_true(dark > 0)
}

///|
test "embed_dots different seeds differ" {
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
  let a = RgbaImage::new(64, 64, 0xFFFF_FFFF).embed_dots(cfg1)
  let b = RgbaImage::new(64, 64, 0xFFFF_FFFF).embed_dots(cfg2)
  let mut diff = 0
  for y in 0..<64 {
    for x in 0..<64 {
      if a.get_pixel(x, y) != b.get_pixel(x, y) {
        diff += 1
      }
    }
  }
  assert_true(diff > 0)
}

///|
test "extract_dots high hit rate after embed" {
  let img = RgbaImage::new(64, 64, 0xFFFF_FFFF)
  let cfg = DotConfig::default()
  let _ = img.embed_dots(cfg)
  let rate = extract_dots(img, cfg)
  assert_true(rate >= 0.9)
}

///|
test "extract_dots low hit rate on clean image" {
  let img = RgbaImage::new(64, 64, 0xFFFF_FFFF)
  let cfg = DotConfig::default()
  let rate = extract_dots(img, cfg)
  assert_true(rate < 0.05)
}

///|
test "negative grid offset does not panic (embed + extract)" {
  let img = RgbaImage::new(64, 64, 0xFFFFFFFF)
  let cfg = DotConfig::new(0.05, 3, 42L, 1.0, -3, -2)
  let _ = img.embed_dots(cfg)
  let rate = extract_dots(img, cfg)
  // 负偏移点大部分落在图外，但提取不应崩溃且命中率合理
  assert_true(rate >= 0.0)
}
