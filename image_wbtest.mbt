///|
/// 测试辅助：解包 Result[RgbaImage, String]（embed_* 统一返回 Result 后使用）。
fn must(img : Result[RgbaImage, String]) -> RgbaImage {
  match img {
    Ok(i) => i
    Err(_) => panic()
  }
}

///|
test "new creates solid image" {
  let img = RgbaImage::new(4, 3, 0xFF00_00FF)
  assert_eq(img.width, 4)
  assert_eq(img.height, 3)
  assert_eq(img.data.length(), 4 * 3 * 4)
  assert_eq(img.get_pixel(0, 0), 0xFF00_00FF)
  assert_eq(img.get_pixel(3, 2), 0xFF00_00FF)
}

///|
test "set_pixel get_pixel roundtrip" {
  let img = RgbaImage::new(2, 2, 0x0000_0000)
  img.set_pixel(1, 1, 0x1122_3344)
  assert_eq(img.get_pixel(1, 1), 0x1122_3344)
  assert_eq(img.get_pixel(0, 0), 0x0000_0000)
}

///|
test "encode_png decode_png roundtrip" {
  let img = RgbaImage::new(8, 8, 0xFFFFFFFF)
  img.set_pixel(0, 0, 0xFF00_0000)
  img.set_pixel(7, 7, 0x0000_00FF)
  let bytes = img.encode_png()
  assert_true(bytes is Ok(_))
  let decoded = decode_png(bytes.unwrap())
  assert_true(decoded is Ok(_))
  let d = decoded.unwrap()
  assert_eq(d.width, 8)
  assert_eq(d.height, 8)
  assert_eq(d.get_pixel(0, 0), 0xFF00_0000)
  assert_eq(d.get_pixel(7, 7), 0x0000_00FF)
  assert_eq(d.get_pixel(3, 3), 0xFFFFFFFF)
}

///|
test "decode_png rejects garbage" {
  let res = decode_png(Bytes::from_array(FixedArray::make(8, b'\x00')))
  assert_true(res is Err(_))
}

///|
test "resize scales dimensions" {
  let img = RgbaImage::new(4, 4, 0xFFFFFFFF)
  let small = img.resize(2, 2, Nearest)
  assert_eq(small.width, 2)
  assert_eq(small.height, 2)
  let big = img.resize(8, 8, Bilinear)
  assert_eq(big.width, 8)
  assert_eq(big.height, 8)
}

///|
test "resize keeps content with nearest" {
  let img = RgbaImage::new(2, 2, 0x0000_0000)
  img.set_pixel(0, 0, 0xFFFF_0000)
  let up = img.resize(4, 4, Nearest)
  // 放大后左上 2x2 应为红色
  assert_eq(up.get_pixel(0, 0), 0xFFFF_0000)
  assert_eq(up.get_pixel(1, 1), 0xFFFF_0000)
  assert_eq(up.get_pixel(3, 3), 0x0000_0000)
}

///|
test "crop extracts region" {
  let img = RgbaImage::new(4, 4, 0x0000_0000)
  img.set_pixel(1, 1, 0xFFFF_0000)
  img.set_pixel(2, 2, 0xFF00_FF00)
  let region = img.crop(1, 1, 2, 2)
  assert_eq(region.width, 2)
  assert_eq(region.height, 2)
  assert_eq(region.get_pixel(0, 0), 0xFFFF_0000)
  assert_eq(region.get_pixel(1, 1), 0xFF00_FF00)
}

///|
test "crop clamps out of bounds" {
  let img = RgbaImage::new(4, 4, 0xFFFFFFFF)
  let region = img.crop(3, 3, 5, 5)
  assert_eq(region.width, 1)
  assert_eq(region.height, 1)
}

///|
test "crop with non-positive size returns empty image" {
  let img = RgbaImage::new(4, 4, 0xFFFFFFFF)
  let a = img.crop(1, 1, 0, 4)
  assert_eq(a.width, 0)
  assert_eq(a.height, 0)
  let b = img.crop(1, 1, -3, 2)
  assert_eq(b.width, 0)
  assert_eq(b.height, 0)
  let c = img.crop(1, 1, 2, -1)
  assert_eq(c.width, 0)
  assert_eq(c.height, 0)
}

///|
test "rotate 90 deg swaps dimensions" {
  let img = RgbaImage::new(4, 8, 0x0000_0000)
  img.set_pixel(0, 0, 0xFFFF_0000)
  let r = img.rotate(90.0)
  // 90° 旋转：包围盒为 8×4；左上角红点应转到右上角区域
  assert_eq(r.width, 8)
  assert_eq(r.height, 4)
  assert_eq(r.get_pixel(7, 0), 0xFFFF_0000)
}

///|
test "rotate 0 deg returns same image" {
  let img = RgbaImage::new(4, 4, 0xFF00_00FF)
  let r = img.rotate(0.0)
  assert_eq(r.width, 4)
  assert_eq(r.height, 4)
  assert_eq(r.get_pixel(2, 2), 0xFF00_00FF)
}
