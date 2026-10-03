# moon-watermark

MoonBit 图像水印算法库：**可见水印**（文本 / 随机点阵 / Logo / 平铺）+ **不可见溯源水印**（LSB），提供 embed / extract / verify / trace API 与配置 JSON 序列化。用于直播防去重、防盗播、内容溯源等场景。

## 功能矩阵

### 可见水印（已实现）

| 类型 | API | 说明 |
| --- | --- | --- |
| 文本水印 | `RgbaImage::embed_text` + `TextConfig` | 内置 5×7 点阵字体（A-Z / 0-9 / 常用符号），支持缩放、透明度、定位 |
| 随机点阵水印 | `RgbaImage::embed_dots` + `DotConfig` | 确定性 PRNG（xorshift64）按网格落点；**同一 seed 完全可复现 → 可提取、可溯源** |
| Logo 水印 | `RgbaImage::embed_logo` | 任意 RGBA 图叠加，支持透明 PNG |
| 平铺水印 | `RgbaImage::embed_tiled` + `TiledConfig` | 全幅网格平铺，防截屏/盗摄 |

### 不可见水印（已实现）

| API | 说明 |
| --- | --- |
| `RgbaImage::embed_invisible` + `extract_invisible` | LSB 逐位嵌入（RGB 通道各 1 bit/像素）；key 派生 keystream 整体混淆，错误 key 在 magic 校验处被拒绝；容量 = `宽×高×3/8` 字节 |
| `verify_invisible` | magic 校验通过即判定存在 |

### 提取、验证与溯源（已实现）

| API | 说明 |
| --- | --- |
| `extract_dots` | 用同一 `DotConfig` 复现点位置，统计深色命中率（0.0~1.0） |
| `verify_dots` | 命中率 ≥ 阈值（默认 0.9）判定水印存在 |
| `verify_invisible` | LSB 水印 magic 校验 |
| `trace_dots` | 对候选 `DotConfig` 数组溯源：返回命中率最高者索引（≥ 阈值）；直播场景每个接收者持有不同 seed，泄漏即锁定接收者 |

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

## 演示

嵌入前后对比（左上原图 → 右上 LSB 不可见水印 → 左下可见水印 → 右下差异放大 ×64 显示 LSB 实际改动位置）：

![嵌入前后对比](docs/demo/compare.png)

溯源演示（三位接收者持不同 seed，泄漏帧命中接收者 C）：

![溯源演示](docs/demo/trace.png)

鲁棒性矩阵可视化（数据来自 `robustness_wbtest.mbt` 实测）：

![鲁棒性矩阵](docs/demo/matrix.png)

## 鲁棒性测试矩阵（实测）

`moon test` 的 `robustness_wbtest.mbt` 实测数据（128×128 测试图，`DotConfig::default()`，density=0.05）：

| 攻击 | 点阵水印命中率 | LSB 不可见水印 | 说明 |
| --- | --- | --- | --- |
| PNG 无损往返 | 1.0 ✅ | 可提取 ✅ | LSB 的可靠载体 |
| JPEG q60 重压 | 1.0 ✅ | 提取失败 ❌ | 深色点高对比经 JPEG 保留；LSB 被量化破坏 → JPEG 场景需 DCT 域水印（roadmap） |
| 裁剪半幅（保留行格） | 1.0 ✅ | — | 点阵网格按行列索引相对化，裁剪不破坏行格时完全命中 |
| 缩放至 1/2（Nearest） | 0.0 ❌ | — | 像素网格重采样后点位置错位；缩放鲁棒需频域方案（roadmap） |

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
- **W2（10/10–10/16）**：不可见水印 LSB ✅（key 混淆 + magic 校验）· 统一 `verify/trace` API ✅ · PNG 无损往返集成测试 ✅
- **W3（10/17–10/23）**：鲁棒性测试矩阵 ✅（实测数据见上表）· CLI 评估 ✅（MoonBit core 暂无进程参数与文件 IO API，WASI 社区包接入会改变 target 配置；`cmd/main` 内存闭环示例已满足发布「可运行示例」要求，CLI 推迟至 v0.2 native 发布）· 发布 mooncakes
- **11 月**：直播贴片工坊应用（OBS / 直播伴侣浏览器源）复用本库

## License

Apache-2.0
