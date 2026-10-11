"""Dựng asset cho màn Tạo Nhân Vật (ui/character_create).

- Sheet nhân vật (1 dải ngang ~20 khung, cao 1080, rộng tới 26000px — vượt giới hạn texture GPU di động)
  -> cắt theo khung, crop chung 1 bbox, thu nhỏ, xếp lưới -> ui/character_create/chars/<he>_<gioi>.png
  + chars.json (kích thước ô, số cột, số khung).
- Ảnh nút/biểu tượng (nền trong suốt, có viền trống) -> crop sát + thu nhỏ.
- Huy hiệu ngũ hành: cắt tròn từ ảnh mockup (không có asset rời).
- Nền: ảnh chiến trường (ảnh số 9).

Chạy: python tools/build_character_create_assets.py <thư_mục_ảnh_UI> <thư_mục_sheet_nhân_vật>
"""
import json
import os
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

UI_SRC = sys.argv[1]
SHEET_SRC = sys.argv[2]
OUT = os.path.join(os.path.dirname(__file__), "..", "ui", "character_create")
os.makedirs(os.path.join(OUT, "chars"), exist_ok=True)

TARGET_H = 480
COLS = 5

# <he>_<gioi> -> số khung (đã đo bằng khoảng trống cột alpha)
SHEETS = {
	"hoa_nam": 21, "hoa_nu": 21, "kim_nam": 21, "moc_nam": 21,
	"moc_nu": 21, "tho_nam": 20, "tho_nu": 21, "thuy_nu": 21,
}


def build_sheet(name: str, n: int) -> dict:
	im = Image.open(os.path.join(SHEET_SRC, name + ".png")).convert("RGBA")
	fw = im.width // n
	frames = [im.crop((i * fw, 0, (i + 1) * fw, im.height)) for i in range(n)]
	boxes = [f.split()[-1].point(lambda v: 255 if v > 10 else 0).getbbox() for f in frames]
	x0 = min(b[0] for b in boxes); y0 = min(b[1] for b in boxes)
	x1 = max(b[2] for b in boxes); y1 = max(b[3] for b in boxes)
	s = TARGET_H / (y1 - y0)
	cw, ch = round((x1 - x0) * s), TARGET_H
	rows = (n + COLS - 1) // COLS
	atlas = Image.new("RGBA", (cw * COLS, ch * rows), (0, 0, 0, 0))
	for i, f in enumerate(frames):
		c = f.crop((x0, y0, x1, y1)).resize((cw, ch), Image.LANCZOS)
		atlas.paste(c, ((i % COLS) * cw, (i // COLS) * ch))
	atlas.save(os.path.join(OUT, "chars", name + ".png"), optimize=True)
	return {"cell_w": cw, "cell_h": ch, "cols": COLS, "frames": n}


def trim_save(src: str, dst: str, width: int) -> tuple:
	im = Image.open(os.path.join(UI_SRC, src)).convert("RGBA")
	box = im.split()[-1].point(lambda v: 255 if v > 8 else 0).getbbox()
	im = im.crop(box)
	h = round(im.height * width / im.width)
	im.resize((width, h), Image.LANCZOS).save(os.path.join(OUT, dst), optimize=True)
	return box


meta = {name: build_sheet(name, n) for name, n in SHEETS.items()}
with open(os.path.join(OUT, "chars", "chars.json"), "w") as f:
	json.dump(meta, f, indent=1)

# 1=mockup 2=Thiết lập 3=Hỗ trợ 4=Thông báo 5=Tài khoản 6=Vào game 7=Tạo nhân vật 8=ô tên 9=nền
for src, dst, w in [("2.png", "icon_settings.png", 300), ("3.png", "icon_support.png", 300),
		("4.png", "icon_notice.png", 300), ("5.png", "icon_account.png", 300),
		("6.png", "btn_enter.png", 760), ("7.png", "btn_create.png", 760),
		("8.png", "name_input.png", 760)]:
	print(dst, trim_save(src, dst, w))

Image.open(os.path.join(UI_SRC, "9.png")).convert("RGB").save(os.path.join(OUT, "bg.jpg"), quality=90)

# Huy hiệu ngũ hành: cắt tròn từ mockup (tâm theo toạ độ ảnh 1672x941)
mock = Image.open(os.path.join(UI_SRC, "1.png")).convert("RGBA")
R = 88
for key, cy in [("kim", 120), ("moc", 258), ("thuy", 395), ("hoa", 525), ("tho", 660)]:
	cx = 838
	crop = mock.crop((cx - R, cy - R, cx + R, cy + R))
	mask = Image.new("L", crop.size, 0)
	ImageDraw.Draw(mask).ellipse((10, 10, 2 * R - 10, 2 * R - 10), fill=255)
	mask = mask.filter(ImageFilter.GaussianBlur(5))
	crop.putalpha(mask)
	crop.save(os.path.join(OUT, "element_%s.png" % key), optimize=True)
print("xong")
