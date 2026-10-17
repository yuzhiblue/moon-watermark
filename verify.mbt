///|
/// 水印验证与溯源 API：在既有 embed/extract 之上提供统一入口族。

///|
/// 验证点阵水印是否存在：成对对照信号（`dot_contrast`）≥ `threshold`（默认 0.4）。
///
/// 与旧版"绝对命中率 ≥ 0.9"的区别：contrast 扣除同图随机对照点位的
/// 背景命中率，暗色调原图（直播暗场/夜景）不再因天然暗像素产生假阳性。
/// 默认阈值 0.4：无损/轻压缩场景 contrast≈1.0，JPEG q85 后≈0.5，未嵌入≈0。
/// 适用边界：原图背景暗像素占比不宜过高（如 >60%），否则嵌入的深色点
/// 与背景对比不足、contrast 偏低——点阵方案面向有内容的画面（直播/商品图），
/// 暗色画面可改走 DCT/LSB 通道溯源（见 `dct.mbt`）。
pub fn verify_dots(
  img : RgbaImage,
  cfg : DotConfig,
  threshold? : Double,
) -> Bool {
  let t = match threshold {
    Some(v) => v
    None => 0.4
  }
  dot_contrast(img, cfg) >= t
}

///|
/// 验证 LSB 不可见水印是否存在：能通过 magic 校验（含正确 key）即存在。
pub fn verify_invisible(img : RgbaImage, key? : Int64) -> Bool {
  match key {
    Some(k) => extract_invisible(img, key=k) is Some(_)
    None => extract_invisible(img) is Some(_)
  }
}

///|
/// 溯源：对候选 `DotConfig` 逐一计算成对对照信号（`dot_contrast`），
/// 返回信号最强且与次强之间有明确差距的候选索引。
///
/// - 返回 `-1`：无候选的信号达到 `threshold`（默认 0.4）——原图未嵌入
///   或候选均不匹配（含暗色原图干扰已被 contrast 扣除的情形）；
/// - 返回 `-2`：存在 ≥ threshold 的候选，但最高与次高信号差距
///   < `margin`（默认 0.15）——候选歧义，无法唯一确定来源，需人工复核；
/// - 返回 `>= 0`：唯一命中候选索引（真实分发来源）。
///
/// 直播溯源场景：每个接收者持有不同 seed 的配置，泄漏视频命中哪个
/// seed 即锁定对应接收者；歧义时宁可报告"无法确定"也不误锁。
pub fn trace_dots(
  img : RgbaImage,
  candidates : Array[DotConfig],
  threshold? : Double,
  margin? : Double,
) -> Int32 {
  let t = match threshold {
    Some(v) => v
    None => 0.4
  }
  let m = match margin {
    Some(v) => v
    None => 0.15
  }
  let mut best = -1
  let mut best_rate = 0.0
  let mut second_rate = 0.0
  for i in 0..<candidates.length() {
    let rate = dot_contrast(img, candidates[i])
    if rate > best_rate {
      second_rate = best_rate
      best_rate = rate
      best = i
    } else if rate > second_rate {
      second_rate = rate
    }
  }
  if best < 0 || best_rate < t {
    -1
  } else if best_rate - second_rate < m {
    -2
  } else {
    best
  }
}
