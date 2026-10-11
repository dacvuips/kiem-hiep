"""Nhập các VÒNG HÀO QUANG (.spr) cho màn Tạo Nhân Vật -> ui/character_create/aura/<tên>.png + aura.json.

    python tools/import_login_aura.py "<1 file aura .spr  HOẶC  thư mục chứa các file .spr>"

Thư mục đích được DỌN SẠCH trước khi nhập (chỉ giữ đúng các vòng đang nhập). Mỗi .spr -> 1 dải PNG (các frame xếp ngang, cùng kích thước khung gốc, đã căn theo toạ độ lệch của từng frame) + mô tả
{frames, w, h, interval} trong aura.json. Tên tệp tiếng Trung/mã hỏng được đổi sang tên không dấu (xem ALIASES).
Chọn vòng nào cho hệ nào: thuộc tính `element_aura` của node CharacterCreate (Inspector), hoặc AuraRing.aura_name.
"""
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
sys.stdout.reconfigure(encoding="utf-8", errors="replace")
import spr_to_png  # noqa: E402
from PIL import Image  # noqa: E402

OUT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "ui", "character_create", "aura")
ALIASES = {"lvguagnhuan": "lvguanghuan"}   # tên gốc gõ sai chính tả


def key_of(filename: str) -> str:
	base = os.path.splitext(filename)[0]
	if not base.isascii() or not base.replace("_", "").isalnum():
		return "cangyan_qisheng"   # "苍炎七圣—光环" (tên gốc bị hỏng mã hoá)
	return ALIASES.get(base.lower(), base.lower())


def main() -> None:
	src = sys.argv[1]
	os.makedirs(OUT, exist_ok=True)
	for old in os.listdir(OUT):   # bỏ các vòng cũ
		os.remove(os.path.join(OUT, old))
	if os.path.isfile(src):
		files = [(os.path.basename(src), src)]
	else:
		files = [(f, os.path.join(src, f)) for f in sorted(os.listdir(src)) if f.lower().endswith(".spr")]
	meta = {}
	for f, path in files:
		images, info = spr_to_png.read_spr(path)
		w, h = images[0].size
		sheet = Image.new("RGBA", (w * len(images), h), (0, 0, 0, 0))
		for i, im in enumerate(images):
			sheet.paste(im, (i * w, 0))
		key = key_of(f)
		sheet.save(os.path.join(OUT, key + ".png"), optimize=True)
		meta[key] = {"frames": len(images), "w": w, "h": h, "interval": max(int(info["interval"]), 1)}
		print("  %-18s %2d frame %dx%d" % (key, len(images), w, h))
	with open(os.path.join(OUT, "aura.json"), "w", encoding="utf-8") as fp:
		json.dump(meta, fp, indent=1, sort_keys=True)
	print("Xong ->", OUT)


if __name__ == "__main__":
	main()
