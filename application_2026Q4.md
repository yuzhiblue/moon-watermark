# moon-watermark：MoonBit 图像水印算法库

**赛道**：新项目申报（参与季度评选） ｜ **主语言**：MoonBit ｜ **许可**：Apache-2.0

## 一、痛点与生态位

直播和短视频是搬运重灾区：同一场直播被 OBS/直播伴侣多开转推、录屏后改标题再发，平台去重和盗播溯源全靠人工。想要"平台名 + 时间戳 + 观众 ID"三件套自动盖到画面上，再在出事时定位到人，就需要一个**能嵌入、能提取、能溯源**的水印库——但 mooncakes 上现成的图像库全是"画像处理"路线：

- `pixelforge`（9 月底发布）：合成 / 滤镜 / PNG-JPEG 编解码，**没有"嵌入→提取→溯源"的水印概念**；
- `watermark-toolkit`：LLM 文本水印，和图像无关；
- `moonwatermarkkit`：流处理的"事件时间水印"，概念撞名、用途完全不同。

**图像水印（可见 + 不可见 + 溯源）在 MoonBit 生态是空白**，这就是我做它的理由。

## 二、交付边界

做：

- **可见水印**：文本（内置 5×7 点阵字体，无外部资源依赖）、随机点阵（PRNG 可复现，同 seed 同点）、Logo、平铺；`TextConfig / DotConfig / TiledConfig` 支持 JSON 序列化，改配置不用改代码；
- **不可见水印**：LSB 逐位嵌入 RGB 通道，`key` 派生 keystream 整体混淆，错误 key 在 magic 校验处被拒——观众 ID 溯源鉴权的底子；
- **验证与溯源**：`verify_dots / verify_invisible / trace_dots`——对候选 seed 数组定位泄漏源，命中率 ≥0.9 才判定；
- 鲁棒性测试矩阵（实测数据见 README）、可运行示例、CI、测试。

不做（明确边界）：

- 不做视频编解码 / 直播推拉流——那是应用层，留给 11 月的贴片工坊（OBS 浏览器源），本库只出算法；
- 不做 DCT 域水印——LSB 实测扛不住 JPEG 量化（矩阵第 2 行），JPEG 鲁棒需要频域方案，列入 roadmap，不在本次 MVP。

## 三、实现路径

- MoonBit 纯实现，`mizchi/image` 只做 PNG/JPEG IO 和 resize/crop，水印算法（PRNG、字体渲染、混合、LSB、混淆）全部自写；
- 全程 `--deny-warn` 零警告，**48 个测试**全过：单位测试 + PNG 无损往返集成 + 鲁棒性矩阵（PNG→1.0、JPEG q60→1.0、裁剪→1.0、缩放→0，实测记录在 README）；
- 11 个 commits、CI（check + test）、README、可运行示例：`moon run cmd/main` 内存闭环演示创建图→三种水印→PNG 编解码→提取命中率 1.0；
- 已发布 mooncakes：**https://mooncakes.io/docs/yuzhiblue/moon-watermark**
- 仓库：**https://github.com/yuzhiblue/moon-watermark**

一句话：**别人在做"让图片好看"的库，我在做"让图片认主人"的库**，直播去重、防盗播、内鬼溯源直接可落。
