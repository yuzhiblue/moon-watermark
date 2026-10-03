///|
/// 将 `src` 图像以 `alpha`（0~255）混合叠加到 `self` 的 `(x, y)` 处。
///
/// `(x, y)` 为 `src` 左上角在目标图上的位置；越界部分自动裁剪；
/// `src` 的像素 alpha 参与混合，全透明像素跳过。
fn overlay_at(img : RgbaImage, src : RgbaImage, x : Int, y : Int, alpha : Int) -> Unit {
  for sy in 0..<src.height {
    let dy = y + sy
    if dy < 0 || dy >= img.height {
      continue
    }
    for sx in 0..<src.width {
      let dx = x + sx
      if dx < 0 || dx >= img.width {
        continue
      }
      let sp = src.get_pixel(sx, sy)
      let sa = sp & 0xFF
      if sa == 0 {
        continue
      }
      let eff = (sa * alpha) / 255
      if eff == 0 {
        continue
      }
      let dst = img.get_pixel(dx, dy)
      img.set_pixel(dx, dy, blend_pixel(dst, sp, eff))
    }
  }
}

///|
/// Logo 水印：将 `logo` 图像叠加到 `(x, y)` 处（原地修改并返回同一图像）。
///
/// - `logo` 的自身 alpha 参与混合（透明背景的 PNG 可直接使用）。
/// - `opacity`（0.0~1.0）控制整体透明度；越界部分自动裁剪。
pub fn RgbaImage::embed_logo(
  self : RgbaImage, logo : RgbaImage, x : Int, y : Int, opacity : Double
) -> RgbaImage {
  let alpha = clamp_opacity(opacity)
  if alpha == 0 {
    return self
  }
  overlay_at(self, logo, x, y, alpha)
  self
}

///|
/// 平铺水印：将 `TiledConfig.text` 渲染出的水印单元按间距平铺覆盖整张图
/// （原地修改并返回同一图像）。常用于防盗摄的全幅斜向/网格水印。
pub fn RgbaImage::embed_tiled(self : RgbaImage, cfg : TiledConfig) -> RgbaImage {
  let wm = render_text(cfg.text, cfg.color, scale = cfg.font_size)
  if wm.width == 0 || wm.height == 0 {
    return self
  }
  let alpha = clamp_opacity(cfg.opacity)
  if alpha == 0 {
    return self
  }
  let step_x = wm.width + cfg.spacing_x
  let step_y = wm.height + cfg.spacing_y
  if step_x <= 0 || step_y <= 0 {
    return self
  }
  let mut y = 0
  while y < self.height {
    let mut x = 0
    while x < self.width {
      overlay_at(self, wm, x, y, alpha)
      x += step_x
    }
    y += step_y
  }
  self
}
