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
  // v0.1.10：先查汉字段，再查 ASCII/符号段（混合文本一条水印完整渲染）
  match cjk_glyphs.get(c) {
    Some(g) => Some(g)
    None => cjk16_ascii_glyphs.get(c)
  }
}

///|
/// 通用位图字体：由调用方提供字形表，自动实现 [`GlyphProvider`]。
///
/// 用于自定义字形场景：客户用自己的工具（如"字体→点阵"转换脚本）生成
/// 字形数据，一行构造即可用于水印渲染，无需手写 trait 实现。
pub struct BitmapFont {
  cell_w : Int
  cell_h : Int
  glyphs : Map[Char, FixedArray[Byte]]
}

///|
/// 由调用方提供的字形对构造；`pairs` 中重复字符以后者为准。
pub fn BitmapFont::new(
  cell_w : Int,
  cell_h : Int,
  pairs : Array[(Char, FixedArray[Byte])],
) -> BitmapFont {
  let m : Map[Char, FixedArray[Byte]] = Map([])
  for p in pairs {
    m.set(p.0, p.1)
  }
  { cell_w, cell_h, glyphs: m }
}

///|
/// 以内置 Cjk16（GB2312 一级 3755 字）为基础，叠加调用方补充/覆盖的字形。
/// 适合在通用字集上追加生僻字、专用字或品牌定制字形。
/// 注意：内部会**拷贝**内置字表——补充的字形只影响返回的 `BitmapFont`，
/// 不会污染全局 `Cjk16` 提供者（Map 为引用语义，直接 `let m = cjk_glyphs`
/// 再 `set` 会改写全局字表）。
pub fn BitmapFont::with_cjk16(extra : Array[(Char, FixedArray[Byte])]) -> BitmapFont {
  let m : Map[Char, FixedArray[Byte]] = Map([])
  for k, v in cjk_glyphs {
    m.set(k, v)
  }
  for k, v in cjk16_ascii_glyphs {
    m.set(k, v)
  }
  for p in extra {
    m.set(p.0, p.1)
  }
  { cell_w: 16, cell_h: 16, glyphs: m }
}

///|
pub extend BitmapFont with GlyphProvider::{cell_width, cell_height, glyph}

///|
pub impl GlyphProvider for BitmapFont with fn cell_width(self) -> Int {
  self.cell_w
}

///|
pub impl GlyphProvider for BitmapFont with fn cell_height(self) -> Int {
  self.cell_h
}

///|
pub impl GlyphProvider for BitmapFont with fn glyph(self, c : Char) -> FixedArray[Byte]? {
  self.glyphs.get(c)
}
