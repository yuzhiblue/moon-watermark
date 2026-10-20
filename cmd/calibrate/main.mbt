/// 标定实验：用数据回答「dot_contrast + margin 机制实际能支撑多强的结论」。
///
/// 实验一：单对照（controls=1，旧判据）在未嵌入图上的 contrast 分布 → 误报率基线。
/// 实验二：多对照（controls=8，现行默认）在同一批样本上的误报率对比。
/// 实验三：自标定显著性检验（多对照 + 本底对比）的误报率。
/// 实验四：溯源锁定质量——1 真 + 8 相邻错误 seed，三类出口占比。
///
/// 全部样本与 seed 固定，输出可复现；判据均调用库内公开 API。

let size : Int32 = 128

/// 伪随机数（LCG，固定初值保证可复现）
fn rng(st : Int64) -> Int64 {
  st * 6364136223846793005L + 1442695040888963407L
}

/// 均匀亮度图
fn uniform(v : Int32) -> @lib.RgbaImage {
  @lib.RgbaImage::new(size, size, (0xFF << 24) | (v << 16) | (v << 8) | v)
}

/// 双值噪声纹理：dark_frac 比例的像素为暗值，其余为亮值
fn noise(dark_frac : Double, dark : Int32, light : Int32) -> @lib.RgbaImage {
  let img = uniform(light)
  let mut st = 12345L
  let n = size * size
  for i in 0..<n {
    st = rng(st)
    if ((st >> 33) & 0x7FFFFFFFL).to_double() / 2147483648.0 < dark_frac {
      let v = (0xFF << 24) | (dark << 16) | (dark << 8) | dark
      img.set_pixel(i % size, i / size, v)
    }
  }
  img
}

/// 水平渐变
fn gradient_h() -> @lib.RgbaImage {
  let img = uniform(0)
  for y in 0..<size {
    for x in 0..<size {
      let v = (x * 255) / (size - 1)
      img.set_pixel(x, y, (0xFF << 24) | (v << 16) | (v << 8) | v)
    }
  }
  img
}

/// 垂直渐变
fn gradient_v() -> @lib.RgbaImage {
  let img = uniform(0)
  for y in 0..<size {
    let v = (y * 255) / (size - 1)
    for x in 0..<size {
      img.set_pixel(x, y, (0xFF << 24) | (v << 16) | (v << 8) | v)
    }
  }
  img
}

/// 水平条纹（周期 4，相位 phase 行为暗行）
fn pinstripe(phase : Int32) -> @lib.RgbaImage {
  let img = uniform(180)
  for y in 0..<size {
    if y % 4 == phase {
      for x in 0..<size {
        img.set_pixel(x, y, (0xFF << 24) | (30 << 16) | (30 << 8) | 30)
      }
    }
  }
  img
}

/// 4px 棋盘
fn checker() -> @lib.RgbaImage {
  let img = uniform(0)
  for y in 0..<size {
    for x in 0..<size {
      let v = if ((x / 4 + y / 4) % 2) == 0 { 30 } else { 200 }
      img.set_pixel(x, y, (0xFF << 24) | (v << 16) | (v << 8) | v)
    }
  }
  img
}

/// 内容式图：亮背景 + 若干暗矩形块（模拟文字/图形区域）
fn blocks() -> @lib.RgbaImage {
  let img = uniform(200)
  let mut st = 999L
  for _ in 0..<12 {
    st = rng(st)
    let bw = 8 + ((st >> 40) & 15L).to_int()
    let bh = 4 + ((st >> 24) & 7L).to_int()
    st = rng(st)
    let bx = (((st >> 40) & 0x7FFFFFFFL) % (size - bw).to_int64()).to_int()
    st = rng(st)
    let by = (((st >> 40) & 0x7FFFFFFFL) % (size - bh).to_int64()).to_int()
    for dy in 0..<bh {
      for dx in 0..<bw {
        img.set_pixel(bx + dx, by + dy, (0xFF << 24) | (25 << 16) | (25 << 8) | 25)
      }
    }
  }
  img
}

/// 图像类型清单：(名称, 构造器)
fn image_set() -> Array[(String, () -> @lib.RgbaImage)] {
  [
    ("uniform_0", fn() { uniform(0) }),
    ("uniform_80", fn() { uniform(80) }),
    ("uniform_160", fn() { uniform(160) }),
    ("uniform_240", fn() { uniform(240) }),
    ("noise_dark10", fn() { noise(0.1, 20, 150) }),
    ("noise_dark30", fn() { noise(0.3, 20, 150) }),
    ("noise_dark50", fn() { noise(0.5, 20, 150) }),
    ("noise_dark70", fn() { noise(0.7, 20, 150) }),
    ("gradient_h", fn() { gradient_h() }),
    ("gradient_v", fn() { gradient_v() }),
    ("pinstripe_p0", fn() { pinstripe(0) }),
    ("pinstripe_p1", fn() { pinstripe(1) }),
    ("pinstripe_p2", fn() { pinstripe(2) }),
    ("pinstripe_p3", fn() { pinstripe(3) }),
    ("checker4", fn() { checker() }),
    ("blocks", fn() { blocks() }),
  ]
}

