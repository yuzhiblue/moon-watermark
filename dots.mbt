///|
/// 随机点阵水印：按 `DotConfig` 的归一化网格 + PRNG 布局，在全图散布深色点。
///
/// - 落点网格使用**归一化坐标**（单元边长 = 图宽 8%），点位置按比例跟随
///   图像尺寸——因此缩放（resize）后提取仍能命中，鲁棒性矩阵实测通过。
/// - 每个单元由 `seed` 驱动的确定性 PRNG 决定是否落点（`density` 为落点
///   单元概率）及点在单元内的偏移比例（叠加 `grid_offset_x / grid_offset_y`
///   像素偏移，非零偏移在缩放场景会有轻微漂移，建议默认 0）。
/// - 点颜色固定为深色（`0x0000_00FF`），半透明时由 `opacity` 控制；
///   同一配置（尤其同一 `seed`）嵌入结果完全一致，可被 `extract_dots` 复现。
pub fn RgbaImage::embed_dots(
  self : RgbaImage,
  cfg : DotConfig,
) -> Result[RgbaImage, String] {
  let alpha = clamp_opacity(cfg.opacity)
  if alpha == 0 {
    return Ok(self)
  }
  for (px, py) in dot_points(cfg, self.width, self.height) {
    for dy in 0..<cfg.dot_size {
      for dx in 0..<cfg.dot_size {
        let x = px + dx
        let y = py + dy
        if x >= 0 && y >= 0 && x < self.width && y < self.height {
          let dst = self.get_pixel(x, y)
          self.set_pixel(x, y, blend_pixel(dst, 0x0000_00FF, alpha))
        }
      }
    }
  }
  Ok(self)
}

///|
/// 提取点阵水印：用同一 `cfg` 复现点位置，统计深色命中率（0.0~1.0）。
///
/// 命中判定：像素亮度（RGB 均值）低于 `brightness_threshold` 视为命中。
/// **注意**：这是绝对命中率，不含基线对照——暗色调原图本身可能天然
/// 高命中（假阳性）。需要严谨判别的场景请用 `verify_dots` / `dot_contrast`
/// （成对对照，自动扣除原图暗区干扰）。
pub fn extract_dots(
  img : RgbaImage,
  cfg : DotConfig,
  brightness_threshold? : Int32,
) -> Double {
  let thr = match brightness_threshold {
    Some(v) => v
    None => 128
  }
  let (hits, total) = count_hits(img, dot_points(cfg, img.width, img.height), cfg.dot_size, thr)
  if total == 0 {
    0.0
  } else {
    hits.to_double() / total.to_double()
  }
}

///|
/// 成对对照判定（多对照组）：`目标点位命中率 − median(k 组对照点位命中率)`。
///
/// - **目标点位**：`cfg.seed` 派生的落点（即嵌入者实际画点处）；
/// - **对照点位**：由 `cfg.seed` 确定性派生的 k 组同密度随机落点
///   （第 j 组参照 seed = `seed ^ (GOLDEN * j)`，j=1..k；k=1 时与单对照
///   完全一致）。
///
/// 两者在同一张图上用同一亮度阈值统计，原图的暗区/纹理等系统性偏差
/// 同时作用于两侧，差值即"水印带来的真实信号"：
///
/// - 未嵌入图（含暗色原图）：目标命中率 ≈ 对照命中率 → contrast ≈ 0；
/// - 已嵌入图：目标点位与真水印重合（全暗）→ contrast 显著 > 0。
///
/// **为什么默认 k=8**：单对照组在空间结构图型（渐变、棋盘、色块）上存在
/// 残余方差——目标点位子集与个别对照子集的网格分布差异可造成 ≥0.4 的
/// 虚警（标定实验实测 17/1024 ≈ 1.7% 误报）。取 k 组对照的中位数可压制
/// 对照侧噪声，实测将误报降至 5/1024 ≈ 0.5%（见 `cmd/calibrate`）。
/// 注意：偏差也可能来自目标点位自身（如渐变图上目标子集偏于一侧），
/// 此时多对照无法完全消除——此类图型建议配合 `verify_dots` 的
/// `calibrated` 自标定模式，或列为点阵通道拒绝域。
pub fn dot_contrast(
  img : RgbaImage,
  cfg : DotConfig,
  controls? : Int,
  brightness_threshold? : Int32,
) -> Double {
  let thr = match brightness_threshold {
    Some(v) => v
    None => 128
  }
  let k = match controls {
    Some(v) => if v < 1 { 1 } else { v }
    None => 8
  }
  let (th, tt) = count_hits(img, dot_points(cfg, img.width, img.height), cfg.dot_size, thr)
  let target = if tt == 0 { 0.0 } else { th.to_double() / tt.to_double() }
  let rates : Array[Double] = []
  for j in 1..<(k + 1) {
    let rs = ref_seed_n(cfg.seed, j)
    let (rh, rt) = count_hits(
      img,
      dot_points_with_seed(cfg, img.width, img.height, rs),
      cfg.dot_size,
      thr,
    )
    rates.push(if rt == 0 { 0.0 } else { rh.to_double() / rt.to_double() })
  }
  rates.sort()
  let refr = if k % 2 == 1 {
    rates[k / 2]
  } else {
    (rates[k / 2 - 1] + rates[k / 2]) / 2.0
  }
  target - refr
}

