///|
/// 将文本渲染为 RGBA 位图（内置 5×7 点阵字体）。
///
/// - `color`：字形颜色，打包 RGBA `0xRRGGBBAA`；字形像素不透明时 alpha 取 255。
/// - `scale`（可选，默认 1）：点阵放大倍数，用最近邻放大。
/// - 字符间距 1 像素；不支持的字形渲染为空白。
/// - 空文本返回 0×0 图像。
pub fn render_text(text : String, color : Int, scale? : Int) -> RgbaImage {
  let s = match scale {
    Some(v) => if v > 0 { v } else { 1 }
    None => 1
  }
  let n = text.length()
  if n == 0 {
    return RgbaImage::new(0, 0, 0)
  }
  let w = n * 6 * s - s
  let h = 7 * s
  let img = RgbaImage::new(w, h, 0x0000_0000)
  for i, c in text.iter2() {
    match glyph(c) {
      Some(g) => {
        for row in 0..<7 {
          let bits = g[row].to_int()
          for col in 0..<5 {
            if ((bits >> (4 - col)) & 1) == 1 {
              for sy in 0..<s {
                for sx in 0..<s {
                  img.set_pixel(i * 6 * s + col * s + sx, row * s + sy, color | 0xFF)
                }
              }
            }
          }
        }
      }
      None => ()
    }
  }
  img
}

///|
/// 在图像指定位置叠加文本水印（原地修改并返回同一图像）。
///
/// 位置由 `TextConfig.x / y` 指定（水印左上角）；透明度仅由
/// `opacity` 控制（字形像素不透明）；越界部分自动裁剪。
pub fn RgbaImage::embed_text(self : RgbaImage, cfg : TextConfig) -> RgbaImage {
  let wm = render_text(cfg.text, cfg.color, scale = cfg.font_size)
  let alpha = clamp_opacity(cfg.opacity)
  if alpha == 0 {
    return self
  }
  overlay_at(self, wm, cfg.x, cfg.y, alpha)
  self
}

///|
/// 将 0.0~1.0 的不透明度转换为 0~255，越界值钳制。
fn clamp_opacity(opacity : Double) -> Int {
  let v = (opacity * 255.0).to_int()
  if v < 0 {
    0
  } else if v > 255 {
    255
  } else {
    v
  }
}
