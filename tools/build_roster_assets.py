"""Dựng asset màn Chọn Nhân Vật trong kho (ui/character_roster/): nền (36.png) + thanh 4 nút (35.png, cắt sát phần nhìn thấy).

    python tools/build_roster_assets.py <thư mục chứa 35.png, 36.png>
"""
import os
import sys

from PIL import Image

SRC = sys.argv[1]
OUT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "ui", "character_roster")
os.makedirs(OUT, exist_ok=True)
bg = Image.open(os.path.join(SRC, "36.png")).convert("RGB")
bg.save(os.path.join(OUT, "bg.jpg"), quality=88)
bar = Image.open(os.path.join(SRC, "35.png")).convert("RGBA")
bar = bar.crop(bar.split()[-1].point(lambda v: 255 if v > 40 else 0).getbbox())
bar = bar.resize((1400, round(bar.height * 1400 / bar.width)), Image.LANCZOS)
bar.save(os.path.join(OUT, "bar.png"), optimize=True)
print("bg", bg.size, "bar", bar.size)
