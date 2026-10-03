///|
/// 文本水印配置。
///
/// - `x` / `y`：水印左上角在目标图像中的坐标（像素）。
/// - `font_size`：点阵字体的缩放倍数（1 = 原始 5×7 尺寸）。
/// - `opacity`：整体不透明度（0.0 ~ 1.0）。
/// - `angle`：旋转角度（度）。当前版本保留字段，暂未实现旋转。
/// - `color`：打包 RGBA 颜色 `0xRRGGBBAA`。
pub struct TextConfig {
  text : String
  x : Int
  y : Int
  font_size : Int
  opacity : Double
  angle : Double
  color : Int
}

///|
/// 便捷构造器：`angle` 默认为 0（当前版本未实现旋转）。
pub fn TextConfig::new(
  text : String, x : Int, y : Int, font_size : Int, opacity : Double, color : Int
) -> TextConfig {
  {
    text: text,
    x: x,
    y: y,
    font_size: font_size,
    opacity: opacity,
    angle: 0.0,
    color: color,
  }
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
  density : Double, dot_size : Int, seed : Int64, opacity : Double,
  grid_offset_x : Int, grid_offset_y : Int
) -> DotConfig {
  {
    density: density,
    dot_size: dot_size,
    seed: seed,
    opacity: opacity,
    grid_offset_x: grid_offset_x,
    grid_offset_y: grid_offset_y,
  }
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
}

///|
/// 便捷构造器（颜色打包 RGBA `0xRRGGBBAA`）。
pub fn TiledConfig::new(
  text : String, font_size : Int, spacing_x : Int, spacing_y : Int, opacity : Double, color : Int
) -> TiledConfig {
  {
    text: text,
    font_size: font_size,
    spacing_x: spacing_x,
    spacing_y: spacing_y,
    opacity: opacity,
    color: color,
  }
}
