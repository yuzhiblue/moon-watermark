///|
/// 16×16 中文点阵表（GB2312 一级字 3755 个；32 字节/字：每行 2 字节，高位在前）。
/// 由 NotoSansCJK-Bold.ttc 渲染生成，invert+getbbox 裁剪 + 多数投票降采样。
/// 版权归属：Copyright 2014-2021 Adobe（Noto Sans CJK，SIL OFL 1.1）。
/// 许可全文见 fonts/OFL-1.1.txt，归属声明见 THIRD_PARTY_NOTICES.md（未分发字体文件、未使用 Reserved Font Name）。
let cjk_glyphs : Map[Char, FixedArray[Byte]] = {
  let m : Map[Char, FixedArray[Byte]] = Map([])
  for (k, v) in cjk_glyphs_a { m[k] = v }
  for (k, v) in cjk_glyphs_b { m[k] = v }
  for (k, v) in cjk_glyphs_c { m[k] = v }
  m
}
