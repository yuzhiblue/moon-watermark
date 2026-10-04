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
/// 数学常量（DCT 基函数与旋转共用；同包内直接引用）。
const PI = 3.141592653589793
const SQRT2 = 1.4142135623730951

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
/// 从 `mizchi/image` 的 `ImageData` 构造本库 `RgbaImage`（decode 共用）。
fn from_image_data(img : @image.ImageData) -> RgbaImage {
  { width: img.width, height: img.height, data: img.data.to_fixedarray(), }
}

///|
/// 将本库 `RgbaImage` 转为 `mizchi/image` 的 `ImageData`（encode / resize 共用）。
fn to_image_data(img : RgbaImage) -> @image.ImageData {
  { width: img.width, height: img.height, data: Bytes::from_array(img.data), }
}

///|
/// 将图像绕中心旋转 `deg` 度（逆时针为正；任意角度，自动规范化到 [0, 360)）。
///
/// 采用逆映射最近邻采样（像素中心坐标，`round` 定位源像素），源范围外的
/// 像素保持透明（alpha 0）。输出为旋转后的包围盒尺寸；90/180/270 度为
/// 精确像素搬运（无采样误差），其余角度为最近邻近似。
pub fn RgbaImage::rotate(self : RgbaImage, deg : Double) -> RgbaImage {
  let mut a = deg
  while a >= 360.0 {
    a = a - 360.0
  }
  while a < 0.0 {
    a = a + 360.0
  }
  if a == 0.0 || self.width == 0 || self.height == 0 {
    return self
  }
  // 90/180/270 精确搬运，避免三角函数浮点误差
  if a == 90.0 {
    return rotate90(self)
  }
  if a == 180.0 {
    return rotate180(self)
  }
  if a == 270.0 {
    return rotate270(self)
  }
  let rad = a * PI / 180.0
  let c = @math.cos(rad)
  let s = @math.sin(rad)
  let w = self.width.to_double()
  let h = self.height.to_double()
  // 包围盒：旋转后跨度的 ceil（像素中心坐标下 90° 精确得 w/h 互换）
  let nw = (w * abs_d(c) + h * abs_d(s) - 0.000001).to_int() + 1
  let nh = (w * abs_d(s) + h * abs_d(c) - 0.000001).to_int() + 1
  let out = RgbaImage::new(nw, nh, 0x0000_0000)
  let cx = nw.to_double() / 2.0
  let cy = nh.to_double() / 2.0
  let ox = w / 2.0
  let oy = h / 2.0
  for y in 0..<nh {
    for x in 0..<nw {
      // 目标像素中心 → 逆旋转 → 源像素中心
      let dx = x.to_double() + 0.5 - cx
      let dy = y.to_double() + 0.5 - cy
      let sx = c * dx + s * dy + ox - 0.5
      let sy = -s * dx + c * dy + oy - 0.5
      let ix = round_d(sx)
      let iy = round_d(sy)
      if ix >= 0 && ix < self.width && iy >= 0 && iy < self.height {
        out.set_pixel(x, y, self.get_pixel(ix, iy))
      }
    }
  }
  out
}

///|
/// 90° 逆时针精确旋转。
fn rotate90(img : RgbaImage) -> RgbaImage {
  let out = RgbaImage::new(img.height, img.width, 0x0000_0000)
  for y in 0..<img.height {
    for x in 0..<img.width {
      out.set_pixel(img.height - 1 - y, x, img.get_pixel(x, y))
    }
  }
  out
}

///|
/// 180° 精确旋转。
fn rotate180(img : RgbaImage) -> RgbaImage {
  let out = RgbaImage::new(img.width, img.height, 0x0000_0000)
  for y in 0..<img.height {
    for x in 0..<img.width {
      out.set_pixel(img.width - 1 - x, img.height - 1 - y, img.get_pixel(x, y))
    }
  }
  out
}

///|
/// 270° 逆时针（= 90° 顺时针）精确旋转。
fn rotate270(img : RgbaImage) -> RgbaImage {
  let out = RgbaImage::new(img.height, img.width, 0x0000_0000)
  for y in 0..<img.height {
    for x in 0..<img.width {
      out.set_pixel(y, img.width - 1 - x, img.get_pixel(x, y))
    }
  }
  out
}

///|
/// 四舍五入到最近整数（`core/double` 的 round 返回 Double，转 Int 前处理）。
fn round_d(x : Double) -> Int {
  if x >= 0.0 {
    (x + 0.5).to_int()
  } else {
    (x - 0.5).to_int()
  }
}

///|
/// 求 Double 绝对值（math 包未直接导出 abs，内联实现）。
fn abs_d(x : Double) -> Double {
  if x < 0.0 { -x } else { x }
}

///|
/// 从 PNG 字节解码为 `RgbaImage`。
pub fn decode_png(raw : Bytes) -> Result[RgbaImage, String] {
  try {
    Ok(from_image_data(@image.decode_png(raw)))
  } catch {
    _ => Err("decode_png: invalid png data")
  }
}

///|
/// 将 `RgbaImage` 编码为 PNG 字节。
pub fn RgbaImage::encode_png(self : RgbaImage) -> Result[Bytes, String] {
  try {
    Ok(@image.encode_png(to_image_data(self)))
  } catch {
    _ => Err("encode_png: invalid image")
  }
}

///|
/// 从 JPEG 字节解码为 `RgbaImage`。
pub fn decode_jpeg(raw : Bytes) -> Result[RgbaImage, String] {
  try {
    Ok(from_image_data(@image.decode_jpeg(raw)))
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
    Ok(@image.encode_jpeg(to_image_data(self), quality~))
  } catch {
    _ => Err("encode_jpeg: invalid image")
  }
}

///|
/// 缩放图像。
///
/// 注意：`width` / `height` 必须为正数——非法尺寸会 **panic**（而非返回
/// 原图副本，避免调用方静默拿到错误结果）；`SampleMode` 决定采样方式
/// （`Nearest` 最近邻 / `Bilinear` 双线性）。
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
    from_image_data(@image.resize(to_image_data(self), width, height, m))
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
  if w <= 0 || h <= 0 || self.width == 0 || self.height == 0 {
    // 空目标或空源：返回 0×0 图（0 宽源下 `width - 1` 会得 -1 越界）
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
  // 源数据一次转 Bytes（避免每行全量拷贝），按行 blit 到裁剪画布
  let src = Bytes::from_array(self.data)
  for row in 0..<ch {
    let src_off = ((cy0 + row) * self.width + cx0) * 4
    let dst_off = row * cw * 4
    out.blit_from_bytes(dst_off, src, src_off, cw * 4)
  }
  { width: cw, height: ch, data: out, }
}
