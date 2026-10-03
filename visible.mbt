///|
/// 将文本渲染为 RGBA 位图。
///
/// - `color`：字形颜色，打包 RGBA `0xRRGGBBAA`；字形像素不透明时 alpha 取 255。
/// - `scale`（可选，默认 1）：点阵放大倍数，用最近邻放大。
/// - `provider`（可选，默认 `Ascii5x7`）：字形提供者，内置 `Cjk16` 支持中文点阵。
/// - 字符间距 1 像素（按各字符单元宽度累加，支持中英文混排）；
///   不支持的字形渲染为空白。
/// - 空文本返回 0×0 图像。
pub fn render_text(text : String, color : Int, scale? : Int) -> RgbaImage {
  let sc = match scale {
    Some(v) => if v > 0 { v } else { 1 }
    None => 1
  }
  render_text_with(text, color, Ascii5x7::new(), scale=sc)
}

///|
/// 带字形提供者的渲染（供自定义字形/`Cjk16` 使用）。
pub fn[T : GlyphProvider] render_text_with(
  text : String,
  color : Int,
  provider : T,
  scale? : Int,
) -> RgbaImage {
  let prov = provider
  let s = match scale {
    Some(v) => if v > 0 { v } else { 1 }
    None => 1
  }
  if text.length() == 0 {
    return RgbaImage::new(0, 0, 0)
  }
  let cw = prov.cell_width()
  let ch = prov.cell_height()
  // 游标式累计宽度：每个字符占 cw+1（1 像素间距），末尾去掉多余间距
  let mut w = 0
  for _, _ in text.iter2() {
    w = w + cw + 1
  }
  w = w - 1
  let img = RgbaImage::new(w * s, ch * s, 0x0000_0000)
  let mut x = 0
  for _, c in text.iter2() {
    match prov.glyph(c) {
      Some(g) =>
        for row in 0..<ch {
          let bits = g[row].to_int()
          for col in 0..<cw {
            if ((bits >> (cw - 1 - col)) & 1) == 1 {
              for sy in 0..<s {
                for sx in 0..<s {
                  img.set_pixel((x + col) * s + sx, row * s + sy, color | 0xFF)
                }
              }
            }
          }
        }
      None => ()
    }
    x = x + cw + 1
  }
  img
}

///|
/// 在图像指定位置叠加文本水印（原地修改并返回同一图像）。
///
/// 位置由 `TextConfig.x / y` 指定（水印左上角）；透明度仅由
/// `opacity` 控制（字形像素不透明）；越界部分自动裁剪。
pub fn RgbaImage::embed_text(self : RgbaImage, cfg : TextConfig) -> RgbaImage {
  let wm = match cfg.font {
    "cjk16" =>
      render_text_with(cfg.text, cfg.color, Cjk16::new(), scale=cfg.font_size)
    _ => render_text(cfg.text, cfg.color, scale=cfg.font_size) // 默认 ascii5x7
  }
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
