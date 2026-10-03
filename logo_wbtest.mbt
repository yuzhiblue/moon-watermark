///|
test "embed_logo overlays at position" {
  let img = RgbaImage::new(20, 20, 0xFFFF_FFFF)
  // 2x2 不透明红 logo，带一个透明角
  let logo = RgbaImage::new(2, 2, 0x0000_0000)
  logo.set_pixel(0, 0, 0xFF00_00FF)
  logo.set_pixel(1, 0, 0xFF00_00FF)
  logo.set_pixel(0, 1, 0xFF00_00FF)
  // (1,1) 保持透明黑
  let _ = img.embed_logo(logo, 5, 5, 1.0)
  assert_eq(img.get_pixel(5, 5), 0xFF00_00FF)
  assert_eq(img.get_pixel(6, 5), 0xFF00_00FF)
  assert_eq(img.get_pixel(6, 6), 0xFFFF_FFFF)
  // 外部区域不受影响
  assert_eq(img.get_pixel(0, 0), 0xFFFF_FFFF)
}

///|
test "embed_logo respects opacity" {
  let img = RgbaImage::new(10, 10, 0x0000_0000)
  let logo = RgbaImage::new(1, 1, 0xFF00_00FF)
  let _ = img.embed_logo(logo, 0, 0, 0.5)
  let p = img.get_pixel(0, 0)
  // 黑底 + 50% 红 → R=127
  assert_eq((p >> 24) & 0xFF, 127)
}

///|
test "embed_logo clips out of bounds" {
  let img = RgbaImage::new(5, 5, 0xFFFF_FFFF)
  let logo = RgbaImage::new(10, 10, 0xFF00_00FF)
  let _ = img.embed_logo(logo, 3, 3, 1.0)
  // 越界裁剪：可见部分为红，不崩溃
  assert_eq(img.get_pixel(3, 3), 0xFF00_00FF)
  assert_eq(img.get_pixel(4, 4), 0xFF00_00FF)
}

///|
test "embed_tiled covers image" {
  let img = RgbaImage::new(30, 30, 0xFFFF_FFFF)
  let cfg = TiledConfig::new("WM", 1, 3, 3, 1.0, 0xFF00_00FF)
  let _ = img.embed_tiled(cfg)
  // 单元宽 11（"WM"）+3 间距 = 14；首个字形像素 (0,0) 与 (14,0) 均应为红
  assert_eq(img.get_pixel(0, 0), 0xFF00_00FF)
  assert_eq(img.get_pixel(14, 0), 0xFF00_00FF)
  assert_eq(img.get_pixel(0, 14), 0xFF00_00FF)
}

///|
test "embed_tiled empty text no crash" {
  let img = RgbaImage::new(10, 10, 0xFFFF_FFFF)
  let cfg = TiledConfig::new("", 1, 1, 1, 1.0, 0xFF00_00FF)
  let _ = img.embed_tiled(cfg)
  assert_eq(img.get_pixel(0, 0), 0xFFFF_FFFF)
}
