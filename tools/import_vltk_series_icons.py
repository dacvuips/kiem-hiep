"""Ảnh HỆ NGŨ HÀNH trên đầu quái / NPC (NamePlate) từ client VLTK 15 phái.

Gốc: KNpc::PaintName (Core/Src/KNpc.cpp, kind_normal) vẽ ảnh GameSetting.ini [Series] Image = \\Spr\\Ui3\\Npc\\series%d.spr
(%d = hệ 0 Kim, 1 Mộc, 2 Thủy, 3 Hỏa, 4 Thổ), frame 0. Script đọc 5 file đó trong pak client (vltk_source) -> PNG.

    python tools/import_vltk_series_icons.py      -> assets/ui/series/series_0.png .. series_4.png
"""
import os
import sys
import tempfile

sys.stdout.reconfigure(encoding="utf-8", errors="replace")
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import spr_to_png  # noqa: E402
import vltk_source  # noqa: E402

OUT_DIR = os.path.join(os.path.dirname(HERE), "assets", "ui", "series")
SPR_PATH = "\\spr\\Ui3\\Npc\\series%d.spr"


def main():
	os.makedirs(OUT_DIR, exist_ok=True)
	tmp = os.path.join(tempfile.mkdtemp(), "series.spr")
	for series in range(5):
		data = vltk_source.client_file(SPR_PATH % series)
		if data is None:
			print("THIẾU", SPR_PATH % series)
			continue
		with open(tmp, "wb") as f:
			f.write(data)
		images, meta = spr_to_png.read_spr(tmp)
		frame = images[0]
		box = frame.getbbox()
		if box:
			frame = frame.crop(box)
		out = os.path.join(OUT_DIR, "series_%d.png" % series)
		frame.save(out, optimize=True)
		print("hệ %d: %d frame, %dx%d -> %s" % (series, len(images), frame.size[0], frame.size[1], out))


if __name__ == "__main__":
	main()
