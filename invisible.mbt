///|
/// 不可见水印：LSB（最低有效位）嵌入 + key 派生 keystream 混淆。
///
/// 布局（按像素顺序，每像素 RGB 三个通道各 1 bit）：
///
///   [magic 2B "MW"] [len 2B 大端] [payload 混淆数据]
///
/// 嵌入前整体与 keystream XOR（keystream 由 `key` 经 xorshift64 派生；
/// `key` 为 `None` 时 keystream 全 0，即明文嵌入）。因此错误 key 会在
/// magic 校验处被拒绝（返回 `None`），可用于观众 ID 溯源鉴权。
/// 注意：LSB 提供隐蔽性，不提供强加密，密钥用于混淆与访问控制。

///|
/// 将 `payload`（如观众 ID）以 LSB 方式嵌入图像（原地修改）。
///
/// - 容量：`width × height × 3 / 8` 字节（含 4 字节头部）；超出返回 `Err`。
/// - `key`：可选混淆密钥，`None` 为明文嵌入。
/// - 返回 `Ok(图像)` / `Err(容量不足)`。
pub fn RgbaImage::embed_invisible(
  self : RgbaImage,
  payload : Bytes,
  key? : Int64,
) -> Result[RgbaImage, String] {
  let capacity = self.width * self.height * 3 / 8
  let need = 4 + payload.length()
  if need > capacity {
    return Err("payload too large: \{need} > capacity \{capacity}")
  }
  // 构造明文帧：magic + len + payload（Bytes 不可变，用 FixedArray 承载）
  let frame = make_frame(b'M', b'W', payload)
  // 混淆（keystream 覆盖整个 frame）
  let ks = keystream(key, need)
  for i in 0..<need {
    frame[i] = (frame[i].to_int() ^ ks[i].to_int()).to_byte()
  }
  // 逐位写入 RGB LSB（按行主序）
  let total_bits = need * 8
  for b in 0..<total_bits {
    let bit = (frame[b / 8].to_int() >> (b % 8)) & 1
    let pix = b / 3
    let x = pix % self.width
    let y = pix / self.width
    let p = self.get_pixel(x, y)
    let shift = lsb_shift(b) // R=16, G=8, B=0
    let cur = (p >> shift) & 0xFF
    let nv = (cur & 0xFE) | bit
    let np = (p & (-1 ^ (0xFF << shift))) | (nv << shift)
    self.set_pixel(x, y, np)
  }
  Ok(self)
}

///|
/// 从图像提取 LSB 不可见水印；magic 校验失败（含错误 key）返回 `None`。
pub fn extract_invisible(img : RgbaImage, key? : Int64) -> Bytes? {
  let capacity = img.width * img.height * 3 / 8
  match read_lsb_head(img, key) {
    None => None
    Some((_, _, len)) => {
      if 4 + len > capacity {
        return None
      }
      let total = 4 + len
      // 读完整混淆帧（头 + payload 位），整体 XOR 还原（帧头 magic 已由
      // read_lsb_head 校验过，这里一并还原到明文，payload 区正确）
      let frame = FixedArray::make(total, (0).to_byte())
      fill_bits(frame, fn(b) { read_bit(img, b).to_int() }, 0, total * 8)
      let ks = keystream(key, total)
      let out = Array::make(len, (0).to_byte())
      for i in 0..<total {
        frame[i] = (frame[i].to_int() ^ ks[i].to_int()).to_byte()
      }
      for i in 0..<len {
        out[i] = frame[4 + i]
      }
      Some(Bytes::from_array(out))
    }
  }
}

///|
/// 第 `b` 个水印位对应的通道位移（LSB 位流按像素行主序、RGB 三通道：
/// b%3=0→R(16), b%3=1→G(8), b%3=2→B(0)）。embed 与 extract 共用，公式不漂移。
fn lsb_shift(b : Int) -> Int {
  let ch = b % 3
  (2 - ch) * 8
}

/// 读取第 `b` 个水印位（对应像素 `b/3` 的通道 `b%3` 的 LSB）。
fn read_bit(img : RgbaImage, b : Int) -> Byte {
  let pix = b / 3
  let x = pix % img.width
  let y = pix / img.width
  let p = img.get_pixel(x, y)
  let shift = lsb_shift(b)
  ((p >> shift) & 0xFF & 1).to_byte()
}

