///|
/// 鲁棒性测试矩阵：验证各水印类型在典型攻击下的表现。
///
/// 结论供申报书「鲁棒性测试矩阵」引用：
/// - LSB 不可见水印：抗 PNG 无损 ✅；抗 JPEG 有损 ❌（量化破坏 LSB）
///   → 需 JPEG 鲁棒水印时走 DCT 域路线（roadmap）
/// - 点阵水印：抗无损 ✅；JPEG / 缩放 / 裁剪下命中率下降（实测记录）

///|
test "robustness: lsb destroyed by jpeg requantization" {
  let img = RgbaImage::new(64, 64, 0xFFFF_FFFF)
  let _ = img.embed_invisible(Bytes::from_array([b'I', b'D']), key=5L)
  // JPEG 有损量化必然破坏 RGB LSB
  match img.encode_jpeg(40) {
    Ok(jpg) =>
      match decode_jpeg(jpg) {
        Ok(back) => assert_true(extract_invisible(back, key=5L) is None)
        Err(_) => assert_true(false)
      }
    Err(_) => assert_true(false)
  }
}

///|
test "robustness: dots survive png, rate recorded" {
  let img = RgbaImage::new(128, 128, 0xFFFF_FFFF)
  let cfg = DotConfig::default()
  let _ = img.embed_dots(cfg)
  match img.encode_png() {
    Ok(png) =>
      match decode_png(png) {
        Ok(back) => {
          let rate = extract_dots(back, cfg)
          println("matrix|dots|png-lossless|hit-rate|\{rate}")
          assert_true(rate >= 0.9)
        }
        Err(_) => assert_true(false)
      }
    Err(_) => assert_true(false)
  }
}

///|
test "robustness: dots vs jpeg, rate recorded" {
  let img = RgbaImage::new(128, 128, 0xFFFF_FFFF)
  let cfg = DotConfig::default()
  let _ = img.embed_dots(cfg)
  match img.encode_jpeg(60) {
    Ok(jpg) =>
      match decode_jpeg(jpg) {
        Ok(back) => {
          let rate = extract_dots(back, cfg)
          println("matrix|dots|jpeg-q60|hit-rate|\{rate}")
        }
        Err(_) => assert_true(false)
      }
    Err(_) => assert_true(false)
  }
}

///|
test "robustness: dots vs resize, rate recorded" {
  let img = RgbaImage::new(128, 128, 0xFFFF_FFFF)
  let cfg = DotConfig::default()
  let _ = img.embed_dots(cfg)
  let half = img.resize(64, 64, SampleMode::Nearest)
  let rate = extract_dots(half, cfg)
  println("matrix|dots|resize-half|hit-rate|\{rate}")
}

///|
test "robustness: dots vs crop, rate recorded" {
  let img = RgbaImage::new(128, 128, 0xFFFF_FFFF)
  let cfg = DotConfig::default()
  let _ = img.embed_dots(cfg)
  // 裁掉右下半幅（可能包含一半水印点）
  let cropped = img.crop(0, 0, 128, 64)
  let rate = extract_dots(cropped, cfg)
  println("matrix|dots|crop-half|hit-rate|\{rate}")
}

///|
test "robustness: lsb vs resize, recorded" {
  let img = RgbaImage::new(128, 128, 0xFFFF_FFFF)
  let _ = img.embed_invisible(Bytes::from_array([b'I', b'D']), key=5L)
  let half = img.resize(64, 64, SampleMode::Nearest)
  let r = match extract_invisible(half, key=5L) {
    Some(_) => "ok"
    None => "fail"
  }
  println("matrix|lsb|resize-half|extract|\{r}")
}

///|
test "robustness: lsb vs crop, recorded" {
  let img = RgbaImage::new(128, 128, 0xFFFF_FFFF)
  let _ = img.embed_invisible(Bytes::from_array([b'I', b'D']), key=5L)
  let cropped = img.crop(0, 0, 128, 64)
  let r2 = match extract_invisible(cropped, key=5L) {
    Some(_) => "ok"
    None => "fail"
  }
  println("matrix|lsb|crop-half|extract|\{r2}")
}
