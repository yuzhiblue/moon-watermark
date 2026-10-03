///|
/// 集成测试：PNG 无损往返后 LSB 不可见水印与点阵水印仍可提取/验证。
/// （PNG 编码/解码不损失像素数据，是 LSB 水印的可靠载体。）

///|
test "lsb watermark survives png roundtrip" {
  let img = RgbaImage::new(32, 32, 0xFFFF_FFFF)
  let payload = Bytes::from_array([b'V', b'I', b'E', b'W', b'E', b'R'])
  let _ = img.embed_invisible(payload, key = 99L)
  let png = img.encode_png()
  match png {
    Ok(bytes) => {
      match decode_png(bytes) {
        Ok(back) => {
          match extract_invisible(back, key = 99L) {
            Some(out) => {
              assert_eq(out.length(), 6)
              assert_eq(out[0], b'V')
              assert_eq(out[5], b'R')
            }
            None => assert_true(false)
          }
        }
        Err(_) => assert_true(false)
      }
    }
    Err(_) => assert_true(false)
  }
}

///|
test "dot watermark survives png roundtrip" {
  let img = RgbaImage::new(64, 64, 0xFFFF_FFFF)
  let cfg = DotConfig::default()
  let _ = img.embed_dots(cfg)
  let png = img.encode_png()
  match png {
    Ok(bytes) => {
      match decode_png(bytes) {
        Ok(back) => assert_true(verify_dots(back, cfg))
        Err(_) => assert_true(false)
      }
    }
    Err(_) => assert_true(false)
  }
}