///|
/// 构造水印帧：magic 2B + len 2B（大端）+ payload（LSB 与 DCT 共用）。
fn make_frame(m0 : Byte, m1 : Byte, payload : Bytes) -> FixedArray[Byte] {
  let need = 4 + payload.length()
  let frame = FixedArray::make(need, (0).to_byte())
  frame[0] = m0
  frame[1] = m1
  frame[2] = ((payload.length() >> 8) & 0xFF).to_byte()
  frame[3] = (payload.length() & 0xFF).to_byte()
  for i in 0..<payload.length() {
    frame[4 + i] = payload[i]
  }
  frame
}

///|
/// 将位流填充进帧：对 `[start, end)` 的每个位下标调用 `get_bit`，
/// 按 LSB 优先写入 `frame[b / 8]`（LSB 像素位流与 DCT 块位流共用组装逻辑）。
fn fill_bits(
  frame : FixedArray[Byte],
  get_bit : (Int) -> Int,
  start : Int,
  end : Int,
) -> Unit {
  for b in start..<end {
    frame[b / 8] = (frame[b / 8].to_int() | (get_bit(b) << (b % 8))).to_byte()
  }
}

///|
/// 由 key 派生 keystream：xorshift64 序列低 8 位；`None` 时全 0（明文模式）。
fn keystream(key : Int64?, len : Int) -> FixedArray[Byte] {
  let out = FixedArray::make(len, (0).to_byte())
  match key {
    Some(k) => {
      let mut st = seed_to_state(k)
      for i in 0..<len {
        st = xorshift64_next(st)
        out[i] = (st & 0xFFUL).to_int().to_byte()
      }
    }
    None => ()
  }
  out
}

///|
/// 盲检测：不依赖 key，仅读帧头 magic + 长度合理性判断图像是否含 LSB 水印。
///
/// 与 `extract_invisible` 的区别：不需要 key 即可回答"是否被标记"，适合
/// 拿到疑似泄漏帧时先判断、再决定是否用正确 key 深入提取（溯源第一问）。
/// 注意：若水印以非默认 key 混淆，magic 同样被 XOR，无 key 时可能检不出
/// （此时用 `extract_invisible(img)` 无 key 探测或先跑一次 key 枚举）。
pub fn detect_lsb(img : RgbaImage) -> Bool {
  let capacity = img.width * img.height * 3 / 8
  // 无混淆读头部（keystream(None) 为全 0 流，等价原样读取）
  match read_lsb_head(img, None) {
    None => false
    Some((_, _, len)) =>
      // 长度合理性：防 magic 偶然匹配但帧长荒谬的误检
      4 + len <= capacity
  }
}

///|
/// 读取 LSB 帧头（可选 key 混淆后还原）：magic 不匹配或容量不足返回 `None`。
/// `extract_invisible` 与 `detect_lsb` 共用——两侧头部解析必须同一套逻辑，
/// 避免"extract 改了 detect 没改"导致的误检/漏检。
fn read_lsb_head(img : RgbaImage, key : Int64?) -> (Byte, Byte, Int)? {
  if img.width * img.height * 3 / 8 < 4 {
    return None
  }
  // 读出混淆帧头部（4 字节），按 key 还原
  let head = FixedArray::make(4, (0).to_byte())
  fill_bits(head, fn(b) { read_bit(img, b).to_int() }, 0, 32)
  let ks = keystream(key, 4)
  for i in 0..<4 {
    head[i] = (head[i].to_int() ^ ks[i].to_int()).to_byte()
  }
  if head[0] != b'M' || head[1] != b'W' {
    return None
  }
  Some((head[0], head[1], (head[2].to_int() << 8) | head[3].to_int()))
}

///|
/// 查询 LSB 通道可用 payload 容量（字节）：扣除 4 字节帧头。
///
/// 返回值为 0 或负数表示该图放不下任何 payload（嵌入会返回 Err）——
/// 嵌入前用本函数规划"这条 payload 走 LSB 还是 DCT"。
pub fn RgbaImage::lsb_capacity(self : RgbaImage) -> Int {
  self.width * self.height * 3 / 8 - 4
}
