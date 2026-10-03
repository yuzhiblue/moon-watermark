///|
test "invisible lsb roundtrip no key" {
  let img = RgbaImage::new(32, 32, 0xFFFF_FFFF)
  let payload = Bytes::from_array([b'A', b'B'])
  let _ = img.embed_invisible(payload)
  match extract_invisible(img) {
    Some(out) => {
      assert_eq(out.length(), 2)
      assert_eq(out[0], b'A')
      assert_eq(out[1], b'B')
    }
    None => assert_true(false)
  }
}

///|
test "invisible lsb roundtrip with key" {
  let img = RgbaImage::new(32, 32, 0xFFFF_FFFF)
  let payload = Bytes::from_array([b'U', b'I', b'D', b'7'])
  let _ = img.embed_invisible(payload, key=123L)
  match extract_invisible(img, key=123L) {
    Some(out) => {
      assert_eq(out.length(), 4)
      assert_eq(out[0], b'U')
      assert_eq(out[3], b'7')
    }
    None => assert_true(false)
  }
}

///|
test "invisible wrong key rejected" {
  let img = RgbaImage::new(32, 32, 0xFFFF_FFFF)
  let payload = Bytes::from_array([b'A', b'B'])
  let _ = img.embed_invisible(payload, key=1L)
  // 错误 key → magic 校验失败 → None
  assert_true(extract_invisible(img, key=2L) is None)
  // 无 key 提取同样失败（混淆帧破坏 magic）
  assert_true(extract_invisible(img) is None)
  // 正确 key 仍可提取
  assert_true(extract_invisible(img, key=1L) is Some(_))
}

///|
test "invisible payload too large" {
  let img = RgbaImage::new(8, 8, 0xFFFF_FFFF)
  // 容量 = 8*8*3/8 = 24 字节，25 字节 payload 超出
  let big = Bytes::make(25, b'X')
  match img.embed_invisible(big) {
    Ok(_) => assert_true(false)
    Err(_) => assert_true(true)
  }
}

///|
test "invisible embeds into lsb only" {
  let img = RgbaImage::new(16, 16, 0xABAB_ABAB)
  let payload = Bytes::from_array([b'L', b'S', b'B'])
  let _ = img.embed_invisible(payload)
  // 每通道仅 LSB 可变，高 7 位保持不变
  for y in 0..<16 {
    for x in 0..<16 {
      let p = img.get_pixel(x, y)
      assert_eq((p >> 24) & 0xFE, (0xABAB_ABAB >> 24) & 0xFE)
      assert_eq((p >> 16) & 0xFE, (0xABAB_ABAB >> 16) & 0xFE)
      assert_eq((p >> 8) & 0xFE, (0xABAB_ABAB >> 8) & 0xFE)
    }
  }
}
