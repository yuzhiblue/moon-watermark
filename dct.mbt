///|
/// DCT 域不可见水印：8×8 分块 DCT-II，中频系数 QIM（量化索引调制）嵌入。
///
/// 与 LSB 的取舍：LSB 抗无损但被 JPEG 量化破坏；DCT 域将 bit 编码进
/// 中频 DCT 系数的量化网格，JPEG 重压后系数仍在网格内即可提取——
/// 实测：纯色/低纹理图 q60 往返可提取（见 `dct_wbtest.mbt`）；自然纹理
/// 图 q85 默认 `delta=24` 通过，强压缩 q60 需 `delta=48`（见 CLI `--delta`）。
///
/// 布局（逐块 1 bit，按行主序）：[magic 2B "MD"] [len 2B] [payload]。
/// 嵌入系数固定为 (u=4, v=1)（中频、JPEG 量化步长适中）；量化步长
/// `delta` 默认 24，越大越鲁棒、可见性略升。

///|
/// 将 `payload` 以 DCT 域方式嵌入（原地修改）。容量 = 完整 8×8 块数 / 8 字节。
/// 量化步长默认值（QIM 网格）；`delta?` 未提供时取 24。embed/extract/detect 共用。
fn default_delta(delta : Int?) -> Int {
  match delta {
    Some(v) => v
    None => 24
  }
}

pub fn RgbaImage::embed_dct(
  self : RgbaImage,
  payload : Bytes,
  delta? : Int,
) -> Result[RgbaImage, String] {
  let d = default_delta(delta)
  let blocks = self.width / 8 * (self.height / 8)
  let need = 4 + payload.length()
  if need * 8 > blocks {
    return Err("payload too large: \{need}B > \{blocks / 8}B capacity")
  }
  // 明文帧：magic + len + payload（与 LSB 共用的帧布局，见 invisible.mbt `make_frame`）
  let frame = make_frame(b'M', b'D', payload)
  let mut bi = 0
  let total = need * 8
  for by in 0..<(self.height / 8) {
    if bi >= total {
      break
    }
    for bx in 0..<(self.width / 8) {
      if bi >= total {
        break
      }
      let bit = (frame[bi / 8].to_int() >> (bi % 8)) & 1
      self.embed_dct_bit(bx * 8, by * 8, bit, d)
      bi += 1
    }
  }
  Ok(self)
}

///|
/// 从图像提取 DCT 域水印；magic 校验失败返回 `None`。
pub fn extract_dct(img : RgbaImage, delta? : Int) -> Bytes? {
  let d = default_delta(delta)
  let blocks = img.width / 8 * (img.height / 8)
  match read_dct_head(img, d) {
    None => None
    Some((m0, m1, len)) => {
      let need = 4 + len
      if need * 8 > blocks {
        return None
      }
      // 用已还原的帧头重建明文帧，再读 payload 位
      let frame = FixedArray::make(need, (0).to_byte())
      frame[0] = m0
      frame[1] = m1
      frame[2] = ((len >> 8) & 0xFF).to_byte()
      frame[3] = (len & 0xFF).to_byte()
      fill_bits(
        frame,
        fn(bi) {
          let (x0, y0) = block_origin(img, bi)
          extract_dct_bit(img, x0, y0, d)
        },
        32,
        need * 8,
      )
      let out = Array::make(len, (0).to_byte())
      for i in 0..<len {
        out[i] = frame[4 + i]
      }
      Some(Bytes::from_array(out))
    }
  }
}

///|
/// 在 (x0, y0) 起的 8×8 块内嵌入 1 bit（QIM 到中频系数 (4,1)）。
fn RgbaImage::embed_dct_bit(
  self : RgbaImage,
  x0 : Int,
  y0 : Int,
  bit : Int,
  delta : Int,
) -> Unit {
  // 取亮度 Y（BT.601）到块矩阵——与 JPEG 编码的亮度分量一致（见 `block_luma`）
  let f = block_luma(self, x0, y0)
  let fk = dct_2d(f)
  // QIM：目标网格奇偶 = bit（偶=0，奇=1）；与原始网格至多差 1 格
  let q0 = (fk[4][1] / delta.to_double()).round().to_int()
  let tq = if bit == 1 { q0 | 1 } else { q0 & -2 }
  fk[4][1] = tq.to_double() * delta.to_double()
  let back = idct_2d(fk)
  for n in 0..<8 {
    for m in 0..<8 {
      // 亮度差 Δ 均摊到 RGB 三通道（同增 Δ → Y 增 Δ，色相近似保持）
      let d = back[n][m] - f[n][m]
      let p = self.get_pixel(x0 + m, y0 + n)
      let r = ((p >> 24) & 0xFF).to_double() + d
      let g = ((p >> 16) & 0xFF).to_double() + d
      let b = ((p >> 8) & 0xFF).to_double() + d
      let rv = if r < 0.0 { 0.0 } else if r > 255.0 { 255.0 } else { r }
      let gv = if g < 0.0 { 0.0 } else if g > 255.0 { 255.0 } else { g }
      let bv = if b < 0.0 { 0.0 } else if b > 255.0 { 255.0 } else { b }
      let np = (rv.to_int() << 24) | (gv.to_int() << 16) | (bv.to_int() << 8) |
        (p & 0xFF)
      self.set_pixel(x0 + m, y0 + n, np)
    }
  }
}

