///|
/// 组合嵌入 embed_all 的测试：多通道叠加、互斥报错、空配置。

///|
test "embed_all combines text and lsb" {
  // 约束：可见文本需避开不可见水印左上角头部区（LSB 前 32 bit），
  // 此处放右下角（与 CLI 默认位置一致）
  let img = RgbaImage::new(64, 64, 0xFF80_8080)
  let tcfg = { text: "WM", x: 30, y: 50, font_size: 1, opacity: 1.0, angle: 45.0, color: 0xFFFF_0000, font: "ascii5x7", auto_shrink: false, }
  let payload = Bytes::from_array([b'a', b'b', b'c', b'd'])
  let opts = {
    text_cfg: Some(tcfg),
    dot_cfg: None,
    lsb_payload: Some(payload),
    lsb_key: Some(7L),
    dct_payload: None,
    dct_delta: 24,
  }
  match img.embed_all(opts) {
    Ok(marked) => {
      // 两个通道全部生效：LSB 带 key 提取到原 payload、画布出现文本像素。
      // 注意：带 key 混淆的帧头部被 XOR，无 key 的 detect_lsb 检不出（文档化语义）
      assert_true(!detect_lsb(marked))
      let mut text_hit = false
      for y in 0..<64 {
        for x in 0..<64 {
          if marked.get_pixel(x, y) != 0xFF80_8080 {
            text_hit = true
          }
        }
      }
      assert_true(text_hit)
      match extract_invisible(marked, key=7L) {
        Some(b) => assert_eq(b, payload)
        None => assert_true(false)
      }
    }
    Err(_) => assert_true(false)
  }
}

///|
test "embed_all supports dots channel alone" {
  let img = RgbaImage::new(64, 64, 0xFF80_8080)
  let dcfg = DotConfig::default()
  let opts = {
    text_cfg: None,
    dot_cfg: Some(dcfg),
    lsb_payload: None,
    lsb_key: None,
    dct_payload: None,
    dct_delta: 24,
  }
  match img.embed_all(opts) {
    Ok(marked) => assert_true(extract_dots(marked, dcfg) >= 0.9)
    Err(_) => assert_true(false)
  }
}

///|
test "embed_all dct channel" {
  let img = RgbaImage::new(64, 64, 0xFF80_8080)
  let payload = Bytes::from_array([b'z', b'9'])
  let opts = {
    text_cfg: None,
    dot_cfg: None,
    lsb_payload: None,
    lsb_key: None,
    dct_payload: Some(payload),
    dct_delta: 24,
  }
  match img.embed_all(opts) {
    Ok(marked) => {
      assert_true(detect_dct(marked, delta=24))
      match extract_dct(marked, delta=24) {
        Some(b) => assert_eq(b, payload)
        None => assert_true(false)
      }
    }
    Err(_) => assert_true(false)
  }
}

///|
test "embed_all rejects lsb and dct together" {
  let img = RgbaImage::new(64, 64, 0xFF80_8080)
  let opts = {
    text_cfg: None,
    dot_cfg: None,
    lsb_payload: Some(Bytes::from_array([b'x'])),
    lsb_key: None,
    dct_payload: Some(Bytes::from_array([b'y'])),
    dct_delta: 24,
  }
  assert_true(img.embed_all(opts) is Err(_))
}

///|
test "embed_all empty config returns same content" {
  let img = RgbaImage::new(16, 16, 0xFF80_8080)
  let opts = {
    text_cfg: None,
    dot_cfg: None,
    lsb_payload: None,
    lsb_key: None,
    dct_payload: None,
    dct_delta: 24,
  }
  match img.embed_all(opts) {
    Ok(m) => assert_eq(m.get_pixel(5, 5), 0xFF80_8080)
    Err(_) => assert_true(false)
  }
}
