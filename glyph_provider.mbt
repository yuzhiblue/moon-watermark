///|
/// 字形提供者接口：把"文本水印渲染"与"具体字形来源"解耦。
///
/// 内置两个实现：
/// - [`Ascii5x7`]：5×7 拉丁字形（A-Z、0-9、常用符号），适合英文/数字水印；
/// - [`Cjk16`]：16×16 中文点阵（**GB2312 一级常用汉字 3755 个**，Noto CJK 生成），
///   适合中文水印（如"防盗播""请勿转载"）。
///
/// 第三方可自行实现 `GlyphProvider`（如接入完整字库、可变字体），
/// 传入 [`render_text`] 的 `provider` 参数即可。

///|
/// 字形提供者：按字符返回点阵位图。
///
/// 点阵约定：每行一个字节，低 `cell_width` 位为像素，位 `cell_width - 1`
/// 为最左像素（与内置 5×7 表一致）；行数 = `cell_height`。
pub trait GlyphProvider {
  /// 单元宽度（像素）
  fn cell_width(Self) -> Int
  /// 单元高度（像素）
  fn cell_height(Self) -> Int
  /// 字符点阵；不支持的字符返回 `None`（渲染为空白）
  fn glyph(Self, Char) -> FixedArray[Byte]?
}

///|
/// 内置 5×7 ASCII 字形提供者。
pub enum Ascii5x7 {
  Ascii5x7
}

///|
/// 构造 `Ascii5x7`。
pub fn Ascii5x7::new() -> Ascii5x7 {
  Ascii5x7::Ascii5x7
}

///|
/// 内置 16×16 中文点阵提供者（GB2312 一级字 3755 个，覆盖常用汉字）。
pub enum Cjk16 {
  Cjk16
}

///|
/// 构造 `Cjk16`。
pub fn Cjk16::new() -> Cjk16 {
  Cjk16::Cjk16
}

///|
pub extend Ascii5x7 with GlyphProvider::{cell_width, cell_height, glyph}

///|
pub extend Cjk16 with GlyphProvider::{cell_width, cell_height, glyph}

///|
pub impl GlyphProvider for Ascii5x7 with fn cell_width(_self) -> Int {
  5
}

///|
pub impl GlyphProvider for Ascii5x7 with fn cell_height(_self) -> Int {
  7
}

///|
pub impl GlyphProvider for Ascii5x7 with fn glyph(_self, c : Char) -> FixedArray[
  Byte,
]? {
  match glyph(c) {
    Some(arr) => {
      let out = FixedArray::make(7, (0).to_byte())
      for i in 0..<7 {
        out[i] = arr[i]
      }
      Some(out)
    }
    None => None
  }
}

///|
pub impl GlyphProvider for Cjk16 with fn cell_width(_self) -> Int {
  16
}

///|
pub impl GlyphProvider for Cjk16 with fn cell_height(_self) -> Int {
  16
}

///|
pub impl GlyphProvider for Cjk16 with fn glyph(_self, c : Char) -> FixedArray[
  Byte,
]? {
  cjk_glyphs.get(c)
}

///|
/// 16×16 中文点阵表（32 字节/字：每行 2 字节，高位在前）。
/// 字集覆盖直播水印高频词：防搬运盗播溯源水印直播间录制屏转载请勿二次传。