///|
/// 提取 1 bit：亮度域系数网格奇偶判定。
fn extract_dct_bit(img : RgbaImage, x0 : Int, y0 : Int, delta : Int) -> Int {
  let f = block_luma(img, x0, y0)
  let fk = dct_2d(f)
  let q0 = (fk[4][1] / delta.to_double()).round().to_int()
  q0 & 1
}

///|
/// 构造 8×8 独立行矩阵（FixedArray/Array 嵌套 make 会共享引用，必须逐行新建）。
fn dct8() -> Array[FixedArray[Double]] {
  let rows = Array(capacity=8)
  for _ in 0..<8 {
    rows.push(FixedArray::make(8, 0.0))
  }
  rows
}

///|
/// 8×8 DCT-II 正变换。
fn dct_2d(f : Array[FixedArray[Double]]) -> Array[FixedArray[Double]] {
  let out = dct8()
  for u in 0..<8 {
    for v in 0..<8 {
      let mut s = 0.0
      for n in 0..<8 {
        for m in 0..<8 {
          s = s + f[n][m] * cos_t(u, n) * cos_t(v, m)
        }
      }
      out[u][v] = 0.25 * dct_alpha(u) * dct_alpha(v) * s
    }
  }
  out
}

///|
/// 8×8 DCT-II 逆变换。
fn idct_2d(fk : Array[FixedArray[Double]]) -> Array[FixedArray[Double]] {
  let out = dct8()
  for n in 0..<8 {
    for m in 0..<8 {
      let mut s = 0.0
      for u in 0..<8 {
        for v in 0..<8 {
          s = s +
            dct_alpha(u) * dct_alpha(v) * fk[u][v] * cos_t(u, n) * cos_t(v, m)
        }
      }
      out[n][m] = 0.25 * s
    }
  }
  out
}

///|
/// DCT 基函数：cos(π(2n+1)u/16)。
fn cos_t(u : Int, n : Int) -> Double {
  @math.cos(PI * ((2 * n + 1) * u).to_double() / 16.0)
}

///|
/// 归一化因子：u=0 时 1/√2，否则 1。
fn dct_alpha(u : Int) -> Double {
  if u == 0 {
    1.0 / SQRT2
  } else {
    1.0
  }
}

///|
/// 块位流下标 → 8×8 块左上角坐标（行主序）。embed 的行列推进与
/// extract/detect 的下标换算共用同一公式，避免两侧坐标漂移。
fn block_origin(img : RgbaImage, bi : Int) -> (Int, Int) {
  let cols = img.width / 8
  ((bi % cols) * 8, (bi / cols) * 8)
}

///|
/// 盲检测：用给定 `delta` 读 DCT 帧头（magic + 长度合理性）判断是否含水印。
///
/// `delta` 需与嵌入时一致（可选，默认 24）——detect 与 extract 共用同一
/// 量化网格判定，两侧不一致会检不出（返回 false，属正常语义而非 bug）。
/// 用于拿疑似泄漏帧先判断是否被 DCT 标记，再决定深入提取。
pub fn detect_dct(img : RgbaImage, delta? : Int) -> Bool {
  let d = default_delta(delta)
  let blocks = img.width / 8 * (img.height / 8)
  match read_dct_head(img, d) {
    None => false
    Some((_, _, len)) => 4 + len <= blocks / 8
  }
}

///|
/// 读取 DCT 帧头（magic + 长度）：容量不足或 magic 不匹配返回 `None`。
/// `extract_dct` 与 `detect_dct` 共用——两侧头部解析必须同一套逻辑。
fn read_dct_head(img : RgbaImage, delta : Int) -> (Byte, Byte, Int)? {
  let blocks = img.width / 8 * (img.height / 8)
  if blocks < 32 {
    return None // 至少 4 字节头部
  }
  let head = FixedArray::make(4, (0).to_byte())
  fill_bits(
    head,
    fn(bi) {
      let (x0, y0) = block_origin(img, bi)
      extract_dct_bit(img, x0, y0, delta)
    },
    0,
    32,
  )
  if head[0] != b'M' || head[1] != b'D' {
    return None
  }
  Some((head[0], head[1], (head[2].to_int() << 8) | head[3].to_int()))
}

///|
/// 取 8×8 块的亮度矩阵 Y = 0.299R + 0.587G + 0.114B（BT.601）。
///
/// 与 JPEG 编码的亮度分量一致，DCT 系数才能经受 JPEG 量化往返
/// （G 通道会被色度量化破坏）；embed 与 extract 两侧共用，保证公式不漂移。
fn block_luma(img : RgbaImage, x0 : Int, y0 : Int) -> Array[FixedArray[Double]] {
  let f = dct8()
  for n in 0..<8 {
    for m in 0..<8 {
      let p = img.get_pixel(x0 + m, y0 + n)
      let r = (p >> 24) & 0xFF
      let g = (p >> 16) & 0xFF
      let b = (p >> 8) & 0xFF
      f[n][m] = (0.299 * r.to_double() + 0.587 * g.to_double() +
        0.114 * b.to_double())
    }
  }
  f
}

///|
/// 查询 DCT 通道可用 payload 容量（字节）：块数/8 再扣除 4 字节帧头。
///
/// 返回 0 或负数表示放不下（需更大的图或改走 LSB）；容量与 `embed_dct`
/// 的校验口径一致（`4 + len <= blocks / 8`）。
pub fn RgbaImage::dct_capacity(self : RgbaImage) -> Int {
  self.width / 8 * (self.height / 8) / 8 - 4
}
