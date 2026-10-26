"""產生占位圖示與啟動畫面(Pillow):assets/icons/icon_128 / 144 / 180 / 512.png、splash.png。
深藍圓角底、橘黃色的魚、幾點雪。正式美術同名覆蓋即可。用法:python tools/gen_icons.py
"""
import os

from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "icons")
BG = (28, 52, 96, 255)
WATER = (60, 130, 210, 255)
FISH = (255, 170, 60, 255)
SNOW = (255, 255, 255, 230)


def draw_fish(d, cx, cy, s):
    """以 (cx, cy) 為中心、s 為比例尺(1 = 單位大小)畫一條朝左的魚。"""
    d.ellipse([cx - 0.27 * s, cy - 0.15 * s, cx + 0.2 * s, cy + 0.15 * s], fill=FISH)
    d.polygon([(cx + 0.17 * s, cy), (cx + 0.36 * s, cy - 0.17 * s), (cx + 0.36 * s, cy + 0.17 * s)], fill=FISH)
    d.ellipse([cx - 0.2 * s, cy - 0.06 * s, cx - 0.13 * s, cy + 0.01 * s], fill=(30, 30, 40, 255))
    d.polygon([(cx - 0.05 * s, cy - 0.14 * s), (cx + 0.05 * s, cy - 0.26 * s), (cx + 0.1 * s, cy - 0.13 * s)], fill=(235, 140, 40, 255))


def icon(size):
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rounded_rectangle([0, 0, size - 1, size - 1], radius=size * 0.22, fill=BG)
    d.rounded_rectangle([size * 0.08, size * 0.58, size * 0.92, size * 0.9], radius=size * 0.08, fill=WATER)
    draw_fish(d, size * 0.5, size * 0.44, size)
    for x, y, r in ((0.2, 0.16, 0.03), (0.78, 0.12, 0.025), (0.62, 0.26, 0.02), (0.3, 0.3, 0.018), (0.86, 0.34, 0.02)):
        d.ellipse([size * (x - r), size * (y - r), size * (x + r), size * (y + r)], fill=SNOW)
    return img


def splash(size=1024):
    img = Image.new("RGBA", (size, size), BG)
    d = ImageDraw.Draw(img)
    d.rectangle([0, size * 0.62, size, size], fill=WATER)
    draw_fish(d, size * 0.5, size * 0.4, size * 0.7)
    for x, y, r in ((0.12, 0.1, 0.012), (0.3, 0.2, 0.009), (0.7, 0.08, 0.011), (0.88, 0.22, 0.008), (0.5, 0.14, 0.007), (0.2, 0.5, 0.01), (0.82, 0.5, 0.009)):
        d.ellipse([size * (x - r), size * (y - r), size * (x + r), size * (y + r)], fill=SNOW)
    try:
        font = ImageFont.truetype("C:/Windows/Fonts/arialbd.ttf", int(size * 0.11))
    except OSError:
        font = ImageFont.load_default()
    text = "ManLife"
    box = d.textbbox((0, 0), text, font=font)
    w = box[2] - box[0]
    d.text(((size - w) / 2, size * 0.72), text, font=font, fill=(255, 255, 255, 255))
    return img


def main():
    os.makedirs(OUT, exist_ok=True)
    for s in (128, 144, 180, 512):
        icon(s).save(os.path.join(OUT, "icon_%d.png" % s))
        print("icon_%d.png" % s)
    splash().save(os.path.join(OUT, "splash.png"))
    print("splash.png")


if __name__ == "__main__":
    main()
