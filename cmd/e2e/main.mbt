///|
/// 真实场景端到端演示：直播贴片防搬运溯源全链路。
///
/// 链路：`assets/live_frame.png`（模拟直播画面）
///   → embed_all 贴片三件套（可见文本 + 点阵 seed=观众ID + DCT 承载 UID）
///   → PNG 保存（watermarked.png）
///   → JPEG q85 重编码（模拟平台转码/切片分发）
///   → 读回 → verify_dots / trace_dots / extract_dct 溯源验证
///
/// 用法：
///   moon run cmd/e2e                # 用仓库内 assets/live_frame.png
///   moon run cmd/e2e -- <your.png>  # 用任意图片跑同一链路
fn main {
  let args = @env.args()
  let in_path = if args.length() >= 2 { args[1] } else { "assets/live_frame.png" }
  match load_image(in_path) {
    Err(e) => println("error: \{e}")
    Ok(img) => {
      // 贴片三件套：平台名+时间戳（可见震慑）、点阵 seed=观众 ID（溯源）、
      // DCT UID（抗平台 JPEG 转码的取证载体）
      // v0.1.10 起 Cjk16 内置 ASCII/符号字形（96 个），中文+英文+数字混合文本一条水印完整渲染；
      // y=276 放在底部字幕条(316+)上方，避免被覆盖（cjk16 font_size=2 高 32px）
      let tcfg = @lib.TextConfig::with_font(
        "直播 LIVE UID-00421",
        8,
        276,
        2,
        0.5,
        0xFF00_00FF,
        "cjk16",
      )
      let dcfg = @lib.DotConfig::new(0.05, 3, 421L, 1.0, 0, 0)
      let payload = @utf8.encode("UID-00421".to_string_view())
      let opts : @lib.EmbedOptions = {
        text_cfg: Some(tcfg),
        dot_cfg: Some(dcfg),
        lsb_payload: None,
        lsb_key: None,
        dct_payload: Some(payload),
        dct_delta: 24,
      }
      match img.embed_all(opts) {
        Err(e) => println("embed failed: \{e}")
        Ok(marked) => {
          match save_image(marked, "docs/demo/e2e_watermarked.png") {
            Ok(_) => println("saved: docs/demo/e2e_watermarked.png")
            Err(e) => println("error: \{e}")
          }
          // 模拟平台转码：JPEG q85 → 读回
          match marked.encode_jpeg(85) {
            Err(e) => println("jpeg encode failed: \{e}")
            Ok(jpeg) => {
              match @lib.decode_jpeg(jpeg) {
                Err(e) => println("jpeg decode failed: \{e}")
                Ok(received) => {
                  match save_image(received, "docs/demo/e2e_jpeg.jpg") {
                    Ok(_) => println("saved: docs/demo/e2e_jpeg.jpg (模拟平台转码)")
                    Err(e) => println("error: \{e}")
                  }
                  // 溯源三问
                  let rate = @lib.extract_dots(received, dcfg)
                  println("1. verify_dots hit rate: \{rate} → \{if rate >= 0.9 { "PASS" } else { "FAIL" }}")
                  match @lib.extract_dct(received, delta=24) {
                    None => println("2. dct watermark NOT found (wrong delta / too heavy compression)")
                    Some(uid) => println("2. extract_dct UID: \{utf8_str(uid)} → 定位观众 421")
                  }
                  let c_a = @lib.DotConfig::new(0.05, 3, 1L, 1.0, 0, 0)
                  let c_b = @lib.DotConfig::new(0.05, 3, 2L, 1.0, 0, 0)
                  let c_c = @lib.DotConfig::new(0.05, 3, 421L, 1.0, 0, 0)
                  let idx = @lib.trace_dots(received, [c_a, c_b, c_c])
                  println(
                    "3. trace_dots → 候选索引 \{idx}（0=观众A 1=观众B 2=观众C seed421）→ \{if idx == 2 { "锁定观众 C" } else if idx >= 0 { "误锁" } else { "未命中" }}",
                  )
                }
              }
            }
          }
        }
      }
    }
  }
}

///|
/// 按扩展名读取图片。
fn load_image(path : String) -> Result[@lib.RgbaImage, String] {
  try {
    let bytes = @fs.read_file_to_bytes(path)
    if path.has_suffix(".png") {
      @lib.decode_png(bytes)
    } else if path.has_suffix(".jpg") || path.has_suffix(".jpeg") {
      @lib.decode_jpeg(bytes)
    } else {
      Err("unsupported input format: use .png / .jpg / .jpeg")
    }
  } catch {
    _ => Err("cannot read file: \{path}")
  }
}

///|
fn save_image(img : @lib.RgbaImage, path : String) -> Result[Unit, String] {
  let bytes = if path.has_suffix(".png") {
    img.encode_png()
  } else if path.has_suffix(".jpg") || path.has_suffix(".jpeg") {
    img.encode_jpeg(85)
  } else {
    return Err("unsupported output format")
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
/// Bytes → UTF-8 字符串（仅用于打印验证结果）。
fn utf8_str(b : Bytes) -> String {
  try {
    @utf8.decode(b[0:b.length()], ignore_bom=true)
  } catch {
    _ => "<non-utf8>"
  }
}
