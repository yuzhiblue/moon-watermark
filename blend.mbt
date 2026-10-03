///|
/// 标准 alpha 混合：将 `src` 以不透明度 `alpha` 叠加到 `dst` 上。
///
/// 逐通道计算：`out = (src * a + dst * (255 - a)) / 255`，
/// 输入输出均为打包 RGBA 颜色 `0xRRGGBBAA`，`alpha` 取值 0~255。
pub fn blend_pixel(dst : Int, src : Int, alpha : Int) -> Int {
  let a = if alpha < 0 { 0 } else if alpha > 255 { 255 } else { alpha }
  let inv = 255 - a
  let dr = (dst >> 24) & 0xFF
  let dg = (dst >> 16) & 0xFF
  let db = (dst >> 8) & 0xFF
  let da = dst & 0xFF
  let sr = (src >> 24) & 0xFF
  let sg = (src >> 16) & 0xFF
  let sb = (src >> 8) & 0xFF
  let sa = src & 0xFF
  let or = (sr * a + dr * inv) / 255
  let og = (sg * a + dg * inv) / 255
  let ob = (sb * a + db * inv) / 255
  let oa = (sa * a + da * inv) / 255
  (or << 24) | (og << 16) | (ob << 8) | oa
}
