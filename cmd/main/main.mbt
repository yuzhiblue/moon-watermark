///|
/// moon-watermark 命令行入口。
///
/// 两种模式：
///  1. 无参数：内存闭环演示（生成渐变图 → 水印 → PNG 往返 → 提取验证）；
///  2. 文件模式：对真实图片文件嵌入 / 验证水印。
///
/// 用法：
///  ```
///  # 嵌入（默认文本水印 + 点阵溯源水印）
///  moon run cmd/main -- embed in.png out.png --text "LIVE 2026-10-03" --font cjk16
///  # 追加不可见水印（LSB，携带 ID）
///  moon run cmd/main -- embed in.jpg out.jpg --text "防搬运" --font cjk16 --lsb "UID-001" --key 42
///  # DCT 域水印（抗 JPEG 重压）
///  moon run cmd/main -- embed in.png out.png --dct "UID-001"
///  # 平铺水印（防盗摄全幅覆盖）
///  moon run cmd/main -- embed in.png out.png --tiled "请勿转载" --font cjk16
///  # 提取验证
///  moon run cmd/main -- verify-dots in.png --seed 42
///  moon run cmd/main -- verify-lsb in.png --key 42
///  moon run cmd/main -- verify-dct in.png
///  ```
///  输入输出格式由扩展名决定（.png / .jpg / .jpeg）；JPEG 输出默认质量 85。
fn main {
  let args = @env.args()
  if args.length() <= 1 {
    demo()
    return
  }
  match args[1] {
    "embed" => cmd_embed(args)
    "verify-dots" => cmd_verify_dots(args)
    "verify-lsb" => cmd_verify_lsb(args)
    "verify-dct" => cmd_verify_dct(args)
    _ =>
      println(
        "usage: moon run cmd/main -- embed <in> <out> [--text T --font ascii5x7|cjk16 --opacity N --seed N --lsb PAYLOAD --key N --dct PAYLOAD --tiled T] | verify-dots <in> [--seed N --density D --dot-size N] | verify-lsb <in> [--key N] | verify-dct <in>",
      )
  }
}

///|
/// 内存闭环演示（无文件 IO）。
fn demo() -> Unit {
  let img = @lib.RgbaImage::new(320, 240, 0xFFFF_FFFF)
  for y in 0..<240 {
    for x in 0..<320 {
      let r = x * 255 / 319
      let g = y * 255 / 239
      img.set_pixel(x, y, (r << 16) | (g << 8) | 255)
    }
  }
  println("created 320x240 test image")
  // 可见水印 embed_* 统一返回 Result（当前无失败路径，Ok 恒成立）
  let tcfg = @lib.TextConfig::new("LIVE", 8, 8, 2, 0.6, 0xFF00_00FF)
  let _ = img.embed_text(tcfg)
  println("embedded text watermark")
  let dcfg = @lib.DotConfig::default()
  let _ = img.embed_dots(dcfg)
  println("embedded dot watermark (seed=\{dcfg.seed})")
  let png = img.encode_png()
  match png {
    Ok(bytes) => {
      println("encoded png: \{bytes.length()} bytes")
      match @lib.decode_png(bytes) {
        Ok(back) => {
          let rate = @lib.extract_dots(back, dcfg)
          println("dot extraction hit rate: \{rate}")
          let ok = rate >= 0.9
          println("verification: \{if ok { "PASS" } else { "FAIL" }}")
        }
        Err(e) => println("decode failed: \{e}")
      }
    }
    Err(e) => println("encode failed: \{e}")
  }
}

///|
/// 解析整数参数；失败时返回默认值。
fn parse_int_or(s : String, d : Int) -> Int {
  try { @string.parse_int(s.to_string_view()) } catch { _ => d }
}

///|
/// 解析浮点参数；失败时返回默认值。
fn parse_double_or(s : String, d : Double) -> Double {
  try { @string.parse_double(s.to_string_view()) } catch { _ => d }
}

///|
/// 解析 64 位整数参数；失败时返回默认值。
fn parse_int64_or(s : String, d : Int64) -> Int64 {
  try { @string.parse_int64(s.to_string_view()) } catch { _ => d }
}

///|
/// 从命令行参数取 flag 值（`--name value`）。
fn flag_value(args : Array[String], name : String) -> String? {
  for i in 0..<args.length() {
    if args[i] == name && i + 1 < args.length() {
      return Some(args[i + 1])
    }
  }
  None
}

