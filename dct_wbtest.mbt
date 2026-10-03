///|
test "dct roundtrip lossless" {
  let img = RgbaImage::new(64, 64, 0xFF80_8080)
  let payload = Bytes::from_array([b'D', b'C', b'T'])
  match img.embed_dct(payload) {
    Ok(_) => {
      match extract_dct(img) {
        Some(out) => {
          assert_eq(out.length(), 3)
          assert_eq(out[0], b'D')
          assert_eq(out[2], b'T')
        }
        None => assert_true(false)
      }
    }
    Err(_) => assert_true(false)
  }
}

///|
test "dct survives png roundtrip" {
  let img = RgbaImage::new(64, 64, 0xFF80_8080)
  let payload = Bytes::from_array([b'P', b'N', b'G'])
  let _ = img.embed_dct(payload)
  match img.encode_png() {
    Ok(png) => {
      match decode_png(png) {
        Ok(back) => assert_true(extract_dct(back) is Some(_))
        Err(_) => assert_true(false)
      }
    }
    Err(_) => assert_true(false)
  }
}

///|
test "dct survives jpeg q60" {
  let img = RgbaImage::new(128, 128, 0xFF80_8080)
  let payload = Bytes::from_array([b'J', b'P', b'E', b'G', b'!'])
  let _ = img.embed_dct(payload)
  match img.encode_jpeg(60) {
    Ok(jpg) => {
      match decode_jpeg(jpg) {
        Ok(back) => {
          match extract_dct(back) {
            Some(out) => {
              assert_eq(out.length(), 5)
              assert_eq(out[0], b'J')
              assert_eq(out[4], b'!')
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
test "dct wrong magic rejected" {
  let img = RgbaImage::new(64, 64, 0xFF80_8080)
  // 未嵌入 → 提取 None
  assert_true(extract_dct(img) is None)
}

///|
test "dct payload too large" {
  let img = RgbaImage::new(32, 32, 0xFF80_8080)
  // 32x32 → 16 块 → 2 字节容量；5 字节 payload 超出
  let big = Bytes::make(5, b'X')
  match img.embed_dct(big) {
    Ok(_) => assert_true(false)
    Err(_) => assert_true(true)
  }
}

///|
/// 构造非饱和渐变图（30..209 灰度，模拟真实纹理）。
fn grad_img(w : Int, h : Int) -> RgbaImage {
  let img = RgbaImage::new(w, h, 0xFF00_0000)
  for y in 0..<h {
    for x in 0..<w {
      let g = ((x + y) % 180) + 30
      img.set_pixel(x, y, 0xFF00_0000 | (g << 16) | (g << 8) | g)
    }
  }
  img
}

///|
/// 渐变背景（模拟真实纹理，非单一灰度）：JPEG q60 后仍可提取。
test "dct survives jpeg q60 gradient" {
  let img = grad_img(128, 128)
  let payload = Bytes::from_array([b'g', b'r', b'a', b'd', b'e'])
  let _ = img.embed_dct(payload)
  match img.encode_jpeg(60) {
    Ok(jpg) => {
      match decode_jpeg(jpg) {
        Ok(back) => {
          match extract_dct(back) {
            Some(out) => {
              assert_eq(out.length(), 5)
              assert_eq(out[0], b'g')
              assert_eq(out[4], b'e')
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
/// DCT 域不可见性：Δ=24 时扰动 ≤±4 灰度，PSNR ≈35dB（远高于可见水印 25dB；
/// 低于 LSB 的 77dB 是 JPEG 鲁棒性的代价，见 README 选型表）。
test "dct psnr > 30" {
  let orig = grad_img(128, 128)
  let marked = grad_img(128, 128)
  let payload = Bytes::from_array([b'p', b's', b'n', b'r'])
  let _ = marked.embed_dct(payload)
  match psnr(orig, marked) {
    Some(v) => assert_true(v > 30.0)
    None => assert_true(false)
  }
}
