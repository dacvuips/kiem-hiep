"""Xuất các MAP VƯỢT ẢI THU GỌN (10 x 6 region giữa map gốc, kèm quái — tạo bằng editor_map/worldgen/make_vuotai.py,
map "vuotai/<tên>" trong tool map) vào game: world/maps/map_<số map>/, rồi trỏ danh mục data/maps/map_catalog.json vào đó.

    python tools/export_vuotai_maps.py               # xuất mọi map trong vuotai_maps.json
    python tools/export_vuotai_maps.py --only 2 53   # chỉ các map số 2, 53

Giống export_training_maps.py (cùng cách xuất / đồng bộ / nav graph) nhưng nguồn là map thu gọn; không nhập lại quái từ
script gốc (quái đã nằm sẵn trong map thu gọn). Map có trong vuotai_maps.json mà chưa có trong danh mục thì được thêm vào.
"""
import argparse
import collections
import gzip
import json
import os
import subprocess
import sys
import time
import urllib.parse

sys.stdout.reconfigure(encoding="utf-8", errors="replace")
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import export_training_maps as etm  # noqa: E402
import update_main_map  # noqa: E402

VUOTAI = os.path.join(etm.TOOL_DIR, "worldgen", "out", "vuotai_maps.json")


def export_map(tool_id, dest):
	q = urllib.parse.quote(tool_id)
	etm.http("/api/map?id=" + q)
	etm.http("/api/godot/export?mode=full&id=" + q, {})
	start = time.time()
	while True:
		time.sleep(2)
		st = etm.http("/api/godot/status?id=" + q)
		if st["state"] in ("done", "error", "idle") and st.get("map_id") == tool_id:
			break
		if time.time() - start > etm.EXPORT_TIMEOUT:
			raise RuntimeError("xuất quá lâu")
	if st["state"] == "error":
		raise RuntimeError(st.get("error"))
	src = st.get("out_dir_map") or st.get("out_dir")
	update_main_map.validate(src)
	copied, unchanged, removed = update_main_map.sync_folder(src, dest)
	print("    đồng bộ: %d mới/đổi, %d giữ nguyên, %d xoá" % (copied, unchanged, removed))
	with open(os.path.join(dest, "map.json"), encoding="utf-8") as f:
		data = json.load(f)
	if data.get("minimap"):
		update_main_map.shrink_minimap(data["minimap"], dest)
	if data.get("format") == "chunks":
		subprocess.run([sys.executable, os.path.join(HERE, "build_nav_graph.py"), dest], check=True)


def spawn_summary(dest, monsters):
	"""quái thật trong map đã xuất: (số con, [{t, name, level, count}], cấp phổ biến nhất)"""
	p = os.path.join(dest, "spawns.json.gz")
	items = []
	if os.path.isfile(p):
		with gzip.open(p, "rt", encoding="utf-8") as f:
			raw = json.load(f)
		items = raw if isinstance(raw, list) else [n for v in raw.values() for n in (v if isinstance(v, list) else [])]
	else:
		with open(os.path.join(dest, "map.json"), encoding="utf-8") as f:
			items = json.load(f).get("npcs", [])
	mons = [n for n in items if isinstance(n, dict) and n.get("role") == "monster"]
	cnt = collections.Counter(int(n["t"]) for n in mons)
	lv = collections.Counter(int(n.get("lv", 0)) for n in mons)
	top = {}
	for n in mons:
		top[int(n["t"])] = max(top.get(int(n["t"]), 0), int(n.get("lv", 0)))
	lst = [{"t": t, "name": str(monsters.get(str(t), {}).get("name", "?")), "level": top[t], "count": c} for t, c in cnt.most_common()]
	return len(mons), lst, (lv.most_common(1)[0][0] if lv else 0)


def main():
	ap = argparse.ArgumentParser()
	ap.add_argument("--only", type=int, nargs="*")
	args = ap.parse_args()
	with open(VUOTAI, encoding="utf-8") as f:
		vuotai = json.load(f)
	if args.only:
		vuotai = [v for v in vuotai if v["id"] in args.only]
	with open(etm.MONSTERS, encoding="utf-8") as f:
		monsters = json.load(f)
	names = etm.map_names()
	proc = etm.ensure_server()
	done, failed = {}, {}
	try:
		for v in vuotai:
			num = int(v["id"])
			dest = os.path.join(etm.OUT_DIR, "map_%d" % num)
			print("Map %d %s <- %s ..." % (num, v["name"], v["map"]), flush=True)
			try:
				export_map(v["map"], dest)
				done[num] = (v, dest)
			except Exception as e:  # noqa: BLE001 — 1 map lỗi không dừng cả lô
				failed[num] = str(e)
				print("    LỖI: %s" % e)
	finally:
		if proc is not None:
			proc.terminate()
	with open(etm.CATALOG, encoding="utf-8") as f:
		cat = json.load(f)
	by_id = {int(e["id"]): e for e in cat["maps"]}
	for num, (v, dest) in done.items():
		count, lst, level = spawn_summary(dest, monsters)
		e = by_id.get(num)
		if e is None:
			name, kind = names.get(num, (v["name"], ""))
			e = {"id": num, "name": name or v["name"], "kind": kind, "level": level or 1, "monster_count": 0, "monsters": [], "dir": ""}
			cat["maps"].append(e)
			by_id[num] = e
		e["dir"] = "res://world/maps/map_%d" % num
		e["monster_count"] = count
		if lst:
			e["monsters"] = lst
		e["vuotai"] = v["map"]
	cat["maps"].sort(key=lambda e: (int(e["level"]), int(e["id"])))
	with open(etm.CATALOG, "w", encoding="utf-8", newline="\n") as f:
		json.dump(cat, f, ensure_ascii=False, indent=1)
	print("Xong: %d map xuất, danh mục %d map -> %s" % (len(done), len(cat["maps"]), etm.CATALOG))
	for num, err in failed.items():
		print("  map %d lỗi: %s" % (num, err))


if __name__ == "__main__":
	main()
