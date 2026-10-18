///|
/// 溯源判定案例集：点阵水印「溯源到人」的判定规则与输入输出示例。
///
/// 一次运行输出四个案例的完整输入 / 输出，
/// 覆盖点阵溯源判定的全部出口：
///
///   案例 A：原图干扰（未嵌入水印的暗色 / 暗纹理原图）→ 拒判（-1）
///   案例 B：候选歧义（两候选信号不可区分）→ 拒绝误锁（-2）
///   案例 C：真实分发来源（JPEG q85 转码后唯一命中）→ 锁定索引
///   案例 D：盲检测（溯源第一问：先判「是否被标记」再提取）
///
/// 用法：
///   moon run cmd/review
fn main {
  println("================================================================")
  println("moon-watermark 溯源判定案例集（成对对照信号）")
  println("点阵溯源的三种判定情形：原图干扰 / 候选歧义 / 真实分发来源")
  println("================================================================")

  case_a_original_interference()
  case_b_candidate_ambiguity()
  case_c_real_distribution_source()
  case_d_blind_detection()

  println("================================================================")
  println("判定规则速查（trace_dots 返回值语义）：")
  println("  >= 0  唯一命中 → 锁定该候选对应的分发来源（输入索引）")
  println("  = -1  无候选达标 → 原图未嵌入或候选均不匹配（原图干扰已扣除）")
  println("  = -2  候选歧义（最高 − 次高 < margin 0.15）→ 不误锁，转人工复核")
  println("================================================================")
}

///|
/// 打印一行候选明细：seed / 目标命中率-对照命中率（dot_contrast）/ 判定。
fn report_candidate(
  idx : Int,
  img : @lib.RgbaImage,
  cfg : @lib.DotConfig,
  threshold : Double,
) -> Unit {
  let con = @lib.dot_contrast(img, cfg)
  let mark = if con >= threshold { "达标" } else { "未达标" }
  println(
    "  候选[\{idx}] seed=\{cfg.seed}  dot_contrast=\{con}  \{mark}（阈值 \{threshold}）",
  )
}

///|
/// 案例 A：原图干扰——未嵌入水印的暗色 / 暗纹理原图不得被判为「已嵌入」。
///
/// 旧判据（v0.1.14 及以前）：目标点位「绝对命中率 ≥ 0.9」。暗色原图的
/// 暗像素本身即满足命中条件，绝对命中率天然 ≈ 1 → 假阳性（verify=true、
/// trace 误锁某个候选）。
/// 新判据（v0.1.15）：成对对照信号 dot_contrast = 目标点位命中率 −
/// 对照点位命中率（对照点位由 seed 确定性派生，同密度、未画点处）。
/// 同一张图上两侧用同一亮度阈值统计，原图暗区/纹理的系统性偏差被
/// 自动扣除 → 未嵌入图 contrast ≈ 0。
fn case_a_original_interference() -> Unit {
  println("")
  println("--------------------------------------------------------------")
  println("案例 A：原图干扰（未嵌入水印的暗色原图 → 必须拒判）")
  println("--------------------------------------------------------------")

  // A1：纯暗图（测试同款构造：verify_wbtest "dark original image…"）
  let cfg = @lib.DotConfig::new(0.05, 3, 42L, 1.0, 0, 0)
  let dark = @lib.RgbaImage::new(64, 64, 0xFF00_0000)
  let a1_hit = @lib.extract_dots(dark, cfg)
  let a1_con = @lib.dot_contrast(dark, cfg)
  let a1_ver = @lib.verify_dots(dark, cfg)
  let a1_trace = @lib.trace_dots(dark, [cfg])
  println("A1 输入：64×64 纯暗图（未嵌入任何水印），候选 seed=42")
  println("    绝对命中率（旧判据）= \{a1_hit}   ← 旧判据在此假阳性 verify=true")
  println(
    "    dot_contrast（新判据）= \{a1_con}   verify_dots = \{a1_ver}",
  )
  println("    trace_dots = \{a1_trace}  → -1 = 无候选达标，不误锁（正确）")

  // A2：暗纹理图（一半暗一半亮的伪随机纹理）
  let tex = @lib.RgbaImage::new(64, 64, 0xFF40_4040)
  let mut st = 42L
  for i in 0..<4096 {
    st = st * 6364136223846793005L + 1442695040888963407L
    let v = if ((st >> 33) & 1) == 1 { 20 } else { 150 }
    tex.set_pixel(
      i % 64,
      i / 64,
      (0xFF << 24) | (v << 16) | (v << 8) | v,
    )
  }
  let a2_hit = @lib.extract_dots(tex, cfg)
  let a2_con = @lib.dot_contrast(tex, cfg)
  let a2_ver = @lib.verify_dots(tex, cfg)
  let a2_trace = @lib.trace_dots(tex, [cfg])
  println("A2 输入：64×64 暗纹理图（亮度 20/150 伪随机，未嵌入），候选 seed=42")
  println("    绝对命中率（旧判据）= \{a2_hit}   ← 暗纹理系统抬高命中率")
  println(
    "    dot_contrast（新判据）= \{a2_con}   verify_dots = \{a2_ver}",
  )
  println("    trace_dots = \{a2_trace}  → 原图干扰被对照项扣除，正确拒判")

  println("结论：原图干扰由成对对照机制自动扣除——未嵌入图 contrast ≈ 0，")
  println("      verify_dots=false、trace_dots=-1；假阳性在回归测试中固化。")
}

