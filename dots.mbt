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
pub fn RgbaImage::embed_dots(self : RgbaImage, cfg : DotConfig) -> RgbaImage {
  let alpha = clamp_opacity(cfg.opacity)
  if alpha == 0 {
    return self
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
  self
}

///|
/// 提取点阵水印：用同一 `cfg` 复现点位置，统计深色命中率（0.0~1.0）。
///
/// 命中判定：像素亮度（RGB 均值）低于 `brightness_threshold` 视为命中。
/// 用于验证水印是否存在 / 匹配某个 `seed`（溯源时不同接收者持有不同 `seed`）。
pub fn extract_dots(
  img : RgbaImage,
  cfg : DotConfig,
  brightness_threshold? : Int,
) -> Double {
  let thr = match brightness_threshold {
    Some(v) => v
    None => 128
  }
  let mut hits = 0
  let mut total = 0
  for (px, py) in dot_points(cfg, img.width, img.height) {
    // 提取与 embed 同公式（偶数对齐）；邻域容差兜住 2 倍缩放错位（dot_size=3 时 4×4）
    let size = cfg.dot_size + 1
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
    // 与 embed 对齐：embed 对越界格不画点，提取时也跳过（避免分母虚增）
    if checked {
      total += 1
      if any {
        hits += 1
      }
    }
  }
  if total == 0 {
    0.0
  } else {
    (hits * 1000 / total).to_double() / 1000.0
  }
}

///|
/// 按 `cfg` 计算全部落点坐标（embed 与 extract 共用，保证两侧公式一致）。
///
/// - 归一化网格 + PRNG 序列在此统一推进；任何一侧改动落点公式，另一侧
///   自动跟随，避免"改一处漏一处"导致的提取失配。
/// - 坐标已做偶数像素对齐（2 的幂次缩放下奇偶网格重合）；`grid_offset`
///   叠加在最终坐标上（可为负，越界点由调用侧按边界裁剪）。
fn dot_points(cfg : DotConfig, w : Int, h : Int) -> Array[(Int, Int)] {
  let cell_ratio = 0.08 // 单元边长占图宽的比例（≈ 原 8px @100px 的观感）
  let threshold = (cfg.density * 1000.0).to_int()
  let cols = (1.0 / cell_ratio).ceil().to_int()
  let mut st = seed_to_state(cfg.seed)
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