///|
/// 判断命令行是否包含 flag。
fn has_flag(args : Array[String], name : String) -> Bool {
  for i in 0..<args.length() {
    if args[i] == name {
      return true
    }
  }
  false
}

///|
/// 判断路径是否为 JPEG 扩展名（.jpg / .jpeg）。
fn is_jpeg(path : String) -> Bool {
  path.has_suffix(".jpg") || path.has_suffix(".jpeg")
}

///|
/// 按扩展名读取并解码图片（PNG / JPEG）。
fn load_image(path : String) -> Result[@lib.RgbaImage, String] {
  try {
    let bytes = @fs.read_file_to_bytes(path)
    if path.has_suffix(".png") {
      @lib.decode_png(bytes)
    } else if is_jpeg(path) {
      @lib.decode_jpeg(bytes)
    } else {
      Err("unsupported input format: use .png / .jpg / .jpeg")
    }
  } catch {
    _ => Err("cannot read file: \{path}")
  }
}

///|
/// 按扩展名编码并写入图片（PNG / JPEG，质量默认 85）。
fn save_image(img : @lib.RgbaImage, path : String) -> Result[Unit, String] {
  let bytes = if path.has_suffix(".png") {
    img.encode_png()
  } else if is_jpeg(path) {
    img.encode_jpeg(85)
  } else {
    return Err("unsupported output format: use .png / .jpg / .jpeg")
  }
  match bytes {
    Ok(b) => {
      try {
        @fs.write_bytes_to_file(path, b)
        Ok(())
      } catch {
        _ => Err("cannot write file: \{path}")
      }
    }
    Err(e) => Err(e)
  }
}

///|
/// 将命令行文本参数编码为 UTF-8 字节（`String::to_bytes` 是 UTF-16，不能直用）。
fn payload_bytes(s : String) -> Bytes {
  @utf8.encode(s.to_string_view())
}

///|
/// 逐字节打印 Bytes（规避 Bytes::to_string 的编码显示歧义）。
fn debug_bytes(b : Bytes) -> String {
  let parts = Array::make(0, "")
  for i in 0..<b.length() {
    parts.push(b[i].to_int().to_string())
  }
  parts.join(",")
}

///|
/// 从命令行参数解析 DotConfig（seed/density/dot-size 三参数；embed 与
/// verify-dots 共用同一解析逻辑，保证两侧默认值一致）。
fn dot_cfg_from_args(args : Array[String], opacity : Double) -> @lib.DotConfig {
  let seed = match flag_value(args, "--seed") {
    Some(v) => parse_int64_or(v, 42L)
    None => 42L
  }
  let density = match flag_value(args, "--density") {
    Some(v) => parse_double_or(v, 0.05)
    None => 0.05
  }
  let dot_size = match flag_value(args, "--dot-size") {
    Some(v) => parse_int_or(v, 3)
    None => 3
  }
  @lib.DotConfig::new(density, dot_size, seed, opacity, 0, 0)
}

