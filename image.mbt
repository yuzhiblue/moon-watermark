///|
/// RGBA 图像数据结构：每像素 4 字节（R,G,B,A），行优先存储。
///
/// 内部用 `FixedArray[Byte]` 存储以便像素级原地修改（水印嵌入零复制）；
/// 与 mizchi/image 的 `ImageData`（Bytes）互转见 `decode_png` / `encode_png`。
pub struct RgbaImage {
  width : Int
  height : Int
  data : FixedArray[Byte]
}

///|
/// 缩放采样方式。
pub(all) enum SampleMode {
  Nearest
  Bilinear
}

///|
/// 创建指定尺寸的纯色图像。
///
/// 参数 `rgba` 为打包颜色：`0xRRGGBBAA`。
pub fn RgbaImage::new(width : Int, height : Int, rgba : Int) -> RgbaImage {
  let bytes = FixedArray::make(width * height * 4, b'\x00')
  let img = { width, height, data: bytes, }
  for i in 0..<(width * height) {
    let x = i % width
    let y = i / width
    img.set_pixel(x, y, rgba)
  }
  img
}

///|
/// 读取像素，返回打包 RGBA 颜色 `0xRRGGBBAA`。
pub fn RgbaImage::get_pixel(self : RgbaImage, x : Int, y : Int) -> Int {
  let idx = (y * self.width + x) * 4
  let d = self.data
  (d[idx].to_int() << 24) |
  (d[idx + 1].to_int() << 16) |
  (d[idx + 2].to_int() << 8) |
  d[idx + 3].to_int()
}

///|
/// 写入像素，`rgba` 为打包颜色 `0xRRGGBBAA`。
pub fn RgbaImage::set_pixel(
  self : RgbaImage,
  x : Int,
  y : Int,
  rgba : Int,
) -> Unit {
  let idx = (y * self.width + x) * 4
  let d = self.data
  d[idx] = ((rgba >> 24) & 0xFF).to_byte()
  d[idx + 1] = ((rgba >> 16) & 0xFF).to_byte()
  d[idx + 2] = ((rgba >> 8) & 0xFF).to_byte()
  d[idx + 3] = (rgba & 0xFF).to_byte()
}

///|
/// 从 PNG 字节解码为 `RgbaImage`。
pub fn decode_png(raw : Bytes) -> Result[RgbaImage, String] {
  try {
    let img = @image.decode_png(raw)
    Ok({ width: img.width, height: img.height, data: img.data.to_fixedarray(), })
  } catch {
    _ => Err("decode_png: invalid png data")
  }
}

///|
/// 将 `RgbaImage` 编码为 PNG 字节。
pub fn RgbaImage::encode_png(self : RgbaImage) -> Result[Bytes, String] {
  try {
    let id : @image.ImageData = {
      width: self.width,
      height: self.height,
      data: Bytes::from_array(self.data),
    }
    Ok(@image.encode_png(id))
  } catch {
    _ => Err("encode_png: invalid image")
  }
}

///|
/// 从 JPEG 字节解码为 `RgbaImage`。
pub fn decode_jpeg(raw : Bytes) -> Result[RgbaImage, String] {
  try {
    let img = @image.decode_jpeg(raw)
    Ok({ width: img.width, height: img.height, data: img.data.to_fixedarray(), })
  } catch {
    _ => Err("decode_jpeg: invalid jpeg data")
  }
}

///|
/// 将 `RgbaImage` 编码为 JPEG 字节（质量 0~100，用于鲁棒性测试）。
pub fn RgbaImage::encode_jpeg(
  self : RgbaImage,
  quality : Int,
) -> Result[Bytes, String] {
  try {
    let id : @image.ImageData = {
      width: self.width,
      height: self.height,
      data: Bytes::from_array(self.data),
    }
    Ok(@image.encode_jpeg(id, quality~))
  } catch {
    _ => Err("encode_jpeg: invalid image")
  }
}

///|
/// 缩放图像。非法尺寸时返回原图副本。
pub fn RgbaImage::resize(
  self : RgbaImage,
  width : Int,
  height : Int,
  sampler : SampleMode,
) -> RgbaImage {
  let m = match sampler {
    Nearest => @image.ResizeMethod::Nearest
    Bilinear => @image.ResizeMethod::Bilinear
  }
  try {
    let id : @image.ImageData = {
      width: self.width,
      height: self.height,
      data: Bytes::from_array(self.data),
    }
    let out = @image.resize(id, width, height, m)
    { width: out.width, height: out.height, data: out.data.to_fixedarray(), }
  } catch {
    _ => panic()
  }
}

///|
/// 裁剪图像区域 `(x, y, w, h)`。越界坐标被钳制到图像范围内。
pub fn RgbaImage::crop(
  self : RgbaImage,
  x : Int,
  y : Int,
  w : Int,
  h : Int,
) -> RgbaImage {
  if w <= 0 || h <= 0 {
    return { width: 0, height: 0, data: FixedArray::make(0, b'\x00'), }
  }
  let cx0 = if x < 0 { 0 } else if x >= self.width { self.width - 1 } else { x }
  let cy0 = if y < 0 {
    0
  } else if y >= self.height {
    self.height - 1
  } else {
    y
  }
  let cw = if cx0 + w > self.width { self.width - cx0 } else { w }
  let ch = if cy0 + h > self.height { self.height - cy0 } else { h }
  let out = FixedArray::make(cw * ch * 4, b'\x00')
  for row in 0..<ch {
    let src_off = ((cy0 + row) * self.width + cx0) * 4
    let dst_off = row * cw * 4
    out.blit_from_bytes(dst_off, Bytes::from_array(self.data), src_off, cw * 4)
  }
  { width: cw, height: ch, data: out, }
}
