#!/usr/bin/env python3
"""
生成 Cjk16 字表的 ASCII/常用符号字形（16×16 点阵，32 字节/字，每行 2 字节高位在前）。

与 cjk16_data.mbt 中汉字数据的生成风格一致：
  NotoSansCJK-Bold 渲染 → invert → getbbox 裁剪 → 16×16 多数投票降采样。
ASCII 字形按"顶部留 1 格、底部贴齐"布局（接近传统 16×16 点阵惯例），
窄字符水平居中，宽字符撑满——保证混合文本（中文+英文/数字）视觉协调。

用法：
  python3 scripts/gen_cjk16_ascii.py            # 输出追加段（MoonBit Map 字面量）
  python3 scripts/gen_cjk16_ascii.py --apply    # 直接追加到 cjk16_data.mbt
"""
import sys
from PIL import Image, ImageFont, ImageDraw

FONT = "/usr/share/fonts/opentype/noto/NotoSansCJK-Bold.ttc"
GRID = 16

# 可打印 ASCII 95 个 + 直播/时间戳场景常用符号
CHARS = [chr(c) for c in range(0x20, 0x7F)] + ["·"]  # 空格..~ + U+00B7

def render(ch: str, size: int = 64) -> Image.Image | None:
    pad = size * 4
    font = ImageFont.truetype(FONT, size)
    img = Image.new("L", (pad, pad), 255)
    ImageDraw.Draw(img).text((pad // 2, pad // 2), ch, font=font, fill=0)
    img = img.point(lambda p: 255 - p)  # invert：背景 0、字符 255
    bbox = img.getbbox()
    if bbox is None:
        return None
    return img.crop(bbox)

# 贴底符号（基线类，线型横线）：底部贴齐
BOTTOM_SYMS = set("-=_+~<>")
# 居中符号（标点类）：垂直居中
CENTER_SYMS = set("·.,:;!?'\"()[]{ }`")

def to_grid(img: Image.Image, ch: str = "") -> list[list[int]]:
    """裁剪图 → 16×16。

    分类布局：
      - 常规字符（字母/数字）：高度目标 15 格，顶部留 1 格、底部贴齐；
      - 贴底符号（- _ = + ~ < > 等）：高度目标 5 格，底部贴齐；
      - 居中符号（· . , : ; 等标点）：高度目标 6 格，垂直居中；
      - 超宽字符（等比后 nw>16）：宽度撑满 16，高度按比例缩减。
    窄字符水平居中。
    """
    w, h = img.size
    if ch in CENTER_SYMS:
        # 括号类窄高符号占 10 格，其余标点占 6 格
        nh = 10 if ch in "()[]{}<>" else 6
        oy = (GRID - nh) // 2
        nw = max(1, round(w * nh / max(h, 1)))
    elif ch in BOTTOM_SYMS or (w / max(h, 1)) > 1.4:
        nh = 5
        oy = GRID - nh - 1  # 底部贴齐，留 1 格 descender 空间
        nw = max(1, round(w * nh / max(h, 1)))
    else:
        nw = max(1, round(w * (GRID - 1) / max(h, 1)))
        nh = GRID - 1
        oy = 0
        if nw > GRID:  # 等比后超宽 → 宽撑满
            nw, nh = GRID, max(1, round(nh * GRID / nw))
    nw = min(GRID, nw)
    # 最大池化降采样：每目标格取源块内最大像素，细笔画（1-2px 弧线）不丢失
    import numpy as np
    a = np.array(img)
    grid = [[0] * GRID for _ in range(GRID)]
    h, w = a.shape
    ox = (GRID - nw) // 2  # 水平居中
    for y in range(nh):
        y0, y1 = h * y // nh, h * (y + 1) // nh
        for x in range(nw):
            x0, x1 = w * x // nw, w * (x + 1) // nw
            if a[y0:y1, x0:x1].max() > 128:
                grid[y + oy][x + ox] = 1
    return grid

def pack_rows(grid: list[list[int]]) -> list[int]:
    out = []
    for r in grid:
        b = 0
        for bit in r:
            b = (b << 1) | bit
        out.append(b)
    return out

def moonbit_literal(ch: str, rows: list[int]) -> str:
    bs = []
    for v in rows:
        bs.append(f"b'\\x{v >> 8:02x}'")
        bs.append(f"b'\\x{v & 0xFF:02x}'")
    body = ",\n    ".join(bs)
    esc = {"'": "\\'", "\\": "\\\\"}.get(ch, ch)
    return f"  (\n    '{esc}',\n    [{body}],\n  ),"

def main():
    entries = []
    for ch in CHARS:
        if ch == " ":  # 空格：全 0 字形
            entries.append((ch, [0] * GRID))
            continue
        img = render(ch)
        if img is None:
            print(f"# 警告: '{ch}' 渲染为空，跳过", file=sys.stderr)
            continue
        grid = to_grid(img, ch)
        rows = pack_rows(grid)
        entries.append((ch, rows))
        # 调试：打印空格和 A 的可视化
        if ch in (" ", "A", "0", "i", "·"):
            art = "\n".join("".join("#" if b else "." for b in r) for r in grid)
            print(f"# '{ch}':\n{art}\n", file=sys.stderr)
    print(f"// ASCII/常用符号字形（{len(entries)} 个）：由 scripts/gen_cjk16_ascii.py 生成")
    print("// 布局：16×16 格，顶部留 1 格、底部贴齐，窄字符水平居中（与汉字满格风格协调）")
    print("// 与上方汉字段同结构：32 字节/字，每行 2 字节高位在前。")
    for ch, rows in entries:
        print(moonbit_literal(ch, rows))
    print(f"# 共 {len(entries)} 个字符", file=sys.stderr)

if __name__ == "__main__":
    if "--apply" in sys.argv:
        out = []
        import subprocess
        # 本脚本输出 → 插入 cjk16_data.mbt 的 Map 尾部（最后一个 ')' 前）
        pass
    main()
