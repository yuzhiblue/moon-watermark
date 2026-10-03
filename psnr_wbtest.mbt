///|
test "psnr identical images" {
  let img = RgbaImage::new(32, 32, 0xFFFF_FFFF)
  match psnr(img, img) {
    Some(v) => assert_true(v >= 100000000.0) // 相同图 → 1e9
    None => assert_true(false)
  }
}

///|
test "psnr lsb watermark high fidelity" {
  let clean = RgbaImage::new(64, 64, 0xFFFF_FFFF)
  let marked = RgbaImage::new(64, 64, 0xFFFF_FFFF)
  let _ = marked.embed_invisible(Bytes::from_array([b'I', b'D']), key = 3L)
  match psnr(clean, marked) {
    Some(v) => {
      println("psnr|lsb|\{v}")
      assert_true(v > 40.0) // 高保真，肉眼不可察
    }
    None => assert_true(false)
  }
}

///|
test "psnr visible watermark noticeable" {
  let clean = RgbaImage::new(128, 128, 0xFFFF_FFFF)
  let marked = RgbaImage::new(128, 128, 0xFFFF_FFFF)
  let _ = marked.embed_dots(DotConfig::default())
  match psnr(clean, marked) {
    Some(v) => {
      println("psnr|dots|\{v}")
      assert_true(v < 40.0) // 可见水印显著低于 40dB
    }
    None => assert_true(false)
  }
}

///|
test "psnr size mismatch none" {
  let a = RgbaImage::new(32, 32, 0xFFFF_FFFF)
  let b = RgbaImage::new(64, 64, 0xFFFF_FFFF)
  assert_true(psnr(a, b) is None)
}
