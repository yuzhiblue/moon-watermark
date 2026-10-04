///|
test "render_text basic glyph A" {
  let img = render_text("A", 0xFFFF_FFFF)
  assert_eq(img.width, 5)
  assert_eq(img.height, 7)
  // 'A' 首行 01110：像素 (1..3) 亮，(0,4) 灭
  assert_eq(img.get_pixel(0, 0), 0x0000_0000)
  assert_eq(img.get_pixel(1, 0), 0xFFFF_FFFF)
  assert_eq(img.get_pixel(2, 0), 0xFFFF_FFFF)
  assert_eq(img.get_pixel(3, 0), 0xFFFF_FFFF)
  assert_eq(img.get_pixel(4, 0), 0x0000_0000)
  // 第四行 11111：全部亮
  assert_eq(img.get_pixel(0, 3), 0xFFFF_FFFF)
  assert_eq(img.get_pixel(4, 3), 0xFFFF_FFFF)
  // 最后一行 10001
  assert_eq(img.get_pixel(0, 6), 0xFFFF_FFFF)
  assert_eq(img.get_pixel(1, 6), 0x0000_0000)
  assert_eq(img.get_pixel(4, 6), 0xFFFF_FFFF)
}

///|
test "render_text width with spacing" {
  let img = render_text("AB", 0xFFFF_FFFF)
  // 2 字符 × (5+1) - 1
  assert_eq(img.width, 11)
  assert_eq(img.height, 7)
}

///|
test "render_text scale" {
  let img = render_text("A", 0xFFFF_FFFF, scale=2)
  assert_eq(img.width, 10)
  assert_eq(img.height, 14)
  // 'A' 首行 01110：col0 透明，col1-3 亮（各占 2px → x=2..7 亮）
  assert_eq(img.get_pixel(0, 0), 0x0000_0000)
  assert_eq(img.get_pixel(1, 0), 0x0000_0000)
  assert_eq(img.get_pixel(2, 0), 0xFFFF_FFFF)
  assert_eq(img.get_pixel(7, 0), 0xFFFF_FFFF)
  assert_eq(img.get_pixel(8, 0), 0x0000_0000)
  // 中间行 11111：全亮
  assert_eq(img.get_pixel(0, 6), 0xFFFF_FFFF)
  assert_eq(img.get_pixel(9, 6), 0xFFFF_FFFF)
  // 末行 10001：左右亮中间灭
  assert_eq(img.get_pixel(0, 13), 0xFFFF_FFFF)
  assert_eq(img.get_pixel(4, 13), 0x0000_0000)
  assert_eq(img.get_pixel(8, 13), 0xFFFF_FFFF)
}

///|
test "render_text unsupported char is blank" {
  let img = render_text("中", 0xFFFF_FFFF)
  // 不支持字符渲染为空白：宽度 5（单字符），全透明
  assert_eq(img.width, 5)
  assert_eq(img.get_pixel(0, 0), 0x0000_0000)
  assert_eq(img.get_pixel(4, 6), 0x0000_0000)
}

///|
test "blend_pixel math" {
  // 纯黑底色 + 纯白前景 50% → 255*128/255 = 128 灰
  assert_eq(blend_pixel(0x0000_0000, 0xFFFF_FFFF, 128), 0x8080_8080)
  // alpha=0 → 完全保留底
  assert_eq(blend_pixel(0x1122_3344, 0xFFFF_FFFF, 0), 0x1122_3344)
  // alpha=255 → 完全覆盖
  assert_eq(blend_pixel(0x1122_3344, 0xAABB_CCDD, 255), 0xAABB_CCDD)
}

///|
test "embed_text overlays at position" {
  let img = RgbaImage::new(20, 20, 0xFFFF_FFFF)
  let cfg : TextConfig = {
    text: "A",
    x: 5,
    y: 6,
    font_size: 1,
    opacity: 1.0,
    angle: 0.0,
    color: 0xFF00_0000,
    font: "ascii5x7",
    auto_shrink: false,
  }
  let _ = img.embed_text(cfg)
  // (5,6) 是 'A' 首行 col0（透明）→ 保持原色；(6,6) 是 col1 → 不透明红
  assert_eq(img.get_pixel(5, 6), 0xFFFF_FFFF)
  assert_eq(img.get_pixel(6, 6), 0xFF00_00FF)
  // 水印外区域保持原色
  assert_eq(img.get_pixel(0, 0), 0xFFFF_FFFF)
  assert_eq(img.get_pixel(19, 19), 0xFFFF_FFFF)
}