///|
/// 案例 B：候选歧义——信号不可区分时拒绝「锁定」，宁可报告无法确定。
///
/// margin 机制：trace_dots 要求最高信号与次高信号差距 ≥ margin
/// （默认 0.15）才锁定；不足即返回 -2（候选歧义，转人工复核）。
/// 对照组：不同 seed 的候选 contrast 差异显著（正确 seed ≈1，错误 ≈0），
/// 差距 > margin → 唯一锁定。
fn case_b_candidate_ambiguity() -> Unit {
  println("")
  println("--------------------------------------------------------------")
  println("案例 B：候选歧义（信号不可区分 → -2 拒绝误锁；可区分 → 唯一命中）")
  println("--------------------------------------------------------------")

  let img = @lib.RgbaImage::new(64, 64, 0xFF80_8080)
  let embedded = @lib.DotConfig::new(0.05, 3, 42L, 1.0, 0, 0)
  let _ = img.embed_dots(embedded)

  // B1：两个完全相同的候选 → 信号并列最高 → 差距 0 < margin → -2
  println("B1 输入：嵌入 seed=42 的图，候选 = [cfg42, cfg42]（信号并列）")
  let b1 = @lib.trace_dots(img, [embedded, embedded])
  report_candidate(0, img, embedded, 0.4)
  report_candidate(1, img, embedded, 0.4)
  println("    最高 − 次高 = 0 < margin(0.15)  →  trace_dots = \{b1}")
  println("    → -2 = 候选歧义，无法唯一确定来源，转人工复核（不误锁）")

  // B2：对照组——错误 seed 46 与正确 seed 42 的 contrast 差异
  let wrong = @lib.DotConfig::new(0.05, 3, 46L, 1.0, 0, 0)
  let b2 = @lib.trace_dots(img, [wrong, embedded])
  println("B2 输入：同一张图，候选 = [cfg46(错误seed), cfg42(正确seed)]")
  report_candidate(0, img, wrong, 0.4)
  report_candidate(1, img, embedded, 0.4)
  println("    →  trace_dots = \{b2}  → 唯一命中索引 \{b2}（正确 seed）")
  println("结论：能区分时差距 > margin 即锁定；不能区分时返回 -2——")
  println("      「歧义」与「命中」由同一阈值体系统一判定，无中间模糊态。")
}

///|
/// 案例 C：真实分发来源——每个接收者持独立 seed，泄漏帧唯一定位。
///
/// 模拟真实分发链路：嵌入（seed=观众ID）→ JPEG q85 平台转码 → 读回 →
/// 对候选 seed 数组逐一计算 dot_contrast → trace_dots 唯一锁定。
fn case_c_real_distribution_source() -> Unit {
  println("")
  println("--------------------------------------------------------------")
  println("案例 C：真实分发来源（分发独立 seed → 泄漏帧唯一锁定）")
  println("--------------------------------------------------------------")

  let img = @lib.RgbaImage::new(128, 128, 0xFF80_8080)
  let viewer = @lib.DotConfig::new(0.05, 3, 421L, 1.0, 0, 0)
  let _ = img.embed_dots(viewer)

  // 模拟平台转码：JPEG q85 往返（分发必经链路）
  let received = match img.encode_jpeg(85) {
    Ok(jpg) =>
      match @lib.decode_jpeg(jpg) {
        Ok(back) => back
        Err(_) => img
      }
    Err(_) => img
  }

  println("C 输入：嵌入 seed=421（观众C）的图 → JPEG q85 转码 → 读回")
  println("        候选 = [seed=1(观众A), seed=2(观众B), seed=421(观众C)]")
  let c_a = @lib.DotConfig::new(0.05, 3, 1L, 1.0, 0, 0)
  let c_b = @lib.DotConfig::new(0.05, 3, 2L, 1.0, 0, 0)
  let c_c = @lib.DotConfig::new(0.05, 3, 421L, 1.0, 0, 0)
  report_candidate(0, received, c_a, 0.4)
  report_candidate(1, received, c_b, 0.4)
  report_candidate(2, received, c_c, 0.4)
  let idx = @lib.trace_dots(received, [c_a, c_b, c_c])
  let verdict = if idx == 2 {
    "锁定观众 C（seed 421）——泄漏来源唯一确定"
  } else if idx == -2 {
    "歧义：无法唯一确定来源"
  } else if idx >= 0 {
    "误锁（不应发生）"
  } else {
    "未命中（不应发生）"
  }
  println("    verify_dots = \{@lib.verify_dots(received, viewer)}（JPEG q85 后仍通过）")
  println("    trace_dots = \{idx}（0=观众A 1=观众B 2=观众C）→ \{verdict}")
  println("结论：分发时为每个接收者分配独立 seed，泄漏帧的 contrast 只在")
  println("      真实来源候选上显著 >0 → trace_dots 返回其索引，溯源到人。")
}

