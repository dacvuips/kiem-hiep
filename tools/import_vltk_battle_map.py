"""Toạ độ chiến trường Tống Kim từ server VLTK gốc (bản 15 phái) -> data/battle/<tên>.json cho BattleServer / game.

    python tools/import_vltk_battle_map.py [narrow] [378]

Nguồn: settings/battles/maps/<thư mục>/mapinfo.txt (+ các file điểm .txt nó trỏ tới) — mỗi map có 2 khu (Area_1, Area_2):
  homepos      hậu doanh (điểm hồi sinh + điểm vào trận)
  hometrap     ô cổng hậu doanh -> dịch chuyển sang đại doanh (hậu doanh là khu kín, chỉ ra bằng cổng này — hometrap1.lua)
  centertohometrap  ô cổng đại doanh -> dịch chuyển về hậu doanh;  centertrap  ô cổng đại doanh -> ra ngoài chiến trường
  hometocenterpos  đại doanh;  doctornpc  Quân nhu quan;  generalpos  Nguyên soái
Toạ độ gốc là toạ độ LOGIC (y gấp đôi): pixel map của game = (x, y / 2). Toạ độ NPC tính theo ô 32: (x*32, y*32/2).
Khu trại (camp_rect) = hộp bao hậu doanh + đại doanh + các ô cổng, nới thêm CAMP_PAD — lúc báo danh người chơi bị giữ trong đó.
Ghi theo KHU ("areas": {"1": ..., "2": ...}); phe nào đóng khu nào do BattleServer bốc thăm mỗi trận (battlehead.lua camparea).
"""
import json
import os
import re
import sys

from vltk_source import SETTINGS

sys.stdout.reconfigure(encoding="utf-8", errors="replace")
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CAMP_PAD = 160
AREAS = {"1": "Area_1", "2": "Area_2"}


def read_gbk(path):
	with open(path, "rb") as f:
		return f.read().decode("gbk", "replace")


def ini_sections(text):
	out, cur = {}, None
	for line in text.splitlines():
		line = line.strip()
		if not line or line.startswith(";"):
			continue
		m = re.match(r"\[(.+)\]$", line)
		if m:
			cur = out.setdefault(m.group(1), {})
		elif cur is not None and "=" in line:
			k, v = line.split("=", 1)
			cur[k.strip().lower()] = v.strip()
	return out


def points(rel):
	path = os.path.join(str(SETTINGS.parent), *rel.replace("\\\\", "\\").strip("\\").split("\\"))
	pts = []
	for line in read_gbk(path).splitlines()[1:]:
		parts = line.split()
		if len(parts) >= 2 and parts[0].lstrip("-").isdigit():
			pts.append([int(parts[0]), int(parts[1]) // 2])
	return pts


def xy_cell(v):
	x, y = (int(s) for s in v.split(","))
	return [x * 32, y * 32 // 2]


def main():
	folder = sys.argv[1] if len(sys.argv) > 1 else "narrow"
	map_id = int(sys.argv[2]) if len(sys.argv) > 2 else 378
	info = ini_sections(read_gbk(os.path.join(str(SETTINGS), "battles", "maps", folder, "mapinfo.txt")))
	out = {"source": "settings/battles/maps/%s/mapinfo.txt — tools/import_vltk_battle_map.py" % folder, "map_id": map_id, "areas": {}}
	for key, area in AREAS.items():
		a = info[area]
		home = points(a["homepos"])
		center = points(a["hometocenterpos"])
		traps = points(a["hometrap"]) + points(a["centertrap"])
		allp = home + center + traps
		xs = [p[0] for p in allp]
		ys = [p[1] for p in allp]
		out["areas"][key] = {
			"area": area,
			"home": home,
			"center": center,
			"gate": points(a["centertrap"]),
			"home_trap": points(a["hometrap"]),
			"back_trap": points(a["centertohometrap"]),
			"doctor": xy_cell(a["doctornpc"]),
			"general": xy_cell(a["generalpos"]),
			"camp_rect": [min(xs) - CAMP_PAD, min(ys) - CAMP_PAD, max(xs) - min(xs) + 2 * CAMP_PAD, max(ys) - min(ys) + 2 * CAMP_PAD],
		}
		r = out["areas"][key]["camp_rect"]
		print("khu %s (%s): %d điểm hậu doanh, %d đại doanh, khu trại %dx%d tại (%d,%d)" % (key, area, len(home), len(center), r[2], r[3], r[0], r[1]))
	dest = os.path.join(ROOT, "data", "battle", "map_%d.json" % map_id)
	os.makedirs(os.path.dirname(dest), exist_ok=True)
	with open(dest, "w", encoding="utf-8", newline="\n") as f:
		json.dump(out, f, ensure_ascii=False, indent=1)
	print("->", dest)


if __name__ == "__main__":
	main()