///|
/// 统计一组点位的深色命中（embed 与 extract/contrast 共用，两侧公式一致）。
///
/// 邻域容差兜住 2 倍缩放错位（dot_size=3 时 4×4）；与 embed 对齐：
/// embed 对完全越界的格不画点，提取时也跳过（避免分母虚增）；
/// 部分越界的格 embed 已画界内部分，提取用邻域"任一像素在界内"即计入，两侧一致。
fn count_hits(
  img : RgbaImage,
  pts : Array[(Int32, Int32)],
  dot_size : Int32,
  thr : Int32,
) -> (Int32, Int32) {
  let mut hits = 0
  let mut total = 0
  for (px, py) in pts {
    let size = dot_size + 1
    let mut any = false
    let mut checked = false
    for dy in 0..<size {
      for dx in 0..<size {
        let x = px + dx
        let y = py + dy
        if x >= 0 && y >= 0 && x < img.width && y < img.height {
          checked = true
          let p = img.get_pixel(x, y)
          let r2 = (p >> 24) & 0xFF
          let g2 = (p >> 16) & 0xFF
          let b2 = (p >> 8) & 0xFF
          if (r2 + g2 + b2) / 3 < thr {
            any = true
          }
        }
      }
    }
    if checked {
      total += 1
      if any {
        hits += 1
      }
    }
  }
  (hits, total)
}

///|
/// 对照 seed：由目标 seed 确定性派生（黄金比例常数异或），保证同密度、
/// 同规模、位置与目标点位不相干；embed 不会使用此 seed，因此对照点位
/// 恒为"未画点处"。
///|
/// 多对照组参照 seed：第 j 组 = `seed ^ (GOLDEN * j)`。
/// j=1 时与单对照 `ref_seed`（旧实现）完全一致，保证 `controls=1` 的向后兼容。
fn ref_seed_n(seed : Int64, j : Int) -> Int64 {
  seed ^ (0x9E37_79B9_7F4A_7C15L * Int64::from_int(j))
}

///|
/// 按 `cfg` 计算全部落点坐标（embed 与 extract 共用，保证两侧公式一致）。
///
/// - 归一化网格 + PRNG 序列在此统一推进；任何一侧改动落点公式，另一侧
///   自动跟随，避免"改一处漏一处"导致的提取失配。
/// - 坐标已做偶数像素对齐（2 的幂次缩放下奇偶网格重合）；`grid_offset`
///   叠加在最终坐标上（可为负，越界点由调用侧按边界裁剪）。
fn dot_points(cfg : DotConfig, w : Int32, h : Int32) -> Array[(Int32, Int32)] {
  dot_points_with_seed(cfg, w, h, cfg.seed)
}

///|
/// 按指定 `seed` 计算全部落点坐标（embed/extract 用 `cfg.seed`，
/// 对照判定用 `ref_seed(cfg.seed)`——两侧共用同一落点公式，保证点
/// 规模/密度一致，仅位置由 seed 决定）。
fn dot_points_with_seed(
  cfg : DotConfig,
  w : Int32,
  h : Int32,
  seed : Int64,
) -> Array[(Int32, Int32)] {
  let cell_ratio = 0.08 // 单元边长占图宽的比例（≈ 原 8px @100px 的观感）
  // density clamp 到 [0,1]：<0 无点、>1 全图点；embed/extract 共用本函数故两侧一致
  let mut threshold = (cfg.density * 1000.0).to_int()
  if threshold < 0 {
    threshold = 0
  } else if threshold > 1000 {
    threshold = 1000
  }
  let cols = (1.0 / cell_ratio).ceil().to_int()
  let mut st = seed_to_state(seed)
  let pts = Array::make(0, (0, 0))
  for cy in 0..<cols {
    for cx in 0..<cols {
      st = xorshift64_next(st)
      let r = (st % 1000UL).to_int()
      if r < threshold {
        st = xorshift64_next(st)
        let oxr = (st % 800UL).to_double() / 800.0
        st = xorshift64_next(st)
        let oyr = (st % 800UL).to_double() / 800.0
        let ux = cell_ratio * (cx.to_double() + oxr)
        let uy = cell_ratio * (cy.to_double() + oyr)
        // 点坐标对齐偶数像素：2 的幂次缩放（Nearest）下奇偶网格重合，点不被采样丢弃
        let px = ((ux * w.to_double()).to_int() & -2) + cfg.grid_offset_x
        let py = ((uy * h.to_double()).to_int() & -2) + cfg.grid_offset_y
        pts.push((px, py))
      }
    }
  }
  pts
}
