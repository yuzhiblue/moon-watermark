///|
/// 水印验证与溯源 API：在既有 embed/extract 之上提供统一入口族。

///|
/// 自标定 null seed 基值：与候选 seed 派生链（GOLDEN 倍数异或）独立，
/// 8 个 null seed = BASE + j*7919，任意候选 seed 与之重合的概率可忽略，
/// 实现中仍做显式跳过防护。
const NULL_SEED_BASE : Int64 = 0x243F_6A88_85A3_08D3L

///|
/// 验证点阵水印是否存在：多对照成对信号（`dot_contrast`）≥ `threshold`（默认 0.4）。
///
/// 与旧版"绝对命中率 ≥ 0.9"的区别：contrast 扣除同图 k=8 组对照点位的
/// 中位数命中率，暗色调原图（直播暗场/夜景）与空间结构图型的背景偏差
/// 不再产生假阳性（标定实验：单对照误报 1.7% → 多对照 0.5%）。
/// 默认阈值 0.4：无损/轻压缩场景 contrast≈1.0，JPEG q85 后≈0.5，未嵌入≈0。
/// `calibrated=true` 时启用**图像自标定显著性检验**：除固定阈值外，还要求
/// contrast 超过该图自身本底（8 个独立 null seed 的 contrast 最大值 +
/// `significance_margin`，默认 0.15）——用于渐变/棋盘等目标点位自身偏斜
/// 的图型，进一步压制网格对齐类假阳性。
/// 适用边界：原图背景暗像素占比不宜过高（如 >60%），且高频二值纹理
/// （噪声图、密集文字截图）会让深色命中统计饱和——两类画面均属点阵
/// 通道拒绝域，应改走 DCT/LSB 通道溯源（见 `dct.mbt`）。
pub fn verify_dots(
  img : RgbaImage,
  cfg : DotConfig,
  threshold? : Double,
  controls? : Int,
  calibrated? : Bool,
  significance_margin? : Double,
) -> Bool {
  let t = match threshold {
    Some(v) => v
    None => 0.4
  }
  let k = match controls {
    Some(v) => if v < 1 { 1 } else { v }
    None => 8
  }
  let c = dot_contrast(img, cfg, controls=k)
  if c < t {
    return false
  }
  match calibrated {
    Some(true) => {
      let sm = match significance_margin {
        Some(v) => v
        None => 0.15
      }
      c >= null_max(img, cfg, k, t) + sm
    }
    _ => true
  }
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
/// 溯源：对候选 `DotConfig` 逐一计算多对照成对信号（`dot_contrast`），
/// 返回信号最强且与次强之间有明确差距的候选索引。
///
/// - 返回 `-1`：无候选的信号达到 `threshold`（默认 0.4）——原图未嵌入
///   或候选均不匹配（含暗色原图干扰已被 contrast 扣除的情形）；
/// - 返回 `-2`：存在 ≥ threshold 的候选，但最高与次高信号差距
///   < `margin`（默认 0.15）——候选歧义，无法唯一确定来源，需人工复核；
///   或 `calibrated=true` 时最高信号未显著超过本图本底；
/// - 返回 `>= 0`：唯一命中候选索引（真实分发来源）。
///
/// `calibrated=true` 时启用**图像自标定显著性检验**：最高候选还须超过
/// 该图自身本底（8 个独立 null seed 的 contrast 最大值 + margin）才输出
/// 指认，否则返回 -2——压制渐变/棋盘等目标点位自身偏斜导致的误锁。
///
/// 输出语义：`>=0` 表示「唯一强指向候选」，是**统计证据**而非最终裁决；
/// 最终归属判定应结合持有方分发台账交叉核验。直播溯源场景：每个接收者
/// 持有不同 seed 的配置，泄漏视频命中哪个 seed 即指向对应接收者；
/// 歧义时宁可报告"无法确定"也不误锁。
pub fn trace_dots(
  img : RgbaImage,
  candidates : Array[DotConfig],
  threshold? : Double,
  margin? : Double,
  controls? : Int,
  calibrated? : Bool,
) -> Int32 {
  let t = match threshold {
    Some(v) => v
    None => 0.4
  }
  let m = match margin {
    Some(v) => v
    None => 0.15
  }
  let k = match controls {
    Some(v) => if v < 1 { 1 } else { v }
    None => 8
  }
  let mut best = -1
  let mut best_rate = 0.0
  let mut second_rate = 0.0
  for i in 0..<candidates.length() {
    let rate = dot_contrast(img, candidates[i], controls=k)
    if rate > best_rate {
      second_rate = best_rate
      best_rate = rate
      best = i
    } else if rate > second_rate {
      second_rate = rate
    }
  }
  if best < 0 || best_rate < t {
    return -1
  }
  if best_rate - second_rate < m {
    return -2
  }
  match calibrated {
    Some(true) =>
      if best_rate >= null_max(img, candidates[best], k, t) + m {
        best
      } else {
        -2
      }
    _ => best
  }
}

///|
/// 图像自标定本底：以 `tmpl` 为模板（density/dot_size/offset 与候选一致，
/// 仅替换 seed），用 8 个独立 null seed 在当前图上计算 contrast 的最大值。
/// 用于显著性检验——候选信号必须显著高于本图"未嵌入时的噪声地板"。
fn null_max(img : RgbaImage, tmpl : DotConfig, k : Int, floor : Double) -> Double {
  let mut mx = floor
  for j in 1..<9 {
    let s = NULL_SEED_BASE + Int64::from_int(j) * 7919L
    if s == tmpl.seed {
      continue
    }
    let c = dot_contrast(
      img,
      { ..tmpl, seed: s },
      controls=k,
    )
    if c > mx {
      mx = c
    }
  }
  mx
}
