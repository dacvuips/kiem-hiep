"""Đo vị trí CHÂN của từng nhân vật trong atlas màn Tạo Nhân Vật -> ghi "feet_x" (toạ độ ngang của chân, tính theo pixel ô) vào
ui/character_create/chars/chars.json.

    python tools/measure_character_feet.py

Lý do: ảnh mỗi nhân vật được cắt theo hộp bao chung của mọi khung nên thân người không nằm giữa ô (kiếm/áo choàng lệch 1 bên).
AnimatedPortrait căn CHÂN vào giữa cạnh dưới khung thay vì căn giữa ô. Còn lệch thì chỉnh tay (AnimatedPortrait.preview_offset).
"""
import json
import sys
import os

import numpy as np
from PIL import Image

sys.stdout.reconfigure(encoding="utf-8", errors="replace")
DIR = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "ui", "character_create", "chars")
BAND = 0.07   # phần dưới cùng của ô được coi là "bàn chân"

with open(os.path.join(DIR, "chars.json"), encoding="utf-8") as f:
	meta = json.load(f)
for key, m in meta.items():
	alpha = np.array(Image.open(os.path.join(DIR, key + ".png")).convert("RGBA"))[:, :, 3]
	cw, ch, cols = m["cell_w"], m["cell_h"], m["cols"]
	xs = []
	for i in range(m["frames"]):
		x0, y0 = (i % cols) * cw, (i // cols) * ch
		cell = alpha[y0:y0 + ch, x0:x0 + cw]
		rows = np.where((cell > 10).any(axis=1))[0]
		if rows.size == 0:
			continue
		bottom = rows.max()
		band = cell[max(0, bottom - int(ch * BAND)):bottom + 1] > 10
		cols_hit = np.where(band.any(axis=0))[0]
		xs.append(cols_hit.mean())
	m["feet_x"] = round(float(np.mean(xs)), 1)
	print("%-8s ô %3dx%d  chân ở x=%.1f (giữa ô = %.1f, lệch %+.1f)" % (key, cw, ch, m["feet_x"], cw / 2, m["feet_x"] - cw / 2))
with open(os.path.join(DIR, "chars.json"), "w", encoding="utf-8") as f:
	json.dump(meta, f, indent=1)
