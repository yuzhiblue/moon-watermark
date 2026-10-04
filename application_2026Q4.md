# moon-watermark 项目申报书

## 基本信息

- **项目名称**：moon-watermark
- **参赛者**：yuzhiblue
- **联系方式**：13588235094
- **GitHub 仓库链接**：https://github.com/yuzhiblue/moon-watermark
- **项目方向**：MoonBit 图像处理基础生态库 / 通用图像水印与溯源
- **是否为移植项目**：否（原创）

## 项目简介

moon-watermark 是 MoonBit 生态的**通用图像水印基础库**，打通"嵌入身份标识 → 提取验证 → 溯源到人"完整链路：**可见水印**（文本 / 点阵 / Logo / 平铺）做威慑，**不可见水印**（LSB / DCT 域）做取证，**溯源 API**（`trace_dots` / 盲检测）定位泄漏源。直播搬运、电商盗图、内部泄密溯源是普遍痛点，而 mooncakes 现有图像包均无此能力——**图像水印在 MoonBit 生态是空白**，本库补齐，下游直播贴片工坊、电商防盗图工具等直接复用。技术上以亮度域 DCT 嵌入保证抗 JPEG 重压（真实照片 q85/q60 往返实测可提取）。

## 核心功能范围

- **可见水印四通道**：文本（内置 5×7 拉丁字 + **Cjk16 中文点阵：GB2312 一级字 3755 个 + ASCII/符号 96 个**，混合文本一条渲染）、点阵（确定性 PRNG，同 seed 可溯源）、Logo、平铺；支持缩放、透明度、任意角度旋转（45° 斜向防盗播）。
- **不可见水印（LSB）**：RGB 逐位嵌入 + key 混淆，错误 key 在 magic 校验处被拒；容量 = 宽×高×3/8 字节；PSNR 76.98dB。
- **不可见水印（DCT 域）**：8×8 分块 DCT-II + 中频系数 QIM 量化，亮度域与 JPEG 编码一致，JPEG 重压可提取（q85 默认 `delta=24`、q60 用 `delta=48`）；PSNR 50.9dB。
- **验证与溯源**：`verify_dots` / `verify_invisible` / `extract_dct` + `trace_dots`（候选 seed 定位泄漏源）+ 盲检测 `detect_lsb/detect_dct`（先判"是否被标记"再深入提取）。
- **组合嵌入与工程化**：`embed_all` 一次叠加多通道（LSB/DCT 互斥返回 Err）；容量规划 API；配置 JSON 序列化；越界防护 `auto_shrink`（v0.1.11）；文件 CLI + 性能基准 `cmd/bench` + 真实场景 E2E `cmd/e2e`（模拟直播画面 → 嵌入 → JPEG 转码 → 溯源锁定）。
- **质量与边界**：102 测试全过（边界矩阵、盲检测、组合、旋转、越界/自动缩放、JPEG 往返）、CI 绿、`--deny-warn` 零警告；诚实声明：不可见水印非强加密、不抗几何攻击（坐标依赖），密钥由持有方管理。

## 预期验收产物

- **mooncakes 发布**：`yuzhiblue/moon-watermark` v0.1.12，`moon add` 即用全部 API；
- **可复现**：README（目标/安装/用法/示例/鲁棒性矩阵/性能基准）+ 可运行示例（CLI / bench / e2e 一键 `moon run`）+ E2E 产物入库；
- **持续集成**：GitHub Actions 覆盖 check（零警告门禁）/ build / test，主分支全绿；
- **开源许可**：Apache-2.0（OSI 认可），原创实现，依赖社区包许可兼容。

## 参考或依赖说明

原创实现，不移植开源项目；依赖 MoonBit 社区基础包 `mizchi/image`（PNG/JPEG IO）与 `moonbitlang/x/fs`（CLI），与 Apache-2.0 兼容；Cjk16 字形数据由 Noto CJK 字体（SIL OFL 1.1）生成，生成脚本入库可复现，库本身无运行时外部资源依赖。
