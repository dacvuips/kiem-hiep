"""(Dự phòng cho map xuất bản cũ chưa có minimap) Lấy ẢNH BẢN ĐỒ NHỎ (mini map) gốc của map chính từ client VNG -> world/minimap/minimap.jpg.

    python tools/import_vltk_minimap.py [thư_mục_map = world/map_xxxxxxxx đang dùng]

Theo KScenePlaceMapC gốc: ảnh toàn map nằm ở <đường dẫn thư mục map> + "24.jpg" (tên thư mục map lấy từ trường "name" trong map.json),
trong pak dùng dấu gạch ngược làm phân cách. Ảnh đã có sẵn chấm vàng + tên địa điểm (Tiệm tạp hóa, Rương chứa đồ...).
Tỉ lệ ảnh -> map: 1 pixel ảnh = (bề rộng map / bề rộng ảnh) pixel map (map này: 16), gốc ảnh = góc trên-trái vùng (min_x, min_y).
"""
import json
import os
import re
import sys

sys.path.insert(0, os.path.dirname(__file__))
import vltk_pak  # noqa: E402

VNG = r"D:\game\source_vo-lam-truyen-ky\vng\Level Up Games\Vo Lam Truyen Ky 2.0"
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "world", "minimap", "minimap.jpg")


BS = chr(92)


def _iconv() -> str:
	import shutil
	found = shutil.which("iconv")
	if found:
		return found
	for cand in (BS.join(["C:", "Program Files", "Git", "usr", "bin", "iconv.exe"]),
			BS.join(["C:", "Program Files (x86)", "Git", "usr", "bin", "iconv.exe"])):
		if os.path.isfile(cand):
			return cand
	return ""


def lookup_title(pl, path_key: bytes) -> str:
	"""Tên tiếng Việt của map từ maplist.ini: mục "N=<đường dẫn>" trùng -> dòng "N_name=<tên TCVN3>"."""
	import subprocess
	raw = pl.read("settings/maplist.ini")
	exe = _iconv()
	if raw is None or not exe:
		return ""
	number = None
	for line in raw.split(b"\r\n"):
		m = re.match(rb"^(\d+)=(.+)$", line)
		if m and m.group(2).strip() == path_key:
			number = m.group(1)
			break
	if number is None:
		return ""
	for line in raw.split(b"\r\n"):
		if line.startswith(number + b"_name="):
			out = subprocess.run([exe, "-f", "TCVN5712-1", "-t", "UTF-8", "-c"], input=line.split(b"=", 1)[1], capture_output=True)
			return out.stdout.decode("utf-8", "replace").strip()
	return ""


def write_title(map_dir: str) -> str:
	"""Tra TÊN tiếng Việt của map trong client VNG (maplist.ini) và ghi world/minimap/minimap.json {"title"}."""
	with open(os.path.join(map_dir, "map.json"), encoding="utf-8") as f:
		name = json.load(f)["name"]
	pl = vltk_pak.PakList.__new__(vltk_pak.PakList)
	pl.client_dir, pl.paks = VNG, []
	for n in "common slistcl update minimap res1 res2 freeresource skills spr resource map font sound".split():
		p = os.path.join(VNG, "data", n + ".pak")
		if os.path.isfile(p):
			pl.paks.append(vltk_pak.PakFile(p))
	title = lookup_title(pl, (BS + "maps" + BS + name.replace("/", BS)).encode("gbk"))
	os.makedirs(os.path.dirname(OUT), exist_ok=True)
	with open(os.path.join(os.path.dirname(OUT), "minimap.json"), "w", encoding="utf-8") as f:
		json.dump({"title": title}, f, ensure_ascii=False)
	return title


def extract(map_dir: str) -> bool:
	with open(os.path.join(map_dir, "map.json"), encoding="utf-8") as f:
		name = json.load(f)["name"]
	pl = vltk_pak.PakList.__new__(vltk_pak.PakList)
	pl.client_dir, pl.paks = VNG, []
	for n in "common slistcl update minimap res1 res2 freeresource skills spr resource map font sound".split():
		p = os.path.join(VNG, "data", n + ".pak")
		if os.path.isfile(p):
			pl.paks.append(vltk_pak.PakFile(p))
	base = BS + "maps" + BS + name.replace("/", BS)
	data = pl.read(base + "24.jpg")
	if data is None:
		return False
	os.makedirs(os.path.dirname(OUT), exist_ok=True)
	with open(OUT, "wb") as f:
		f.write(data)
	with open(os.path.join(os.path.dirname(OUT), "minimap.json"), "w", encoding="utf-8") as f:
		json.dump({"title": lookup_title(pl, base.encode("gbk"))}, f, ensure_ascii=False)
	return True


## Nút trên khung mini map gốc (UiMiniMapSmall.ini): mỗi spr có 3 frame = Up / Down / Over, 14x14 px.
BUTTONS = {
	"switch": "小地图－切换按钮0.spr",
	"world": "小地图－世界大地图按钮.spr",
	"cave": "小地图－洞窟.spr",
	"flag": "小地图－旗帜按钮.spr",
}
UI_DIR =BS + "spr" + BS + "ui3" + BS + "小地图" + BS


def extract_buttons() -> int:
	import tempfile
	import spr_to_png
	pl = vltk_pak.PakList.__new__(vltk_pak.PakList)
	pl.client_dir, pl.paks = VNG, []
	for n in "common slistcl update minimap res1 res2 freeresource skills spr resource map font sound".split():
		p = os.path.join(VNG, "data", n + ".pak")
		if os.path.isfile(p):
			pl.paks.append(vltk_pak.PakFile(p))
	out_dir = os.path.join(ROOT, "ui", "minimap")
	os.makedirs(out_dir, exist_ok=True)
	count = 0
	for key, spr in BUTTONS.items():
		data = pl.read(UI_DIR + spr)
		if data is None:
			print("  thiếu", key)
			continue
		fd, tmp = tempfile.mkstemp(suffix=".spr")
		with os.fdopen(fd, "wb") as f:
			f.write(data)
		images, _ = spr_to_png.read_spr(tmp)
		os.remove(tmp)
		for i, im in enumerate(images[:3]):
			im.save(os.path.join(out_dir, "btn_%s_%d.png" % (key, i)))
			count += 1
	return count


if __name__ == "__main__":
	sys.stdout.reconfigure(encoding="utf-8", errors="replace")
	if len(sys.argv) > 1:
		folder = sys.argv[1]
	else:
		world = os.path.join(ROOT, "world")
		folders = [d for d in os.listdir(world) if re.fullmatch(r"map_[0-9a-fA-F]+", d) and os.path.isfile(os.path.join(world, d, "map.json"))]
		if not folders:
			sys.exit("Không thấy thư mục world/map_xxxxxxxx")
		folder = os.path.join(world, folders[0])
	print("Nút mini map:", extract_buttons(), "ảnh -> ui/minimap/")
	print("OK -> world/minimap/minimap.jpg" if extract(folder) else "Không tìm thấy ảnh mini map của map này trong client VNG")
