///|
/// 随机点阵水印：按 `DotConfig` 的网格 + PRNG 布局，在全图散布深色点。
///
/// - 图像按 8×8 单元划分网格；每个单元由 `seed` 驱动的确定性 PRNG
///   决定是否落点（`density` 控制落点单元比例）及点在单元内的偏移
///   （叠加 `grid_offset_x / grid_offset_y`）。
/// - 点颜色固定为深色（`0x0000_00FF`），半透明时由 `opacity` 控制；
///   同一配置（尤其同一 `seed`）嵌入结果完全一致，可被 `extract_dots` 复现。
pub fn RgbaImage::embed_dots(self : RgbaImage, cfg : DotConfig) -> RgbaImage {
  let cell = 8
  let alpha = clamp_opacity(cfg.opacity)
  let threshold = (cfg.density * 1000.0).to_int()
  let mut st = seed_to_state(cfg.seed)
  let cols = (self.width + cell - 1) / cell
  let rows = (self.height + cell - 1) / cell
  for cy in 0..<rows {
    for cx in 0..<cols {
      st = xorshift64_next(st)
      let r = (st % 1000UL).to_int()
      if r < threshold {
        st = xorshift64_next(st)
        let ox = (st % cell.to_uint64()).to_int() + cfg.grid_offset_x
        st = xorshift64_next(st)
        let oy = (st % cell.to_uint64()).to_int() + cfg.grid_offset_y
        let px = cx * cell + ox
        let py = cy * cell + oy
        for dy in 0..<cfg.dot_size {
          for dx in 0..<cfg.dot_size {
            let x = px + dx
            let y = py + dy
            if x < self.width && y < self.height {
              let dst = self.get_pixel(x, y)
              self.set_pixel(x, y, blend_pixel(dst, 0x0000_00FF, alpha))
            }
          }
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
pub fn extract_dots(img : RgbaImage, cfg : DotConfig, brightness_threshold? : Int) -> Double {
  let thr = match brightness_threshold {
    Some(v) => v
    None => 128
  }
  let cell = 8
  let mut st = seed_to_state(cfg.seed)
  let cols = (img.width + cell - 1) / cell
  let rows = (img.height + cell - 1) / cell
  let threshold = (cfg.density * 1000.0).to_int()
  let mut hits = 0
  let mut total = 0
  for cy in 0..<rows {
    for cx in 0..<cols {
      st = xorshift64_next(st)
      let r = (st % 1000UL).to_int()
      if r < threshold {
        st = xorshift64_next(st)
        let ox = (st % cell.to_uint64()).to_int() + cfg.grid_offset_x
        st = xorshift64_next(st)
        let oy = (st % cell.to_uint64()).to_int() + cfg.grid_offset_y
        let px = cx * cell + ox
        let py = cy * cell + oy
        for dy in 0..<cfg.dot_size {
          for dx in 0..<cfg.dot_size {
            let x = px + dx
            let y = py + dy
            if x < img.width && y < img.height {
              total += 1
              let p = img.get_pixel(x, y)
              let r2 = (p >> 24) & 0xFF
              let g2 = (p >> 16) & 0xFF
              let b2 = (p >> 8) & 0xFF
              if (r2 + g2 + b2) / 3 < thr {
                hits += 1
              }
            }
          }
        }
      }
    }
  }
  if total == 0 {
    0.0
  } else {
    (hits * 1000 / total).to_double() / 1000.0
  }
}
