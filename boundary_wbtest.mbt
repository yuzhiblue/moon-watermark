///|
/// 边界输入测试：单像素图、纯色图、超大/空 payload、超长文本、0×0 裁剪。
/// 目标：任何非法/极端输入不得 panic 或静默溢出，必须返回 Err/None/合理空结果。

///|
test "boundary: 1x1 image lsb capacity insufficient returns Err" {
  let img = RgbaImage::new(1, 1, 0xFF00_00FF)
  // 容量 = 1*1*3/8 = 0 字节 < 4 字节帧头 → 必须 Err，不 panic
  let r = img.embed_invisible(Bytes::from_array([b'a']), key=1L)
  assert_true(r is Err(_))
}

///|
test "boundary: 1x1 image dct capacity insufficient returns Err" {
  let img = RgbaImage::new(1, 1, 0xFF00_00FF)
  // 块数 0 → 容量 0，必须 Err
  let r = img.embed_dct(Bytes::from_array([b'a']))
  assert_true(r is Err(_))
}

///|
test "boundary: lsb payload exactly at capacity is Ok, over is Err" {
  let img = RgbaImage::new(8, 8, 0xFF00_00FF)
  // 容量 = 8*8*3/8 = 24 字节 → 帧头 4 + payload 20 恰好填满
  let ok_payload = Bytes::from_array(FixedArray::make(20, b'a'))
  let r_ok = img.embed_invisible(ok_payload, key=7L)
  assert_true(r_ok is Ok(_))
  // 超 1 字节 → Err
  let over = Bytes::from_array(FixedArray::make(21, b'b'))
  let r_over = img.embed_invisible(over, key=7L)
  assert_true(r_over is Err(_))
}

///|
test "boundary: dct payload at capacity is Ok, over is Err" {
  // 中灰纯色：亮度适中、AC 系数为 0，DCT 往返应成功（饱和色见 weak-region 测试）
  let img = RgbaImage::new(64, 64, 0xFF80_8080)
  // 块数 64，容量 = 64/8 - 4 = 4 字节 payload
  let ok_payload = Bytes::from_array(FixedArray::make(4, b'c'))
  match img.embed_dct(ok_payload, delta=24) {
    Ok(marked) => {
      // 往返提取（无损内存链路）应拿到相同 payload
      match extract_dct(marked, delta=24) {
        Some(b) => assert_eq(b.length(), 4)
        None => assert_true(false)
      }
    }
    Err(_) => assert_true(false)
  }
  let over = Bytes::from_array(FixedArray::make(5, b'd'))
  let r_over = img.embed_dct(over, delta=24)
  assert_true(r_over is Err(_))
}

///|
test "boundary: empty payload round-trips on lsb and dct" {
  // DCT 空 payload 仍需 4 字节帧头（32 bit）→ 至少 32 块，用 64×64 中灰图
  let img = RgbaImage::new(64, 64, 0xFF80_8080)
  let empty = Bytes::from_array([])
  match img.embed_invisible(empty, key=3L) {
    Ok(marked) =>
      match extract_invisible(marked, key=3L) {
        Some(b) => assert_eq(b.length(), 0)
        None => assert_true(false)
      }
    Err(_) => assert_true(false)
  }
  match img.embed_dct(empty, delta=24) {
    Ok(marked) =>
      match extract_dct(marked, delta=24) {
        Some(b) => assert_eq(b.length(), 0)
        None => assert_true(false)
      }
    Err(_) => assert_true(false)
  }
}

///|
test "boundary: saturated solid color dct does not panic" {
  // 纯白/纯红等饱和区是 DCT 已知弱点（clamp 截断扰动，文档已说明）：
  // 要求 embed 成功、extract 不崩溃（成功或 None 均可），弱区由文档与 delta 调优覆盖
  let img = RgbaImage::new(64, 64, 0xFFFF_FFFF)
  let payload = Bytes::from_array([b'W', b'M', b'1'])
  match img.embed_dct(payload, delta=24) {
    Ok(marked) => {
      let _ = extract_dct(marked, delta=24)
      ()
    }
    Err(_) => assert_true(false) // embed 不应失败
  }
  let red = RgbaImage::new(64, 64, 0xFF00_00FF)
  match red.embed_dct(Bytes::from_array([b'W', b'M']), delta=24) {
    Ok(marked) => {
      let _ = extract_dct(marked, delta=24)
      ()
    }
    Err(_) => assert_true(false)
  }
}

