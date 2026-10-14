# Third-Party Notices

本项目（moon-watermark）主体代码以 Apache-2.0 许可发布（见根目录 `LICENSE`）。
以下第三方资源被派生或依赖，其归属与许可声明须随本项目分发保留。

## 1. Noto Sans CJK（字形数据来源）

- **版权**：Copyright 2014-2021 Adobe
- **项目地址**：https://github.com/notofonts/noto-cjk
- **许可**：SIL Open Font License 1.1（OFL-1.1），许可全文见 [`fonts/OFL-1.1.txt`](fonts/OFL-1.1.txt)
- **本项目使用方式**：
  - `scripts/gen_cjk16_ascii.py` 与历史生成流程从 `NotoSansCJK-Bold.ttc` 渲染出 16×16 点阵，
    经 invert、包围盒裁剪、多数投票降采样后产出字形数据；
  - 该点阵数据固化在 `cjk16_data.mbt`（GB2312 一级字 3755 个）与
    `cjk16_ascii_data.mbt`（ASCII/符号 96 个）中，作为库内字形表分发。
- **合规说明**：
  - 本项目**未随库分发字体文件本身**（`.ttc`），仅分发由其渲染生成的 16×16 点阵数据；
  - 派生数据**未使用 Reserved Font Name**（命名为 `Cjk16`，非 "Noto Sans CJK"）；
  - 依据 OFL-1.1 第 2、5 条，本文件与 `fonts/OFL-1.1.txt` 作为版权与许可声明随本项目分发保留。

## 2. 社区基础包依赖

- `mizchi/image`：PNG/JPEG 编解码与图像容器；
- `moonbitlang/x/fs`：CLI 文件读写。

均为 MoonBit 生态公开社区包，按其各自开源许可使用，与 Apache-2.0 兼容。
