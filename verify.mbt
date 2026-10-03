///|
/// 水印验证与溯源 API：在既有 embed/extract 之上提供统一入口族。

///|
/// 验证点阵水印是否存在：`extract_dots` 命中率 ≥ `threshold`（默认 0.9）。
pub fn verify_dots(img : RgbaImage, cfg : DotConfig, threshold? : Double) -> Bool {
  let t = match threshold {
    Some(v) => v
    None => 0.9
  }
  extract_dots(img, cfg) >= t
}

///|
/// 验证 LSB 不可见水印是否存在：能通过 magic 校验（含正确 key）即存在。
pub fn verify_invisible(img : RgbaImage, key? : Int64) -> Bool {
  match key {
    Some(k) => extract_invisible(img, key = k) is Some(_)
    None => extract_invisible(img) is Some(_)
  }
}

///|
/// 溯源：对候选 `DotConfig` 逐一提取命中率，返回最高命中率候选的索引。
///
/// 候选为空或最高命中率低于 `threshold`（默认 0.9）时返回 -1。
/// 直播溯源场景：每个接收者持有不同 seed 的配置，泄漏视频命中哪个
/// seed 即锁定对应接收者。
pub fn trace_dots(img : RgbaImage, candidates : Array[DotConfig], threshold? : Double) -> Int {
  let t = match threshold {
    Some(v) => v
    None => 0.9
  }
  let mut best = -1
  let mut best_rate = 0.0
  for i in 0..<candidates.length() {
    let rate = extract_dots(img, candidates[i])
    if rate > best_rate {
      best_rate = rate
      best = i
    }
  }
  if best >= 0 && best_rate >= t {
    best
  } else {
    -1
  }
}