///|
test "boundary: solid black image lsb round-trips" {
  let img = RgbaImage::new(16, 16, 0xFF00_0000)
  let payload = Bytes::from_array([b'k', b'2'])
  match img.embed_invisible(payload, key=5L) {
    Ok(marked) =>
      match extract_invisible(marked, key=5L) {
        Some(b) => assert_eq(b, payload)
        None => assert_true(false)
      }
    Err(_) => assert_true(false)
  }
}

///|
test "boundary: overly long text rejected instead of exhausting memory" {
  // 4000 字符文本旋转会分配 GB 级中间位图：embed_text 对 >512 字符返回 Err（资源保护）
  let long = "WM".repeat(2000)
  let cfg = { text: long, x: 0, y: 0, font_size: 1, opacity: 1.0, angle: 0.0, color: 0xFFFF_0000, font: "ascii5x7", auto_shrink: false, }
  let img = RgbaImage::new(64, 64, 0xFF00_00FF)
  let r = img.embed_text(cfg)
  assert_true(r is Err(_))
  // 400 字符在 64×64 画布超宽（v0.1.11 越界防护）→ Err
  let ok = "WM".repeat(200) // 400 字符
  let r2 = RgbaImage::new(64, 64, 0xFF00_00FF).embed_text({ text: ok, x: 0, y: 0, font_size: 1, opacity: 1.0, angle: 0.0, color: 0xFFFF_0000, font: "ascii5x7", auto_shrink: false, })
  assert_true(r2 is Err(_))
  // 边界内文本（10 字符 × 5px = 50px < 64）正常叠加
  let ok2 = "WM".repeat(5) // 10 字符
  let r3 = RgbaImage::new(64, 64, 0xFF00_00FF).embed_text({ text: ok2, x: 0, y: 0, font_size: 1, opacity: 1.0, angle: 0.0, color: 0xFFFF_0000, font: "ascii5x7", auto_shrink: false, })
  assert_true(r3 is Ok(_))
}

///|
test "boundary: zero-size crop returns empty image" {
  let img = RgbaImage::new(16, 16, 0xFF00_00FF)
  let c0 = img.crop(0, 0, 0, 0)
  assert_eq(c0.width, 0)
  assert_eq(c0.height, 0)
  // 越界裁剪钳制到图内
  let c1 = img.crop(10, 10, 100, 100)
  assert_eq(c1.width, 6)
  assert_eq(c1.height, 6)
  // 0×0 源图裁剪不越界
  let empty = RgbaImage::new(0, 0, 0)
  let c2 = empty.crop(0, 0, 8, 8)
  assert_eq(c2.width, 0)
  assert_eq(c2.height, 0)
}

///|
test "boundary: empty text tiled does not crash" {
  let img = RgbaImage::new(32, 32, 0xFF00_00FF)
  let cfg = { text: "", font_size: 1, spacing_x: 4, spacing_y: 4, opacity: 1.0, color: 0xFFFF_0000, font: "ascii5x7", }
  let r = img.embed_tiled(cfg)
  assert_true(r is Ok(_))
}

///|
test "capacity api matches embed boundary" {
  // 8×8 图 LSB：8*8*3/8 - 4 = 24 - 4 = 20
  let img8 = RgbaImage::new(8, 8, 0xFF80_8080)
  assert_eq(img8.lsb_capacity(), 20)
  // 1×1 图容量为负：任何 payload 都放不下
  let img1 = RgbaImage::new(1, 1, 0xFF80_8080)
  assert_true(img1.lsb_capacity() <= 0)
  // 64×64 图 DCT：64 块 → 64/8 - 4 = 4
  let img64 = RgbaImage::new(64, 64, 0xFF80_8080)
  assert_eq(img64.dct_capacity(), 4)
  // 与 embed 边界一致：恰 4 字节 Ok、5 字节 Err
  match img64.embed_dct(Bytes::from_array(FixedArray::make(4, b'c')), delta=24) {
    Ok(_) => ()
    Err(_) => assert_true(false)
  }
  assert_true(img64.embed_dct(Bytes::from_array(FixedArray::make(5, b'd')), delta=24) is Err(_))
}
