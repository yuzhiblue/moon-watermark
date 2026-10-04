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
  // scale 的默认/归一化逻辑统一在 render_text_with 处理，这里只做转发
  // （MoonBit 可选参数不支持 option 透传，必须显式 match）
  match scale {
    Some(v) => render_text_with(text, color, Ascii5x7::new(), scale=v)
    None => render_text_with(text, color, Ascii5x7::new())
  }
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
/// 按 `font` 名称选择字形提供者渲染文本水印单元（embed_text / embed_tiled 共用）。
///
/// `font` 取 `"cjk16"`（中文点阵）或任意其他值（默认 ascii5x7 拉丁字形）。
fn render_text_by_font(
  text : String,
  color : Int,
  font : String,
  font_size : Int,
) -> RgbaImage {
  if font == "cjk16" {
    render_text_with(text, color, Cjk16::new(), scale=font_size)
  } else {
    render_text(text, color, scale=font_size)
  }
}

///|
/// 在图像指定位置叠加文本水印（原地修改并返回同一图像）。
///
/// 位置由 `TextConfig.x / y` 指定（水印左上角）；透明度仅由
/// `opacity` 控制（字形像素不透明）；`angle` 按度旋转（逆时针，
/// 0 = 不旋转，常用 45 做斜向防盗播水印）。
/// v0.1.11 起：水平/垂直文本（angle=0）越界不再静默裁剪——默认返回
/// `Err`，`auto_shrink=true` 时自动缩小字号适配画布；斜向文本（angle≠0）
/// 保留跨画布特性（45° 防盗播水印需要延伸出画布）。
pub fn RgbaImage::embed_text(
  self : RgbaImage,
  cfg : TextConfig,
) -> Result[RgbaImage, String] {
  // 超长文本会渲染出巨大位图（旋转时中间图按对角线尺寸分配，可至 GB 级）：
  // 文本水印定位是短标记，超过 512 字符视为调用错误
  if cfg.text.length() > 512 {
    return Err("text too long: \{cfg.text.length()} chars (max 512)")
  }
  let mut wm = render_text_by_font(cfg.text, cfg.color, cfg.font, cfg.font_size)
  // v0.1.11：水平/垂直文本（angle=0）越界防护——文本超宽/超高不再被静默裁剪：
  // 默认返回错误；TextConfig.auto_shrink=true 时自动缩小字号适配画布。
  // 斜向文本（angle≠0）保留跨画布特性（45° 防盗播水印本就需要延伸出画布），不检查。
  if cfg.angle == 0.0 {
    let need_w = wm.width
    let need_h = wm.height
    let avail_w = self.width - cfg.x
    let avail_h = self.height - cfg.y
    if need_w > avail_w || need_h > avail_h {
      if cfg.auto_shrink == false {
        return Err(
          "text watermark exceeds image bounds: needs \{need_w}x\{need_h}, \{avail_w}x\{avail_h} available at (\{cfg.x}, \{cfg.y}); set TextConfig.auto_shrink=true to fit, or shorten text / reduce font_size",
        )
      }
      // auto_shrink：按两个方向所需缩放取最小值，重新渲染
      // 注意：font_size<=0 时 render_text_by_font 内部归一化为 scale=1，此处必须用
      // 同一归一化值反推格宽/格高，否则 font_size=0 会除零崩溃
      let base = if cfg.font_size > 0 { cfg.font_size } else { 1 }
      let c_w = need_w / base // 字符总格宽（n × cell_w，整除）
      let c_h = need_h / base // 单行格高（cell_h，整除）
      if avail_w <= 0 || avail_h <= 0 || c_w <= 0 || c_h <= 0 {
        return Err(
          "text watermark position out of image bounds: needs \{need_w}x\{need_h}, \{avail_w}x\{avail_h} available at (\{cfg.x}, \{cfg.y})",
        )
      }
      let s_w = avail_w / c_w
      let s_h = avail_h / c_h
      let s = if s_w < s_h { s_w } else { s_h }
      if s < 1 {
        return Err(
          "text watermark cannot fit even at font_size=1: needs \{need_w}x\{need_h}, \{avail_w}x\{avail_h} available at (\{cfg.x}, \{cfg.y})",
        )
      }
      wm = render_text_by_font(cfg.text, cfg.color, cfg.font, s)
    }
  }
  if cfg.angle != 0.0 {
    wm = wm.rotate(cfg.angle)
  }
  let alpha = clamp_opacity(cfg.opacity)
  if alpha == 0 {
    return Ok(self)
  }
  overlay_at(self, wm, cfg.x, cfg.y, alpha)
  Ok(self)
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
