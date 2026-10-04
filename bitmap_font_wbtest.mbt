///|
test "bitmap_font custom table renders" {
  // 8×8 自定义字形表：'X' 对角线
  let font = BitmapFont::new(8, 8, [
    ('X', [b'\x81', b'\x42', b'\x24', b'\x18', b'\x18', b'\x24', b'\x42', b'\x81']),
  ])
  assert_eq(font.cell_width(), 8)
  assert_eq(font.cell_height(), 8)
  let wm = render_text_with("X", 0xFF00_0000, font)
  assert_eq(wm.width, 8)
  assert_eq(wm.height, 8)
  // 至少 4 个非透明像素（对角线 8 个，降采样后不少于 4）
  let mut on = 0
  for y in 0..<8 {
    for x in 0..<8 {
      if ((wm.get_pixel(x, y) >> 24) & 0xFF) > 0 {
        on = on + 1
      }
    }
  }
  assert_true(on >= 4)
  // 未收录字符返回 None
  assert_true(font.glyph('Y') is None)
}

///|
test "bitmap_font duplicate key last wins" {
  let font = BitmapFont::new(8, 8, [
    ('X', [b'\x01', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00']),
    ('X', [b'\x80', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00']),
  ])
  match font.glyph('X') {
    Some(g) => assert_eq(g[0], b'\x80')
    None => assert_true(false)
  }
}

///|
test "bitmap_font with_cjk16 adds rare char" {
  // '龘' 不在 GB2312 一级字集，默认 Cjk16 返回 None；with_cjk16 可补充
  let font = BitmapFont::with_cjk16([
    ('龘', [b'\xFF', b'\xFF', b'\xFF', b'\xFF', b'\xFF', b'\xFF', b'\xFF', b'\xFF', b'\xFF', b'\xFF', b'\xFF', b'\xFF', b'\xFF', b'\xFF', b'\xFF', b'\xFF', b'\xFF', b'\xFF', b'\xFF', b'\xFF', b'\xFF', b'\xFF', b'\xFF', b'\xFF', b'\xFF', b'\xFF', b'\xFF', b'\xFF', b'\xFF', b'\xFF', b'\xFF', b'\xFF']),
  ])
  // 内置 GB2312 字保留
  assert_true(font.glyph('防') is Some(_))
  // 补充的生僻字可查询
  assert_true(font.glyph('龘') is Some(_))
  // ASCII 已内置（v0.1.10 起），可查询
  assert_true(font.glyph('a') is Some(_))
  // 覆盖语义：内置字也可被调用方替换
  let font2 = BitmapFont::with_cjk16([
    ('防', [b'\xFF', b'\xFF', b'\xFF', b'\xFF', b'\xFF', b'\xFF', b'\xFF', b'\xFF', b'\xFF', b'\xFF', b'\xFF', b'\xFF', b'\xFF', b'\xFF', b'\xFF', b'\xFF', b'\xFF', b'\xFF', b'\xFF', b'\xFF', b'\xFF', b'\xFF', b'\xFF', b'\xFF', b'\xFF', b'\xFF', b'\xFF', b'\xFF', b'\xFF', b'\xFF', b'\xFF', b'\xFF']),
  ])
  match font2.glyph('防') {
    Some(g) => assert_eq(g[0], b'\xFF')
    None => assert_true(false)
  }
}
