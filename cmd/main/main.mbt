///|
/// 可运行示例：完整的水印工作流演示（内存闭环，不依赖文件系统）。
///
/// 流程：生成测试图 → 嵌入文本水印 → 嵌入点阵溯源水印 →
///       PNG 编码 → PNG 解码 → 提取点阵水印验证命中率。
fn main {
  // 1. 生成 320×240 渐变测试图
  let img = @lib.RgbaImage::new(320, 240, 0xFFFF_FFFF)
  for y in 0..<240 {
    for x in 0..<320 {
      let r = x * 255 / 319
      let g = y * 255 / 239
      img.set_pixel(x, y, (r << 16) | (g << 8) | 255)
    }
  }
  println("created 320x240 test image")

  // 2. 文本水印：模拟平台名 + 时间戳（直播贴片场景）
  let tcfg = @lib.TextConfig::new("LIVE 2026-10-03", 8, 8, 2, 0.6, 0xFF00_00FF)
  let _ = img.embed_text(tcfg)
  println("embedded text watermark")

  // 3. 点阵溯源水印：固定 seed = 观众/接收者 ID
  let dcfg = @lib.DotConfig::default()
  let _ = img.embed_dots(dcfg)
  println("embedded dot watermark (seed=\{dcfg.seed})")

  // 4. PNG 编码 → 解码（模拟导出再回收）
  let png = img.encode_png()
  match png {
    Ok(bytes) => {
      println("encoded png: \{bytes.length()} bytes")
      match @lib.decode_png(bytes) {
        Ok(back) => {
          // 5. 提取验证：点阵水印命中率应 ≥ 0.9
          let rate = @lib.extract_dots(back, dcfg)
          println("dot extraction hit rate: \{rate}")
          let ok = rate >= 0.9
          let verdict = if ok { "PASS" } else { "FAIL" }
          println("verification: \{verdict}")
        }
        Err(e) => println("decode failed: \{e}")
      }
    }
    Err(e) => println("encode failed: \{e}")
  }
}
