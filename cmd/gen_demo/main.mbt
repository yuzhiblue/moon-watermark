///|
/// 演示图生成器：输出三张 PNG（hex 编码，每行一个标签）。
/// 1) clean    — 渐变底图（模拟直播画面）
/// 2) lsb      — 嵌入不可见水印（观众 ID，视觉无差别）
/// 3) visible  — 叠加点阵 + 文本水印（可见防去重）
fn main {
  let base = make_gradient(512, 288)
  print_line("clean", png_hex(base))
  let _ = base.embed_invisible(Bytes::from_array([b'V', b'I', b'E', b'W', b'E', b'R', b'-', b'0', b'4', b'2', b'1']), key = 99L)
  print_line("lsb", png_hex(base))
  let _ = base.embed_dots(@lib.DotConfig::default())
  let _ = base.embed_text(@lib.TextConfig::new("LIVE 2026-10-03", 16, 16, 3, 0.6, 0xFFFF_FFFF))
  print_line("visible", png_hex(base))
  trace_demo()
}

///|
fn make_gradient(w : Int, h : Int) -> @lib.RgbaImage {
  let img = @lib.RgbaImage::new(w, h, 0)
  for y in 0..<h {
    for x in 0..<w {
      let r = (x * 255 / (w - 1)) & 0xFF
      let g = (y * 255 / (h - 1)) & 0xFF
      let b = 96 + (x * 63 / w)
      let rgba = (0xFF << 24) | (r << 16) | (g << 8) | b
      img.set_pixel(x, y, rgba)
    }
  }
  img
}

///|
fn png_hex(img : @lib.RgbaImage) -> String {
  match img.encode_png() {
    Ok(bytes) => to_hex(bytes)
    Err(e) => "ERR:\{e}"
  }
}

fn print_line(tag : String, hex : String) -> Unit {
  println("\{tag}:\{hex}")
}

///|
fn to_hex(bytes : Bytes) -> String {
  let mut s = ""
  for i in 0..<bytes.length() {
    let b = bytes[i].to_int()
    s = s + digit(b >> 4) + digit(b & 0xF)
  }
  s
}

///|
fn digit(n : Int) -> String {
  if n < 10 { (n + 48).unsafe_to_char().to_string() } else { (n + 87).unsafe_to_char().to_string() }
}

///|
/// 溯源演示数据：三位接收者持不同 seed，泄漏帧命中 seed=42（接收者 C）。
fn trace_demo() -> Unit {
  let leak = make_gradient(512, 288)
  let _ = leak.embed_dots(@lib.DotConfig::default()) // 接收者 C 的配置
  let c_a = @lib.DotConfig::new(0.05, 1, 1L, 1.0, 0, 0)
  let c_b = @lib.DotConfig::new(0.05, 1, 2L, 1.0, 0, 0)
  let c_c = @lib.DotConfig::default()
  print_line("trace_a", @lib.extract_dots(leak, c_a).to_string())
  print_line("trace_b", @lib.extract_dots(leak, c_b).to_string())
  print_line("trace_c", @lib.extract_dots(leak, c_c).to_string())
  print_line("trace_idx", @lib.trace_dots(leak, [c_a, c_b, c_c]).to_string())
}
