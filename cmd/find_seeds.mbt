fn main {
  // 复现 gradient_h 128x128
  let size = 128
  let img = @lib.RgbaImage::new(size, size, 0xFF000000)
  for y in 0..<size {
    for x in 0..<size {
      let v = (x * 255) / (size - 1)
      img.set_pixel(x, y, (0xFF << 24) | (v << 16) | (v << 8) | v)
    }
  }
  for s in 1..<65 {
    let cfg = @lib.DotConfig::new(0.05, 3, Int64::from_int(s), 1.0, 0, 0)
    let c1 = @lib.dot_contrast(img, cfg, controls=1)
    let c8 = @lib.dot_contrast(img, cfg, controls=8)
    if c1 >= 0.4 || c8 >= 0.4 {
      println("seed=\{s}  single=\{c1}  multi8=\{c8}")
    }
  }
}