/// 自标定本底：8 个独立 null seed 的 contrast 最大值（与库内 null_max 同规则）
fn null_max_of(img : @lib.RgbaImage, k : Int) -> Double {
  let mut mx = 0.4
  for j in 1..<9 {
    let s = 0x243F6A8885A308D3L + Int64::from_int(j) * 7919L
    let c = @lib.dot_contrast(
      img,
      @lib.DotConfig::new(0.05, 3, s, 1.0, 0, 0),
      controls=k,
    )
    if c > mx {
      mx = c
    }
  }
  mx
}

/// 实验一 + 实验二：单对照 vs 多对照 FPR（同一批 1024 未嵌入样本）
fn experiment_fpr() -> Unit {
  println("实验一/二：未嵌入图误报率（64 seed × 16 图型 = 1024 样本，阈值 0.4）")
  println("")
  let set = image_set()
  let mut fp1 = 0
  let mut fp8 = 0
  let mut max1 = 0.0
  let mut max8 = 0.0
  for i in 0..<set.length() {
    let (name, build) = set[i]
    let img = build()
    let mut f1 = 0
    let mut f8 = 0
    for s in 1..<65 {
      let cfg = @lib.DotConfig::new(0.05, 3, Int64::from_int(s), 1.0, 0, 0)
      let c1 = @lib.dot_contrast(img, cfg, controls=1)
      let c8 = @lib.dot_contrast(img, cfg, controls=8)
      if c1 >= 0.4 {
        f1 = f1 + 1
      }
      if c8 >= 0.4 {
        f8 = f8 + 1
      }
      if c1 > max1 {
        max1 = c1
      }
      if c8 > max8 {
        max8 = c8
      }
    }
    fp1 = fp1 + f1
    fp8 = fp8 + f8
    println("\{name}  单对照 FPR=\{f1}/64  多对照(k=8) FPR=\{f8}/64")
  }
  println("")
  println(
    "合计：单对照 FPR=\{fp1}/1024（max=\{max1}）  多对照(k=8) FPR=\{fp8}/1024（max=\{max8}）",
  )
}

/// 实验三：自标定显著性检验 FPR（多对照 + 本底对比）
fn experiment_calibrated_fpr() -> Unit {
  println("")
  println("实验三：自标定规则（c ≥ max(0.4, 本图 null 最大值 + 0.15)，多对照 k=8）")
  let set = image_set()
  let mut fpc = 0
  for i in 0..<set.length() {
    let (_, build) = set[i]
    let img = build()
    for s in 1..<65 {
      let cfg = @lib.DotConfig::new(0.05, 3, Int64::from_int(s), 1.0, 0, 0)
      let c = @lib.dot_contrast(img, cfg, controls=8)
      if c >= 0.4 {
        let nl = null_max_of(img, 8)
        if c >= nl + 0.15 {
          fpc = fpc + 1
        }
      }
    }
  }
  println("自标定后 FPR=\{fpc}/1024")
}

/// 实验四：溯源锁定质量（200 试验，1 真 + 8 相邻错误 seed，多对照默认）
fn experiment_trace() -> Unit {
  println("")
  println("实验四：溯源锁定质量（200 试验 × 2 条件，每试验 1 真 + 8 相邻错误 seed）")
  println("正确=trace 锁定真 seed；安全拒锁=trace=-2；误锁=trace 锁定错误 seed（最坏）；未检出=trace=-1")
  println("")
  for mode in 0..<2 {
    let label = if mode == 0 { "无损" } else { "JPEG q85 转码" }
    let mut correct = 0
    let mut refused = 0
    let mut mislock = 0
    let mut miss = 0
    for t in 0..<200 {
      let base = noise(0.1, 20, 190)
      let seed = 1000L + Int64::from_int(t) * 7L
      let cfg = @lib.DotConfig::new(0.05, 3, seed, 1.0, 0, 0)
      let marked = match base.embed_dots(cfg) {
        Ok(m) => m
        Err(_) => continue
      }
      let img = if mode == 0 {
        marked
      } else {
        match marked.encode_jpeg(85) {
          Ok(j) =>
            match @lib.decode_jpeg(j) {
              Ok(d) => d
              Err(_) => continue
            }
          Err(_) => continue
        }
      }
      let candidates = []
      for k in 0..<9 {
        let s = if k == 0 { seed } else { seed + Int64::from_int(k) }
        candidates.push(@lib.DotConfig::new(0.05, 3, s, 1.0, 0, 0))
      }
      match @lib.trace_dots(img, candidates) {
        0 => correct = correct + 1
        -2 => refused = refused + 1
        -1 => miss = miss + 1
        _ => mislock = mislock + 1
      }
    }
    println(
      "\{label}：正确=\{correct}/200  安全拒锁(-2)=\{refused}/200  误锁=\{mislock}/200  未检出(-1)=\{miss}/200",
    )
  }
  println("")
  println("注：实验背景为高频二值噪声纹理（10% 暗像素），属点阵通道拒绝域——")
  println("    该场景下深色命中统计被 3×3 邻域容差饱和，真信号本底仅 ~0.39。")
  println("    点阵通道的设计场景（平滑内容画面）请参考 cmd/e2e 与 README 鲁棒性矩阵。")
}

///| 主入口
fn main {
  println("================================================================")
  println("moon-watermark 判定机制标定实验（128×128，density=0.05，dot_size=3）")
  println("================================================================")
  experiment_fpr()
  experiment_calibrated_fpr()
  experiment_trace()
}
