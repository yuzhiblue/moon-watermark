#!/usr/bin/env python3
"""
生成 E2E 演示素材：模拟直播画面（assets/live_frame.png）。

用法：python3 scripts/gen_live_frame.py [output_path]
默认输出 assets/live_frame.png（640×360）。

注意：中文字符必须用支持 CJK 的字体渲染（PIL 默认位图字体无中文字形，
会渲染为方框）；本脚本使用系统 Noto Sans CJK。
"""
import sys
import random
from PIL import Image, ImageDraw, ImageFont

W, H = 640, 360
FONT_PATH = "/usr/share/fonts/opentype/noto/NotoSansCJK-Bold.ttc"

def main():
    out = sys.argv[1] if len(sys.argv) > 1 else "assets/live_frame.png"
    random.seed(2026)

    img = Image.new("RGB", (W, H))
    px = img.load()
    # 直播间背景：暖色打光（较亮），模拟真实直播照明
    for y in range(H):
        for x in range(W):
            base = int(150 - 40 * (y / H))  # 上亮下稍暗
            spot = max(0, 200 - int(((x - W * 0.35) ** 2 + (y - H * 0.3) ** 2) / 8000))
            r = min(255, base + spot // 2 + random.randint(-5, 5))
            g = min(255, int(base * 0.95) + spot // 3 + random.randint(-5, 5))
            b = min(255, int(base * 0.8) + random.randint(-5, 5))
            px[x, y] = (max(0, r), max(0, g), max(0, b))

    d = ImageDraw.Draw(img)
    font_title = ImageFont.truetype(FONT_PATH, 20)
    font_chat = ImageFont.truetype(FONT_PATH, 15)
    font_sub = ImageFont.truetype(FONT_PATH, 18)

    # 主播头像框（左下，深色区域占比小）
    d.ellipse([40, 180, 190, 330], fill=(60, 50, 80), outline=(255, 210, 80), width=3)
    d.ellipse([65, 205, 165, 305], fill=(150, 110, 100))
    d.ellipse([95, 235, 135, 260], fill=(235, 185, 155))
    d.rectangle([80, 260, 150, 300], fill=(65, 65, 130))

    # 顶部标题条（平台 + 直播间名）
    d.rectangle([0, 0, W, 40], fill=(25, 25, 30))
    d.text((16, 8), "LIVE · MoonTalk 直播间 · 1234 人在看", font=font_title, fill=(255, 80, 80))

    # 底部字幕条
    d.rectangle([0, H - 44, W, H], fill=(12, 12, 16))
    d.text((16, H - 32), "主播：欢迎来到直播间，点点关注不迷路～", font=font_sub, fill=(240, 240, 240))

    # 聊天栏提示（右侧）
    for i, (t, c) in enumerate([
        ("观众A: 666", (200, 200, 200)),
        ("观众B: 主播好棒", (160, 200, 160)),
        ("观众C: 来了来了", (200, 160, 160)),
    ]):
        d.text((W - 150, 70 + i * 22), t, font=font_chat, fill=c)

    img.save(out)
    print(f"saved {out} ({img.size[0]}x{img.size[1]})")

if __name__ == "__main__":
    main()
