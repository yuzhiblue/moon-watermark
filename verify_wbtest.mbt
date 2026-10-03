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
  let _ = img.embed_invisible(Bytes::from_array([b'I', b'D']), key = 7L)
  assert_true(verify_invisible(img, key = 7L))
  assert_true(!verify_invisible(img, key = 8L))
}

///|
test "trace dots finds matching seed" {
  let img = RgbaImage::new(64, 64, 0xFFFF_FFFF)
  let target = DotConfig::default() // seed = 42
  let _ = img.embed_dots(target)
  let cfg1 : DotConfig = { density: 0.05, dot_size: 1, seed: 1L, opacity: 1.0, grid_offset_x: 0, grid_offset_y: 0 }
  let cfg2 : DotConfig = { density: 0.05, dot_size: 1, seed: 2L, opacity: 1.0, grid_offset_x: 0, grid_offset_y: 0 }
  let idx = trace_dots(img, [cfg1, cfg2, target])
  assert_eq(idx, 2)
}

///|
test "trace dots returns -1 when no match" {
  let img = RgbaImage::new(64, 64, 0xFFFF_FFFF)
  let cfg1 : DotConfig = { density: 0.05, dot_size: 1, seed: 1L, opacity: 1.0, grid_offset_x: 0, grid_offset_y: 0 }
  assert_eq(trace_dots(img, [cfg1]), -1)
  assert_eq(trace_dots(img, []), -1)
}