///|
test "embed_text respects opacity" {
  // 黑底 + 50% 不透明度红字 → 红通道 255*127/255 = 127，绿蓝保持 0
  let img = RgbaImage::new(10, 10, 0x0000_0000)
  let cfg : TextConfig = {
    text: "A",
    x: 0,
    y: 0,
    font_size: 1,
    opacity: 0.5,
    angle: 0.0,
    color: 0xFF00_0000,
    font: "ascii5x7",
    auto_shrink: false,
  }
  let _ = img.embed_text(cfg)
  // 打包 0xRRGGBBAA：R=127、G=0、B=0、A=127
  let p = img.get_pixel(1, 0)
  assert_eq((p >> 24) & 0xFF, 127)
  assert_eq((p >> 16) & 0xFF, 0)
}

///|
test "embed_text rejects out of bounds (v0.1.11)" {
  // v0.1.11：水平文本越界不再静默裁剪，默认返回 Err
  let img = RgbaImage::new(8, 8, 0xFFFF_FFFF)
  let cfg : TextConfig = {
    text: "ABC",
    x: 6,
    y: 6,
    font_size: 1,
    opacity: 1.0,
    angle: 0.0,
    color: 0xFF00_0000,
    font: "ascii5x7",
    auto_shrink: false,
  }
  let r = img.embed_text(cfg)
  assert_true(r is Err(_))
  // 原图未被污染
  assert_eq(img.get_pixel(0, 0), 0xFFFF_FFFF)
  assert_eq(img.get_pixel(7, 7), 0xFFFF_FFFF)
}

///|
test "embed_text auto_shrink fits wide text (v0.1.11)" {
  // auto_shrink=true：超宽文本自动缩小字号适配画布
  // ascii5x7 每字符占 6px（5px 字形 + 1px 间距），"ABCDEF" 最小宽 (6×6-1)=35px
  let img = RgbaImage::new(35, 30, 0xFFFF_FFFF)
  let cfg : TextConfig = {
    text: "ABCDEF",
    x: 0,
    y: 0,
    font_size: 3,
    opacity: 1.0,
    angle: 0.0,
    color: 0xFF00_0000,
    font: "ascii5x7",
    auto_shrink: true,
  }
  let r = img.embed_text(cfg)
  assert_true(r is Ok(_))
  // 缩小到 scale=1（35px）完整落在画布内，水印外像素保持原色
  assert_eq(img.get_pixel(0, 0), 0xFFFF_FFFF)
}

///|
test "embed_text auto_shrink cannot fit returns Err (v0.1.11)" {
  // 文本长到 scale=1 仍超宽 → 返回 Err
  let img = RgbaImage::new(30, 30, 0xFFFF_FFFF)
  let cfg : TextConfig = {
    text: "ABCDEFGHIJKLMNOPQRSTUVWXYZ",
    x: 0,
    y: 0,
    font_size: 2,
    opacity: 1.0,
    angle: 0.0,
    color: 0xFF00_0000,
    font: "ascii5x7",
    auto_shrink: true,
  }
  let r = img.embed_text(cfg)
  assert_true(r is Err(_))
}

///|
test "embed_text rotated wide text still allowed (v0.1.11)" {
  // angle≠0 保留跨画布特性（45° 斜向水印），不触发越界检查
  let img = RgbaImage::new(30, 30, 0xFFFF_FFFF)
  let cfg : TextConfig = {
    text: "ABCDEFGHIJKLMNOPQRSTUVWXYZ",
    x: 0,
    y: 0,
    font_size: 2,
    opacity: 1.0,
    angle: 45.0,
    color: 0xFF00_0000,
    font: "ascii5x7",
    auto_shrink: false,
  }
  let r = img.embed_text(cfg)
  assert_true(r is Ok(_))
}

///|
test "embed_text applies angle rotation" {
  // 注意：embed_text 原地修改并返回 self，每次调用须用独立画布
  let cfg = TextConfig::with_font("A", 20, 20, 1, 1.0, 0xFFFF_0000, "ascii5x7")
  let marked = must(RgbaImage::new(64, 64, 0xFF00_00FF).embed_text({ text: cfg.text, x: cfg.x, y: cfg.y, font_size: cfg.font_size, opacity: cfg.opacity, angle: 45.0, color: cfg.color, font: cfg.font, auto_shrink: false, }))
  assert_eq(marked.width, 64)
  assert_eq(marked.height, 64)
  // 与 angle=0 的叠加结果应不同（旋转改变了像素分布）
  let flat = must(RgbaImage::new(64, 64, 0xFF00_00FF).embed_text({ text: cfg.text, x: cfg.x, y: cfg.y, font_size: cfg.font_size, opacity: cfg.opacity, angle: 0.0, color: cfg.color, font: cfg.font, auto_shrink: false, }))
  let mut diff = false
  for y in 0..<64 {
    for x in 0..<64 {
      if marked.get_pixel(x, y) != flat.get_pixel(x, y) {
        diff = true
      }
    }
  }
  assert_true(diff)
}
