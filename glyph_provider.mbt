///|
/// 字形提供者接口：把"文本水印渲染"与"具体字形来源"解耦。
///
/// 内置两个实现：
/// - [`Ascii5x7`]：5×7 拉丁字形（A-Z、0-9、常用符号），适合英文/数字水印；
/// - [`Cjk16`]：16×16 中文点阵（直播水印高频字，NotoSerifCJK 生成），
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
/// 内置 16×16 中文点阵提供者（直播水印高频字）。
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
let cjk_glyphs : Map[Char, FixedArray[Byte]] = Map([
  (
    '防',
    [
      b'\x78', b'\x60', b'\x7C', b'\x60', b'\x6C', b'\x60', b'\x6F', b'\xFC', b'\x69',
      b'\xFC', b'\x78', b'\x80', b'\x78', b'\xC0', b'\x6C', b'\xFC', b'\x6C', b'\xCC',
      b'\x6D', b'\x8C', b'\x7D', b'\x8C', b'\x79', b'\x88', b'\x63', b'\x18', b'\x66',
      b'\x78', b'\x60', b'\x30', b'\x00', b'\x00',
    ],
  ),
  (
    '搬',
    [
      b'\x31', b'\x00', b'\x31', b'\x3C', b'\x33', b'\x34', b'\x77', b'\xF4', b'\x76',
      b'\xF4', b'\x37', b'\xF7', b'\x35', b'\xE6', b'\x37', b'\xC0', b'\x7F', b'\xFE',
      b'\x7C', b'\xFE', b'\x35', b'\xF4', b'\x35', b'\xDC', b'\x35', b'\xDC', b'\x3C',
      b'\xDC', b'\x7C', b'\xFE', b'\x69', b'\xA2',
    ],
  ),
  (
    '运',
    [
      b'\x20', b'\x00', b'\x33', b'\xFC', b'\x1B', b'\xFC', b'\x00', b'\x00', b'\x60',
      b'\x00', b'\x77', b'\xFF', b'\x17', b'\xFE', b'\x00', b'\xC8', b'\x71', b'\x98',
      b'\x71', b'\x8C', b'\x31', b'\xFE', b'\x37', b'\xFE', b'\x3B', b'\x82', b'\x7C',
      b'\x00', b'\x6F', b'\xFE', b'\x43', b'\xFE',
    ],
  ),
  (
    '盗',
    [
      b'\x01', b'\x00', b'\x73', b'\x80', b'\x3B', b'\xFE', b'\x17', b'\xFE', b'\x06',
      b'\x6C', b'\x08', b'\xE0', b'\x39', b'\xF0', b'\x77', b'\x9C', b'\x47', b'\x0E',
      b'\x1F', b'\xF8', b'\x3F', b'\xFC', b'\x32', b'\x4C', b'\x32', b'\x4C', b'\x32',
      b'\x4C', b'\x7F', b'\xFE', b'\x7F', b'\xFE',
    ],
  ),
  (
    '播',
    [
      b'\x30', b'\x1C', b'\x33', b'\xFC', b'\x31', b'\xEC', b'\x79', b'\xEC', b'\x7F',
      b'\xFE', b'\x33', b'\xFE', b'\x30', b'\xF8', b'\x3B', b'\xEE', b'\x7F', b'\x26',
      b'\xF3', b'\xFE', b'\x33', b'\x6C', b'\x33', b'\x6C', b'\x33', b'\xFC', b'\x33',
      b'\x64', b'\x73', b'\xFC', b'\x63', b'\x0C',
    ],
  ),
  (
    '溯',
    [
      b'\x04', b'\xC0', b'\x76', b'\xDE', b'\x36', b'\x9E', b'\x07', b'\xF6', b'\x0F',
      b'\xFE', b'\x63', b'\x1E', b'\x77', b'\x56', b'\x07', b'\x56', b'\x07', b'\x5E',
      b'\x07', b'\xFE', b'\x3F', b'\xF6', b'\x33', b'\x36', b'\x33', b'\x36', b'\x66',
      b'\x26', b'\x66', b'\x6E', b'\x04', b'\x2C',
    ],
  ),
  (
    '源',
    [
      b'\x20', b'\x00', b'\x77', b'\xFE', b'\x17', b'\xFE', b'\x06', b'\x30', b'\x06',
      b'\xFE', b'\x66', b'\xC6', b'\x76', b'\xC6', b'\x26', b'\xFE', b'\x06', b'\x86',
      b'\x06', b'\xFE', b'\x36', b'\x30', b'\x36', b'\xB4', b'\x3D', b'\xB6', b'\x6D',
      b'\xB6', b'\x6D', b'\x72', b'\x08', b'\x70',
    ],
  ),
  (
    '水',
    [
      b'\x01', b'\x80', b'\x01', b'\x80', b'\x01', b'\x80', b'\x01', b'\x86', b'\x7D',
      b'\xCE', b'\x7D', b'\xDC', b'\x0D', b'\xF8', b'\x0D', b'\xF0', b'\x0D', b'\xE0',
      b'\x19', b'\xB0', b'\x19', b'\xB8', b'\x31', b'\x9C', b'\x71', b'\x8E', b'\x61',
      b'\x8E', b'\x0F', b'\x80', b'\x07', b'\x00',
    ],
  ),
  (
    '印',
    [
      b'\x04', b'\x00', b'\x3E', b'\xFC', b'\x78', b'\xFC', b'\x60', b'\x8C', b'\x60',
      b'\x8C', b'\x70', b'\x8C', b'\x7E', b'\x8C', b'\x70', b'\x8C', b'\x60', b'\x8C',
      b'\x60', b'\x8C', b'\x7C', b'\x8C', b'\x7E', b'\x9C', b'\x60', b'\x98', b'\x00',
      b'\x80', b'\x00', b'\x80', b'\x00', b'\x00',
    ],
  ),
  (
    '直',
    [
      b'\x00', b'\x00', b'\x01', b'\x80', b'\x7F', b'\xFC', b'\x7F', b'\xFC', b'\x03',
      b'\x80', b'\x27', b'\xF8', b'\x24', b'\x18', b'\x27', b'\xF8', b'\x27', b'\xF8',
      b'\x27', b'\xF8', b'\x24', b'\x18', b'\x27', b'\xF8', b'\x23', b'\xE0', b'\x3F',
      b'\xFC', b'\x3F', b'\xFC', b'\x20', b'\x00',
    ],
  ),
  (
    '播',
    [
      b'\x30', b'\x1C', b'\x33', b'\xFC', b'\x31', b'\xEC', b'\x79', b'\xEC', b'\x7F',
      b'\xFE', b'\x33', b'\xFE', b'\x30', b'\xF8', b'\x3B', b'\xEE', b'\x7F', b'\x26',
      b'\xF3', b'\xFE', b'\x33', b'\x6C', b'\x33', b'\x6C', b'\x33', b'\xFC', b'\x33',
      b'\x64', b'\x73', b'\xFC', b'\x63', b'\x0C',
    ],
  ),
  (
    '间',
    [
      b'\x20', b'\x00', b'\x37', b'\xFE', b'\x3B', b'\xFE', b'\x10', b'\x06', b'\x60',
      b'\x06', b'\x67', b'\xE6', b'\x67', b'\xE6', b'\x64', b'\x26', b'\x67', b'\xE6',
      b'\x67', b'\xE6', b'\x64', b'\x26', b'\x67', b'\xE6', b'\x67', b'\xE6', b'\x60',
      b'\x06', b'\x60', b'\x0E', b'\x60', b'\x0C',
    ],
  ),
  (
    '录',
    [
      b'\x00', b'\x00', b'\x3F', b'\xF8', b'\x3F', b'\xF8', b'\x00', b'\x18', b'\x3F',
      b'\xF8', b'\x1F', b'\xF8', b'\x7F', b'\xFE', b'\x7F', b'\xFE', b'\x11', b'\x88',
      b'\x39', b'\xDC', b'\x1D', b'\xF8', b'\x0F', b'\xF0', b'\x1F', b'\xB8', b'\x79',
      b'\x9E', b'\x27', b'\x8E', b'\x07', b'\x00',
    ],
  ),
  (
    '制',
    [
      b'\x2C', b'\x06', b'\x2C', b'\x16', b'\x7F', b'\xB6', b'\x7F', b'\xB6', b'\x4C',
      b'\x36', b'\x7F', b'\xB6', b'\x7F', b'\xF6', b'\x0C', b'\x36', b'\x7F', b'\xB6',
      b'\x7F', b'\xB6', b'\x6D', b'\xB6', b'\x6D', b'\x86', b'\x6D', b'\x86', b'\x6F',
      b'\x86', b'\x6D', b'\x1E', b'\x0C', b'\x1C',
    ],
  ),
  (
    '屏',
    [
      b'\x3F', b'\xFC', b'\x3F', b'\xFC', b'\x3F', b'\xFC', b'\x3F', b'\xFC', b'\x33',
      b'\x18', b'\x33', b'\x18', b'\x3F', b'\xFE', b'\x37', b'\xFC', b'\x33', b'\x10',
      b'\x3F', b'\xFE', b'\x3F', b'\xFE', b'\x63', b'\x10', b'\x67', b'\x10', b'\x6E',
      b'\x10', b'\x44', b'\x10', b'\x00', b'\x00',
    ],
  ),
  (
    '转',
    [
      b'\x10', b'\x20', b'\x30', b'\x60', b'\x7F', b'\xFC', b'\x7C', b'\xF0', b'\x30',
      b'\x60', b'\x7B', b'\xFE', b'\x79', b'\xC0', b'\x7C', b'\xC0', b'\x7C', b'\xFC',
      b'\x18', b'\x18', b'\x7E', b'\x18', b'\x7C', b'\xF0', b'\x18', b'\x70', b'\x18',
      b'\x38', b'\x18', b'\x10', b'\x00', b'\x00',
    ],
  ),
  (
    '载',
    [
      b'\x00', b'\x00', b'\x04', b'\x68', b'\x3F', b'\xEC', b'\x04', b'\x60', b'\x3F',
      b'\xFC', b'\x3F', b'\xFC', b'\x1C', b'\x64', b'\x3F', b'\xAC', b'\x12', b'\x38',
      b'\x3F', b'\xB8', b'\x3F', b'\x30', b'\x06', b'\x30', b'\x3F', b'\xF6', b'\x3E',
      b'\xFC', b'\x06', b'\x4C', b'\x00', b'\x00',
    ],
  ),
  (
    '请',
    [
      b'\x00', b'\x00', b'\x10', b'\x60', b'\x1B', b'\xFC', b'\x18', b'\x60', b'\x01',
      b'\xF8', b'\x31', b'\xF8', b'\x7B', b'\xFE', b'\x18', b'\xF8', b'\x19', b'\xF8',
      b'\x19', b'\x8C', b'\x19', b'\xFC', b'\x1F', b'\xFC', b'\x1D', b'\xFC', b'\x19',
      b'\x0C', b'\x01', b'\x18', b'\x00', b'\x00',
    ],
  ),
  (
    '勿',
    [
      b'\x08', b'\x00', b'\x0C', b'\x00', b'\x18', b'\x00', b'\x1F', b'\xFE', b'\x3F',
      b'\xFE', b'\x33', b'\x66', b'\x76', b'\x66', b'\x66', b'\x66', b'\x0E', b'\x66',
      b'\x0C', b'\xC6', b'\x1C', b'\xC6', b'\x39', b'\xC6', b'\x71', b'\x8C', b'\x23',
      b'\x0C', b'\x07', b'\x3C', b'\x02', b'\x38',
    ],
  ),
  (
    '二',
    [
      b'\x00', b'\x00', b'\x3F', b'\xFC', b'\x3F', b'\xFC', b'\x00', b'\x00', b'\x00',
      b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00',
      b'\x00', b'\x00', b'\x00', b'\x00', b'\x7F', b'\xFE', b'\x7F', b'\xFE', b'\x00',
      b'\x00', b'\x00', b'\x00', b'\x00', b'\x00',
    ],
  ),
  (
    '次',
    [
      b'\x01', b'\x00', b'\x23', b'\x80', b'\x73', b'\x00', b'\x3B', b'\xFE', b'\x17',
      b'\xFE', b'\x06', b'\x66', b'\x0E', b'\x6C', b'\x04', b'\x6C', b'\x18', b'\xE0',
      b'\x18', b'\xE0', b'\x30', b'\xF0', b'\x71', b'\xB8', b'\x63', b'\x98', b'\x07',
      b'\x0E', b'\x0E', b'\x0E', b'\x08', b'\x02',
    ],
  ),
  (
    '传',
    [
      b'\x08', b'\x40', b'\x18', b'\x40', b'\x1B', b'\xFE', b'\x33', b'\xFC', b'\x30',
      b'\xC0', b'\x77', b'\xFE', b'\xF7', b'\xFE', b'\x71', b'\x80', b'\x31', b'\xFC',
      b'\x33', b'\xFE', b'\x30', b'\x1C', b'\x30', b'\xB8', b'\x30', b'\xF0', b'\x30',
      b'\x70', b'\x30', b'\x38', b'\x30', b'\x10',
    ],
  ),
])
