///|
/// 不可见性度量：PSNR（峰值信噪比，dB）。
///
/// 量化水印嵌入前后图像的可感知差异——LSB 不可见水印通常 >40dB（肉眼
/// 不可察），可见水印显著低于此值。评审/验收时可直接用数字说明"嵌入
/// 是否可感知"。
pub fn psnr(orig : RgbaImage, marked : RgbaImage) -> Option[Double] {
  if orig.width != marked.width || orig.height != marked.height {
    return None
  }
  let mut sum = 0.0
  let n = orig.width * orig.height * 3
  for y in 0..<orig.height {
    for x in 0..<orig.width {
      let a = orig.get_pixel(x, y)
      let b = marked.get_pixel(x, y)
      let dr = ((a >> 24) & 0xFF) - ((b >> 24) & 0xFF)
      let dg = ((a >> 16) & 0xFF) - ((b >> 16) & 0xFF)
      let db = ((a >> 8) & 0xFF) - ((b >> 8) & 0xFF)
      sum = sum + (dr * dr + dg * dg + db * db).to_double()
    }
  }
  let mse = sum / n.to_double()
  if mse <= 0.000_001 {
    Some(1000000000.0) // 相同图：PSNR 无穷，用 1e9 表示
  } else {
    Some(10.0 * @math.log10(255.0 * 255.0 / mse))
  }
}
