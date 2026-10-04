///|
/// 组合嵌入：一次调用按 `EmbedOptions` 依次叠加可见水印（文本/点阵）与
/// 不可见水印（LSB 或 DCT）。把 CLI 的组合逻辑库化，供逐帧应用（如直播
/// 贴片）复用——构造一次 `EmbedOptions`，对每帧调用 `embed_all`。
///
/// 组合顺序与约束：
/// 1. 可见水印先嵌（文本 → 点阵），不可见水印最后（避免覆盖其头部区）；
/// 2. **LSB 与 DCT 互斥**——DCT 重写亮度分量会破坏 LSB，同时指定返回
///    `Err`（与 CLI 的"保留 LSB 跳过 DCT"策略不同：库 API 不静默降级）；
/// 3. 任一子嵌入失败（如 payload 超容量）立即返回 Err，不产生半成品。

///|
/// 一次组合嵌入的完整配置。未启用的通道置 `None`：
///
/// ```mbt
/// let opts = {
///   text_cfg: Some(tcfg),
///   lsb_payload: Some(payload),
///   lsb_key: 7L,
///   dot_cfg: None,
///   dct_payload: None,
///   dct_delta: 24,
/// }
/// ```
pub struct EmbedOptions {
  text_cfg : Option[TextConfig]
  dot_cfg : Option[DotConfig]
  lsb_payload : Option[Bytes]
  lsb_key : Option[Int64] // None = 明文帧（无混淆，detect_lsb 可直接检出）
  dct_payload : Option[Bytes]
  dct_delta : Int
}

///|
/// 全通道关闭的默认配置（各字段含义见 [`EmbedOptions`]）。
pub fn EmbedOptions::default() -> EmbedOptions {
  {
    text_cfg: None,
    dot_cfg: None,
    lsb_payload: None,
    lsb_key: None,
    dct_payload: None,
    dct_delta: 24,
  }
}

///|
/// 按配置组合嵌入水印并返回新图像（原图不变）。
pub fn RgbaImage::embed_all(
  self : RgbaImage,
  opts : EmbedOptions,
) -> Result[RgbaImage, String] {
  let mut img = self
  match opts.text_cfg {
    Some(c) =>
      match img.embed_text(c) {
        Ok(m) => img = m
        Err(e) => return Err(e)
      }
    None => ()
  }
  match opts.dot_cfg {
    Some(c) =>
      match img.embed_dots(c) {
        Ok(m) => img = m
        Err(e) => return Err(e)
      }
    None => ()
  }
  // LSB 与 DCT 互斥：DCT 重写亮度分量会破坏 LSB，库 API 明确报错而非静默降级
  if opts.lsb_payload is Some(_) && opts.dct_payload is Some(_) {
    return Err("lsb and dct cannot be embedded together (dct rewrites luma, destroying lsb)")
  }
  match opts.lsb_payload {
    Some(p) => {
      let r = match opts.lsb_key {
        Some(k) => img.embed_invisible(p, key=k)
        None => img.embed_invisible(p)
      }
      match r {
        Ok(m) => img = m
        Err(e) => return Err(e)
      }
    }
    None => ()
  }
  match opts.dct_payload {
    Some(p) =>
      match img.embed_dct(p, delta=opts.dct_delta) {
        Ok(m) => img = m
        Err(e) => return Err(e)
      }
    None => ()
  }
  Ok(img)
}
