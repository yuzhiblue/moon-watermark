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
    let ch = b % 3
    let x = pix % self.width
    let y = pix / self.width
    let p = self.get_pixel(x, y)
    let shift = (2 - ch) * 8 // R=16, G=8, B=0
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
  if capacity < 4 {
    return None
  }
  // 读出混淆帧头部（4 字节）
  let head = FixedArray::make(4, (0).to_byte())
  fill_bits(head, fn(b) { read_bit(img, b).to_int() }, 0, 32)
  let ks_head = keystream(key, 4)
  for i in 0..<4 {
    head[i] = (head[i].to_int() ^ ks_head[i].to_int()).to_byte()
  }
  if head[0] != b'M' || head[1] != b'W' {
    return None
  }
  let len = (head[2].to_int() << 8) | head[3].to_int()
  if 4 + len > capacity {
    return None
  }
  let total = 4 + len
  let frame = FixedArray::make(total, (0).to_byte())
  for i in 0..<4 {
    frame[i] = head[i]
  }
  fill_bits(frame, fn(b) { read_bit(img, b).to_int() }, 32, total * 8)
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

///|
/// 读取第 `b` 个水印位（对应像素 `b/3` 的通道 `b%3` 的 LSB）。
fn read_bit(img : RgbaImage, b : Int) -> Byte {
  let pix = b / 3
  let ch = b % 3
  let x = pix % img.width
  let y = pix / img.width
  let p = img.get_pixel(x, y)
  let shift = (2 - ch) * 8
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
