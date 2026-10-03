# moon-watermark

MoonBit 图像水印算法库：**可见水印**（文本 / 随机点阵 / Logo / 平铺）+ **不可见溯源水印**（LSB，开发中），提供 embed / extract / verify API 与配置 JSON 序列化。用于直播防去重、防盗播、内容溯源等场景。

## 功能矩阵

### 可见水印（已实现）

| 类型 | API | 说明 |
| --- | --- | --- |
| 文本水印 | `RgbaImage::embed_text` + `TextConfig` | 内置 5×7 点阵字体（A-Z / 0-9 / 常用符号），支持缩放、透明度、定位 |
| 随机点阵水印 | `RgbaImage::embed_dots` + `DotConfig` | 确定性 PRNG（xorshift64）按网格落点；**同一 seed 完全可复现 → 可提取、可溯源** |
| Logo 水印 | `RgbaImage::embed_logo` | 任意 RGBA 图叠加，支持透明 PNG |
| 平铺水印 | `RgbaImage::embed_tiled` + `TiledConfig` | 全幅网格平铺，防截屏/盗摄 |

### 提取与验证（已实现）

| API | 说明 |
| --- | --- |
| `extract_dots` | 用同一 `DotConfig` 复现点位置，统计深色命中率（0.0~1.0），≥0.9 判定水印存在 |

### 图像 IO（基于 `mizchi/image`）

`decode_png` / `encode_png` / `decode_jpeg` / `encode_jpeg` / `resize` / `crop`

### 配置持久化（已实现）

`text_config_to_json/from_json`、`dot_config_to_json/from_json`、`tiled_config_to_json/from_json`（core `@json`，seed 以 Number 表示）

## 安装

```bash
moon add yuzhiblue/moon-watermark
```

## Quick Start

完整可运行示例见 `cmd/main/main.mbt`（`moon run cmd/main`）：

```moonbit
// 1. 生成测试图（或 decode_png 解码真实图片）
let img = @lib.RgbaImage::new(320, 240, 0xFFFF_FFFF)

// 2. 文本水印：平台名 + 时间戳（直播贴片场景）
let tcfg = @lib.TextConfig::new("LIVE 2026-10-03", 8, 8, 2, 0.6, 0xFF00_00FF)
let _ = img.embed_text(tcfg)

// 3. 点阵溯源水印：seed = 观众/接收者 ID
let dcfg = @lib.DotConfig::default()
let _ = img.embed_dots(dcfg)

// 4. 编码 → 解码 → 提取验证
let png = img.encode_png()
let back = @lib.decode_png(png.unwrap()).unwrap()
let rate = @lib.extract_dots(back, dcfg)   // ≥0.9 判定水印存在
```

## 设计说明

- **颜色打包**：`0xRRGGBBAA`。MoonBit `Int` 为 32 位有符号，`0xFFFF_FFFF` 等高位字面量会表示为负数——位运算完全等价，无需担心；推荐用 `(r << 16) | (g << 8) | b | (a << 24)` 构造颜色。
- **确定性**：点阵水印完全由 `DotConfig`（含 seed）决定，这是提取与溯源的基础。
- **PNG 无损往返**：PNG 编码/解码不损失 LSB 信息，是不可见水印的载体（见路线图）。

## 生态区分

| 包 | 作者 | 定位 | 与 moon-watermark 差异 |
| --- | --- | --- | --- |
| `pixelforge` | 0717lee | 通用图像处理（合成/滤镜/编解码） | 无安全水印的嵌入-提取-溯源概念 |
| `moonwatermarkkit` | Oyc996 | 流处理"事件时间水印" | 非图像水印 |
| `watermark-toolkit` | V1GreenSummer | LLM 文本水印 | 非图像水印 |

## 路线图

- **W1（10/3–10/9）**：可见水印全家桶 ✅ · 配置 JSON ✅ · 可运行示例 ✅
- **W2**：不可见水印（LSB 字节信息嵌入/提取）+ 统一 `embed/extract/verify/trace` API
- **W3**：CLI（`watermark/cli`）+ 鲁棒性测试矩阵 + 发布 mooncakes
- **11 月**：直播贴片工坊应用（OBS / 直播伴侣浏览器源）复用本库

## License

Apache-2.0
