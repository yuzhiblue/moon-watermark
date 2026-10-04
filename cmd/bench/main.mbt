///|
/// 性能基准：输出各尺寸 × 各水印操作的耗时（µs，中位数）。
///
/// 用法：
///   moon run cmd/bench --             # 全部尺寸（默认 320×240 … 1920×1080）
///   moon run cmd/bench -- 640 360     # 指定尺寸
///
/// 输出为 JSON 行（每项一行），字段来自 core `@bench.Summary`：
/// mean / median / min / max / std_dev / runs / batch_size（单位 µs）。
/// README「性能基准」章节的数据即由此命令复现。
fn main {
  let args = @env.args()
  let sizes = if args.length() >= 3 {
    let w = parse_int_or(args[1], 640)
    let h = parse_int_or(args[2], 360)
    [(w, h)]
  } else {
    [(320, 240), (640, 360), (1280, 720), (1920, 1080)]
  }
  for (w, h) in sizes {
    println("bench \{w}x\{h}")
    let img = make_texture(w, h)
    let tcfg = @lib.TextConfig::with_font(
      "LIVE 42",
      8,
      h - 8 - 2 * 16,
      2,
      0.6,
      0xFF00_00FF,
      "cjk16",
    )
    let dcfg = @lib.DotConfig::default()
    let payload = @utf8.encode("UID-000042".to_string_view())
    let opts : @lib.EmbedOptions = {
      text_cfg: Some(tcfg),
      dot_cfg: Some(dcfg),
      lsb_payload: Some(payload),
      lsb_key: Some(42L),
      dct_payload: None,
      dct_delta: 24,
    }
    bench("embed_text(cjk16)", () => { let _ = img.embed_text(tcfg) })
    bench("embed_dots", () => { let _ = img.embed_dots(dcfg) })
    bench("embed_invisible(lsb)", () => { let _ = img.embed_invisible(payload, key=42L) })
    bench("embed_dct(delta=24)", () => { let _ = img.embed_dct(payload, delta=24) })
    bench("embed_all(text+dots+lsb)", () => { let _ = img.embed_all(opts) })
    bench("encode_png", () => { let _ = img.encode_png() })
  }
}

///|
/// 生成渐变纹理测试图（模拟直播画面背景，避免纯色掩盖 DCT 耗时特征）。
fn make_texture(w : Int, h : Int) -> @lib.RgbaImage {
  let img = @lib.RgbaImage::new(w, h, 0xFF00_0000)
  for y in 0..<h {
    for x in 0..<w {
      let r = (x * 255 / (w - 1)).to_byte().to_int()
      let g = (y * 255 / (h - 1)).to_byte().to_int()
      let b = (96 + x * 63 / w).to_byte().to_int()
      img.set_pixel(x, y, (0xFF << 24) | (r << 16) | (g << 8) | b)
    }
  }
  img
}

///|
/// 跑单项基准并打印 JSON。
fn bench(name : String, f : () -> Unit) -> Unit {
  let s = @corebench.single_bench(name=name, f, count=10)
  println(@json.to_json(s).stringify(escape_slash=true))
}

///|
fn parse_int_or(s : String, d : Int) -> Int {
  try { @string.parse_int(s.to_string_view()) } catch { _ => d }
}
