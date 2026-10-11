"""Dựng asset màn Chọn Máy Chủ (ui/server_select/) từ bộ ảnh nguyên liệu.

    python tools/build_server_select_assets.py <thư mục chứa ảnh 30.png (nền), 31.png (nút Vào game), 32.png (khung)>
Ảnh trong suốt được cắt sát phần nhìn thấy (alpha > 40, bỏ quầng mờ ở mép) rồi thu nhỏ. Logo dùng lại ui/login/logo.png.
"""
import os
import sys

from PIL import Image

SRC = sys.argv[1]
OUT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "ui", "server_select")
os.makedirs(OUT, exist_ok=True)
for src, dst, width in [("30.png", "bg.jpg", 1672), ("31.png", "btn_enter.png", 900), ("32.png", "frame.png", 1300)]:
	im = Image.open(os.path.join(SRC, src))
	if dst.endswith(".png"):
		im = im.convert("RGBA")
		im = im.crop(im.split()[-1].point(lambda v: 255 if v > 40 else 0).getbbox())
	else:
		im = im.convert("RGB")
	im = im.resize((width, round(im.height * width / im.width)), Image.LANCZOS)
	im.save(os.path.join(OUT, dst), **({"quality": 88} if dst.endswith(".jpg") else {"optimize": True}))
	print(dst, im.size)
