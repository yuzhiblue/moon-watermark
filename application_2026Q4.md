# moon-watermark 项目申报书

## 基本信息

- **项目名称**：moon-watermark：MoonBit 通用图像水印基础库
- **参赛者**：yuzhiblue
- **联系方式**：【待填写：手机或微信】
- **GitHub 仓库链接**：https://github.com/yuzhiblue/moon-watermark
- **项目方向**：MoonBit 图像处理基础生态库 / 通用图像水印与溯源
- **是否为移植项目**：否（原创）

## 项目简介

moon-watermark 是 MoonBit 生态的**通用图像水印基础库**，把"给图片/画面嵌入身份标识 → 事后提取验证 → 出事了溯源到人"这条链路一次打通：**可见水印**（文本 / 随机点阵 / Logo / 平铺）做威慑，**不可见水印**（LSB / DCT 域）做取证，**溯源 API**（`trace_dots` / 盲检测）定位泄漏源。直播和短视频是搬运重灾区——同一场直播被多开转推、录屏改标题再发，平台去重和盗播溯源全靠人工；电商主图被同行一键盗用、内部截图外泄找不到人，同样是普遍痛点。mooncakes 现有图像相关包（`pixelforge` 合成滤镜、`watermark-toolkit` LLM 文本水印、`moonwatermarkkit` 流处理事件水印）均无"图像水印嵌入→提取→溯源"能力，**图像水印在 MoonBit 生态是空白**。本库以基础库定位补上这一块，下游应用（直播贴片工坊、电商防盗图工具、内部泄密追踪）开箱即用，无需各自重写水印算法。

技术上的关键难点与验证：DCT 不可见水印最初在 G 通道嵌入，真实照片经 JPEG 转码后提取失败——根因是 JPEG 在 YCbCr 空间量化色度通道、破坏 G 通道系数，v0.1.7 改为**亮度域（BT.601 Y）**嵌入后与 JPEG 亮度分量一致，纹理图 JPEG q85/q60 往返实测可提取，PSNR 50.9/45.3dB（>40dB 肉眼不可察），并新增回归测试防复发；中文点阵字形用 Noto CJK 字体批量生成 GB2312 一级字 3755 个为 16×16 点阵（多数投票降采样、墨迹包围盒裁剪），纯数据表无运行时资源依赖。

## 核心功能范围

- **可见水印四通道**：文本（内置 5×7 点阵拉丁字 + **16×16 中文点阵 Cjk16：GB2312 一级字 3755 个 + ASCII/符号 96 个**，v0.1.10 起混合文本一条渲染）；随机点阵（xorshift64 确定性 PRNG，同 seed 完全可复现 → 可提取、可溯源）；Logo（透明 PNG 叠加）；平铺（全幅网格，防截屏/盗摄）。支持缩放、透明度、定位与**任意角度旋转**（`TextConfig.angle`，45° 斜向防盗播水印；v0.1.12 起 `with_font` 可选 `angle` 参数，库外可直接设置）。
- **不可见水印（LSB）**：RGB 通道逐位嵌入，`key` 派生 keystream 整体混淆，错误 key 在 magic 校验处被拒；容量 = 宽×高×3/8 字节；实测 PSNR 76.98dB。
- **不可见水印（DCT 域）**：8×8 分块 DCT-II + 中频系数 (4,1) QIM 量化嵌入，亮度域与 JPEG 编码亮度分量一致，JPEG 重压可提取（自然纹理 q85 默认 `delta=24` 通过、强压缩 q60 用 `delta=48`）；容量 = 完整 8×8 块数/8 字节。
- **验证与溯源**：`verify_dots`（命中率阈值判定）、`verify_invisible` / `extract_dct`（magic + 长度校验）、`trace_dots`（候选 seed 数组定位泄漏源）；**盲检测 `detect_lsb` / `detect_dct`**（不依赖 key/delta，拿疑似泄漏帧先判"是否被标记"再深入提取——溯源第一问）。
- **组合嵌入与规划 API**：`EmbedOptions + embed_all` 一次叠加文本/点阵/LSB/DCT（可选通道，LSB 与 DCT 互斥返回 Err，不静默降级），面向直播贴片逐帧复用；`lsb_capacity / dct_capacity` 嵌入前规划通道。
- **越界防护（v0.1.11）**：水平文本超宽/超高不再静默裁剪——默认返回错误，`TextConfig.auto_shrink=true` 自动缩小字号适配；斜向 45° 水印保留跨画布特性。
- **字形扩展接口**：`GlyphProvider` trait + `render_text_with` 泛型入口；`BitmapFont::new(w, h, pairs)` 一行构造自定义字表、`BitmapFont::with_cjk16(extra)` 在内置字上补充生僻字/品牌字形；`TextConfig.font`（JSON 兼容）切换。
- **边界与资源保护**：边界输入测试矩阵（1×1 图、纯色饱和区、容量临界、空 payload、超长文本、0 尺寸裁剪）；`embed_text` 对 >512 字符返回 Err（超长文本旋转会分配 GB 级中间位图）。
- **图像 IO 与度量**：PNG/JPEG 编解码、`resize / crop / rotate`（任意角度逆映射最近邻，90/180/270 精确搬运）；`psnr` 量化嵌入前后差异。
- **配置持久化**：`TextConfig / DotConfig / TiledConfig` JSON 序列化，改配置不用改代码。
- **可运行性与工程**：文件模式 CLI（`embed / verify-dots / verify-lsb / verify-dct` 子命令，PNG/JPEG 按扩展名读写，payload 按 UTF-8 转码，LSB/DCT 互斥自动警告）；性能基准 `cmd/bench`；真实场景链路 `cmd/e2e`；GitHub Actions CI（check + build + test）绿。
- **诚实边界声明**：不可见水印是隐蔽性与鲁棒性工具而非强加密——嵌入格式为公开知识，不提供抗伪造/鉴权，密钥（LSB `key`、DCT `delta`）由持有方自行管理；LSB/DCT 不抗缩放/裁剪几何攻击（坐标依赖，抗几何攻击属后续规划）；不做视频编解码/直播推拉流（应用层由下游贴片工坊承担）。

