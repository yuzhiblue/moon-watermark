///|
/// 文本水印配置。
///
/// - `x` / `y`：水印左上角在目标图像中的坐标（像素）。
/// - `font_size`：点阵字体的缩放倍数（1 = 原始 5×7 尺寸）。
/// - `opacity`：整体不透明度（0.0 ~ 1.0）。
/// - `angle`：旋转角度（度，逆时针，0 = 不旋转；常用 45 做斜向防盗播水印）。
/// - `color`：打包 RGBA 颜色 `0xRRGGBBAA`。
pub struct TextConfig {
  text : String
  x : Int
  y : Int
  font_size : Int
  opacity : Double
  angle : Double
  color : Int
  font : String // 字形："ascii5x7"（拉丁）| "cjk16"（中文点阵）
  auto_shrink : Bool // v0.1.11：水平文本越界时自动缩小适配（默认 false=报错）
}

///|
/// 便捷构造器：`angle` 默认为 0（不旋转）。
pub fn TextConfig::new(
  text : String,
  x : Int,
  y : Int,
  font_size : Int,
  opacity : Double,
  color : Int,
) -> TextConfig {
  TextConfig::with_font(text, x, y, font_size, opacity, color, "ascii5x7")
}

///|
/// 带字形选择的构造器：`font` 取 `"ascii5x7"` 或 `"cjk16"`。
pub fn TextConfig::with_font(
  text : String,
  x : Int,
  y : Int,
  font_size : Int,
  opacity : Double,
  color : Int,
  font : String,
) -> TextConfig {
  { text, x, y, font_size, opacity, angle: 0.0, color, font, auto_shrink: false, }
}

///|
/// 随机点阵水印配置。
///
/// - `density`：点阵密度（0.0 ~ 1.0，越大点越密）。
/// - `dot_size`：单个点的大小（像素边长）。
/// - `seed`：确定性 PRNG 种子；同一种子在不同运行间生成相同水印（可复现、可验证）。
/// - `opacity`：点的不透明度（0.0 ~ 1.0）。
/// - `grid_offset_x` / `grid_offset_y`：点阵网格偏移，用于多平台差异化。
pub struct DotConfig {
  density : Double
  dot_size : Int
  seed : Int64
  opacity : Double
  grid_offset_x : Int
  grid_offset_y : Int
}

///|
/// 显式构造：供溯源场景为不同接收者分配不同 `seed`。
pub fn DotConfig::new(
  density : Double,
  dot_size : Int,
  seed : Int64,
  opacity : Double,
  grid_offset_x : Int,
  grid_offset_y : Int,
) -> DotConfig {
  { density, dot_size, seed, opacity, grid_offset_x, grid_offset_y, }
}

///|
/// 默认配置：密度 0.05、点大小 3（1px 点在缩放/重压下会丢失，3px 兼顾可见性与鲁棒性）、
/// 种子 42、全不透明、无偏移。
pub fn DotConfig::default() -> DotConfig {
  {
    density: 0.05,
    dot_size: 3,
    seed: 42L,
    opacity: 1.0,
    grid_offset_x: 0,
    grid_offset_y: 0,
  }
}

///|
/// 平铺水印配置：`text` 按 `font_size` 放大为单元，以
/// `spacing_x / spacing_y` 为间距平铺覆盖整张图。
pub struct TiledConfig {
  text : String
  font_size : Int
  spacing_x : Int
  spacing_y : Int
  opacity : Double
  color : Int
  font : String
}

///|
/// 便捷构造器（颜色打包 RGBA `0xRRGGBBAA`）。
pub fn TiledConfig::new(
  text : String,
  font_size : Int,
  spacing_x : Int,
  spacing_y : Int,
  opacity : Double,
  color : Int,
  font? : String,
) -> TiledConfig {
  let f = match font {
    Some(v) => v
    None => "ascii5x7"
  }
  { text, font_size, spacing_x, spacing_y, opacity, color, font: f, }
}