///|
/// embed 子命令：读入图片 → 按 flag 嵌入水印 → 写出。
fn cmd_embed(args : Array[String]) -> Unit {
  if args.length() < 4 {
    println("usage: moon run cmd/main -- embed <in> <out> [flags]")
    return
  }
  let inp = args[2]
  let outp = args[3]
  match load_image(inp) {
    Err(e) => println("error: \{e}")
    Ok(img) => {
      // 文本水印（默认 "LIVE" + 点阵；位置右下角，避开不可见水印的左上角头部区）
      let text = match flag_value(args, "--text") {
        Some(v) => v
        None => "LIVE"
      }
      let font = match flag_value(args, "--font") {
        Some(v) => v
        None => "ascii5x7"
      }
      // 未知字体静默降级会误导用户：显式警告后回退
      if font != "ascii5x7" && font != "cjk16" {
        println("warning: unknown font '\{font}', fallback to ascii5x7")
      }
      let font_ok = if font == "cjk16" { font } else { "ascii5x7" }
      let opacity = match flag_value(args, "--opacity") {
        Some(v) => parse_double_or(v, 0.6)
        None => 0.6
      }
      let cell_h = if font_ok == "cjk16" { 16 } else { 7 }
      let ty = img.height - 8 - 2 * cell_h
      let ty_ok = if ty < 0 { 0 } else { ty }
      let _ = img.embed_text(
        @lib.TextConfig::with_font(text, 8, ty_ok, 2, opacity, 0xFF00_00FF, font_ok),
      )
      // 点阵溯源水印（默认 seed 42；--no-dots 关闭；--opacity 同时作用于点阵）
      if !has_flag(args, "--no-dots") {
        let dcfg = dot_cfg_from_args(args, opacity)
        let _ = img.embed_dots(dcfg)
      }
      // 可选 LSB 不可见水印（与 DCT 互斥：DCT 重写 G 通道会破坏 LSB，先警告）
      let has_lsb = flag_value(args, "--lsb") is Some(_)
      let has_dct = flag_value(args, "--dct") is Some(_)
      if has_lsb && has_dct {
        println(
          "warning: LSB and DCT are mutually exclusive (DCT rewrites luma, destroying LSB) — DCT skipped, LSB kept",
        )
      }
      match flag_value(args, "--lsb") {
        Some(payload) => {
          let key = match flag_value(args, "--key") {
            Some(v) => parse_int64_or(v, 0L)
            None => 0L
          }
          match img.embed_invisible(payload_bytes(payload), key=key) {
            Ok(_) => ()
            Err(e) => println("warning: LSB embed failed: \{e}")
          }
        }
        None => ()
      }
      // 可选 DCT 域水印（--delta 控制量化步长，默认 24；纹理图抗 JPEG 建议加大）
      match flag_value(args, "--dct") {
        Some(payload) if !has_lsb => {
          let delta = match flag_value(args, "--delta") {
            Some(v) => parse_int_or(v, 24)
            None => 24
          }
          match img.embed_dct(payload_bytes(payload), delta=delta) {
            Ok(_) => ()
            Err(e) => println("warning: DCT embed failed: \{e}")
          }
        }
        _ => ()
      }
      // 可选平铺水印
      match flag_value(args, "--tiled") {
        Some(ttext) => {
          let _ = img.embed_tiled(
            @lib.TiledConfig::new(ttext, 1, 40, 40, 0.25, 0xFF00_00FF, font=font),
          )
        }
        None => ()
      }
      match save_image(img, outp) {
        Ok(_) => println("saved: \{outp} (from \{inp})")
        Err(e) => println("error: \{e}")
      }
    }
  }
}

///|
/// verify-dots 子命令：按配置提取点阵水印命中率。
fn cmd_verify_dots(args : Array[String]) -> Unit {
  if args.length() < 3 {
    println(
      "usage: moon run cmd/main -- verify-dots <in> [--seed N --density D --dot-size N]",
    )
    return
  }
  let inp = args[2]
  match load_image(inp) {
    Err(e) => println("error: \{e}")
    Ok(img) => {
      let cfg = dot_cfg_from_args(args, 1.0)
      let rate = @lib.extract_dots(img, cfg)
      let verdict = if rate >= 0.9 { "PASS" } else { "FAIL" }
      println("dot hit rate: \{rate} (threshold 0.9) verdict: \{verdict}")
    }
  }
}

///|
/// verify-lsb 子命令：提取 LSB 水印并打印 payload。
fn cmd_verify_lsb(args : Array[String]) -> Unit {
  if args.length() < 3 {
    println("usage: moon run cmd/main -- verify-lsb <in> [--key N]")
    return
  }
  let inp = args[2]
  match load_image(inp) {
    Err(e) => println("error: \{e}")
    Ok(img) => {
      let key = match flag_value(args, "--key") {
        Some(v) => parse_int64_or(v, 0L)
        None => 0L
      }
      match @lib.extract_invisible(img, key=key) {
        Some(payload) => println("lsb payload bytes: \{debug_bytes(payload)}")
        None => println("lsb watermark not found (wrong key or absent)")
      }
    }
  }
}

///|
/// verify-dct 子命令：提取 DCT 水印并打印 payload。
fn cmd_verify_dct(args : Array[String]) -> Unit {
  if args.length() < 3 {
    println("usage: moon run cmd/main -- verify-dct <in> [--delta N]")
    return
  }
  let inp = args[2]
  match load_image(inp) {
    Err(e) => println("error: \{e}")
    Ok(img) => {
      let delta = match flag_value(args, "--delta") {
        Some(v) => parse_int_or(v, 24)
        None => 24
      }
      match @lib.extract_dct(img, delta=delta) {
        Some(payload) => println("dct payload bytes: \{debug_bytes(payload)}")
        None => println("dct watermark not found")
      }
    }
  }
}