## 预期验收产物

- **mooncakes 发布的 `yuzhiblue/moon-watermark` 库**（当前 v0.1.12）：`moon add yuzhiblue/moon-watermark` 后可直接使用全部 embed / extract / verify / trace API 与配置序列化；
- **完整测试覆盖核心路径**：102 个测试全过（含边界输入矩阵、盲检测、组合嵌入、旋转回归、混合字形、越界/自动缩放、JPEG 纹理图往返、PSNR），`moon check --deny-warn` 零警告；
- **README 可复现**：说明项目目标、安装方式（`moon add`）、使用方法与示例（Quick Start + 功能矩阵 + 场景选型速记 + 鲁棒性矩阵 + 性能基准），并给出真实场景 E2E 演示产物（`docs/demo/`）；
- **可运行示例**：`cmd/main` CLI（文件模式）、`cmd/bench` 性能基准、`cmd/e2e` 真实场景链路（模拟直播画面 → 贴片嵌入 → JPEG 转码 → 溯源锁定），全部 `moon run` 一键复现；
- **持续集成**：GitHub Actions 覆盖 `moon check`（含 `--deny-warn` 零警告门禁）、`moon build`、`moon test`，主分支全绿；
- **开源许可**：Apache-2.0（OSI 认可）；
- **真实场景验证数据**：640×360 照片风格纹理图全链路实测——文本+点阵+LSB 组合经 PNG 往返提取通过（点阵命中率 1.0、LSB payload 完整）、DCT 经 JPEG q85 往返提取通过；E2E 链路 `verify_dots` PASS、`extract_dct` 提取 `UID-00421`、`trace_dots` 命中观众 C（结果入库可复现）。

## 参考或依赖说明

- 本项目为**原创实现**，不移植任何开源项目，无原项目许可证合规问题；
- 运行时依赖社区基础包：`mizchi/image`（PNG/JPEG 编解码与图像容器，公开许可）与 `moonbitlang/x/fs`（CLI 文件 IO），均为 MoonBit 生态标准包，与 Apache-2.0 兼容；
- Cjk16 字形数据由 Noto Sans CJK 字体（SIL OFL 1.1 许可）批量渲染生成，生成脚本 `scripts/gen_cjk16_ascii.py` 与 `scripts/gen_live_frame.py` 入库可复现，库本身无运行时外部资源依赖。