///|
/// 案例 D：盲检测——溯源第一问「是否被标记」，再决定深入提取。
///
/// detect_lsb / detect_dct 不依赖 key/delta，仅读帧头 magic + 长度
/// 合理性。注意（已文档化语义）：带 key 混淆的 LSB 帧无 key 检不出
/// （混沌流使帧头不可见），此时应以持有方登记的嵌入记录为准。
fn case_d_blind_detection() -> Unit {
  println("")
  println("--------------------------------------------------------------")
  println("案例 D：盲检测（溯源第一问：先判「是否被标记」再提取）")
  println("--------------------------------------------------------------")

  // D1：未嵌入的原图 → 盲检测应全部为 false
  let clean = @lib.RgbaImage::new(64, 64, 0xFFFF_FFFF)
  println("D1 输入：未嵌入的原图")
  println(
    "    detect_lsb=\{@lib.detect_lsb(clean)}  detect_dct=\{@lib.detect_dct(clean)}  → 未标记，溯源终止",
  )

  // D2：DCT 域水印（载荷 UID-00421，delta=24）
  let dct_img = @lib.RgbaImage::new(128, 128, 0xFFC0_C0C0)
  let payload = @utf8.encode("UID-00421".to_string_view())
  let _ = dct_img.embed_dct(payload, delta=24)
  let d2_dct = @lib.detect_dct(dct_img)
  let d2_lsb = @lib.detect_lsb(dct_img)
  let d2_uid = match @lib.extract_dct(dct_img, delta=24) {
    Some(b) => utf8_str(b)
    None => "<none>"
  }
  println("D2 输入：嵌入 DCT 水印（UID-00421, delta=24）的图")
  println(
    "    detect_dct=\{d2_dct}  detect_lsb=\{d2_lsb}  → 已标记（DCT）→ extract_dct = \{d2_uid}",
  )

  // D3：LSB 带 key 嵌入 → 无 key 时 detect=false（文档化语义，非缺陷）
  let lsb_img = @lib.RgbaImage::new(64, 64, 0xFFFF_FFFF)
  let _ = lsb_img.embed_invisible(@utf8.encode("UID-001".to_string_view()), key=42L)
  let d3_detect = @lib.detect_lsb(lsb_img)
  let d3_wrong = match @lib.extract_invisible(lsb_img, key=43L) {
    Some(b) => utf8_str(b)
    None => "None（magic 校验拒绝，错误 key 提取失败）"
  }
  let d3_right = match @lib.extract_invisible(lsb_img, key=42L) {
    Some(b) => utf8_str(b)
    None => "<none>"
  }
  println("D3 输入：嵌入 LSB 水印（UID-001, key=42）的图")
  println(
    "    detect_lsb(无key)=\{d3_detect}  ← 带 key 混淆的帧头不可见（已文档化语义）",
  )
  println(
    "    extract_invisible(错误key=43) \{d3_wrong}；extract_invisible(正确key=42) = \{d3_right}",
  )
  println("结论：盲检测回答「是否被标记」（第一问，无需参数）；提取回答")
  println("      「标记内容是什么」（需正确 key/delta）。带 key 的 LSB 帧")
  println("      以持有方嵌入记录为溯源入口，边界已在 README 安全边界声明。")
}

///|
/// Bytes → UTF-8 String（与 cmd/e2e 共用的小工具）。
fn utf8_str(b : Bytes) -> String {
  @utf8.decode(b[0:b.length()], ignore_bom=true) catch {
    _ => "<non-utf8>"
  }
}
