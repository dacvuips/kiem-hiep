"""Dựng asset màn Đăng Nhập (ui/login/) từ bộ ảnh nguyên liệu.

    python tools/build_login_assets.py <thư mục chứa các ảnh>  [bg logo frame btn_login btn_create g a f u]
Thứ tự mặc định theo tên tệp 20..28: nền, nút đăng nhập, biểu tượng người dùng, Google, Apple, Facebook, logo, nút tạo tài khoản, khung.
Mỗi ảnh có nền trong suốt được cắt sát phần nhìn thấy (alpha > 40, bỏ quầng mờ ở mép) rồi thu nhỏ.
"""
import os
import sys

from PIL import Image

SRC = sys.argv[1]
OUT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "ui", "login")
os.makedirs(OUT, exist_ok=True)
JOBS = [("20.png", "bg.jpg", 1672), ("21.png", "btn_login.png", 900), ("22.png", "icon_user.png", 200), ("23.png", "icon_google.png", 200),
		("24.png", "icon_apple.png", 200), ("25.png", "icon_facebook.png", 200), ("26.png", "logo.png", 1000),
		("27.png", "btn_create.png", 800), ("28.png", "frame.png", 900)]
for src, dst, width in JOBS:
	im = Image.open(os.path.join(SRC, src))
	if dst.endswith(".png"):
		im = im.convert("RGBA")
		box = im.split()[-1].point(lambda v: 255 if v > 40 else 0).getbbox()
		im = im.crop(box)
	else:
		im = im.convert("RGB")
	im = im.resize((width, round(im.height * width / im.width)), Image.LANCZOS)
	if dst.endswith(".jpg"):
		im.save(os.path.join(OUT, dst), quality=88)
	else:
		im.save(os.path.join(OUT, dst), optimize=True)
	print(dst, im.size)
