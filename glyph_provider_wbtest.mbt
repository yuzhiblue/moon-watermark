///|
test "cjk16 renders chinese glyph" {
  let prov = Cjk16::new()
  assert_eq(prov.cell_width(), 16)
  assert_eq(prov.cell_height(), 16)
  match prov.glyph('防') {
    Some(g) => {
      assert_eq(g.length(), 32)
      // 首行非全空（有笔画像素）
      assert_true(g[0].to_int() != 0 || g[1].to_int() != 0)
    }
    None => assert_true(false)
  }
  // 未收录字符返回 None
  assert_true(prov.glyph('a') is None)
}

///|
test "cjk16 render_text produces non-empty image" {
  let wm = render_text_with("防", 0xFF00_0000, Cjk16::new(), scale=1)
  assert_eq(wm.width, 16)
  assert_eq(wm.height, 16)
  // 字形像素存在：至少一个非透明像素
  let mut on = 0
  for y in 0..<16 {
    for x in 0..<16 {
      if ((wm.get_pixel(x, y) >> 24) & 0xFF) > 0 {
        on += 1
      }
    }
  }
  assert_true(on > 0)
}

///|
test "embed_text with cjk16 config" {
  let img = RgbaImage::new(64, 64, 0xFFFF_FFFF)
  let cfg = TextConfig::with_font(
    "防盗播", 4, 4, 1, 1.0, 0xFF00_0000, "cjk16",
  )
  let _ = img.embed_text(cfg)
  // 中文水印区域出现红色像素
  let mut red = 0
  for y in 4..<24 {
    for x in 4..<60 {
      if ((img.get_pixel(x, y) >> 16) & 0xFF) > 0 {
        red += 1
      }
    }
  }
  assert_true(red > 50)
}

///|
test "text config json roundtrip with font" {
  let cfg = TextConfig::with_font("防", 0, 0, 2, 0.8, 0xFFFF_0000, "cjk16")
  let j = text_config_to_json(cfg)
  match text_config_from_json(j) {
    Some(back) => {
      assert_eq(back.font, "cjk16")
      assert_eq(back.text, "防")
      assert_eq(back.font_size, 2)
    }
    None => assert_true(false)
  }
  // 旧 JSON（无 font 字段）向后兼容 → 默认 ascii5x7
  match
    text_config_from_json(
      "{\"text\":\"A\",\"x\":0,\"y\":0,\"font_size\":1,\"opacity\":0.5,\"angle\":0.0,\"color\":0}",
    ) {
    Some(back) => assert_eq(back.font, "ascii5x7")
    None => assert_true(false)
  }
}

///|
test "with_cjk16 does not pollute global cjk glyphs" {
  // Map 为引用语义：直接 set 全局表会污染内置 Cjk16；with_cjk16 必须拷贝
  let extra = [('龘', FixedArray::make(16, b'\xFF'))]
  let _ = BitmapFont::with_cjk16(extra)
  // 补充的字形只应出现在返回的 BitmapFont 里，内置 Cjk16 不受影响
  assert_true(Cjk16::new().glyph('龘') is None)
  let font = BitmapFont::with_cjk16(extra)
  assert_true(font.glyph('龘') is Some(_))
}
