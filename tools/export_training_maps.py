"""Xuất các MAP LUYỆN CÔNG của VLTK gốc vào game (world/maps/map_<số map>/) + dựng danh mục data/maps/map_catalog.json
cho màn "Vượt Ải" (tab Thường: nhóm 1x..12x theo cấp quái).

    python tools/export_training_maps.py                 # xuất mọi map còn thiếu + ghi danh mục
    python tools/export_training_maps.py --only 2 11     # chỉ các map số 2, 11
    python tools/export_training_maps.py --catalog-only  # chỉ ghi lại danh mục (không xuất)
    python tools/export_training_maps.py --force         # xuất lại cả map đã có
    python tools/export_training_maps.py --extra 378     # xuất map KHÔNG phải map luyện công (VD chiến trường Tống Kim), không vào danh mục

Nguồn dữ liệu (không bịa):
  - Map nào có quái + cấp quái: script server gốc script/startgame/** (AddNpcNew — chủ yếu monster/trainingmap.lua), đọc bằng
    luanpc.py của tool map. Cấp map = cấp quái phổ biến nhất trên map (map luyện công gốc mỗi map 1 cấp: 10, 20 ... 100).
  - Tên map tiếng Việt: vng_maps.csv / danh sách map của tool map (maplist.ini client VNG).
  - Hình map: tool map (D:/game/tool/editor_map) — script tự bật server của tool nếu chưa chạy, rồi với từng map:
      mở map (nạp từ pak VNG nếu cần) -> nhập NPC + quái từ script gốc vào map (idempotent) -> xuất đầy đủ -> đồng bộ vào game.
"""
import argparse
import collections
import csv
import json
import os
import subprocess
import sys
import time
import urllib.parse
import urllib.request

sys.stdout.reconfigure(encoding="utf-8", errors="replace")
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
sys.path.insert(0, HERE)
import update_main_map  # noqa: E402  (sync_folder / shrink_minimap dùng chung với map chính)

TOOL_DIR = r"D:\game\tool\editor_map"
SCRIPT_DIR = r"D:\game\source_vo-lam-truyen-ky\anh-viet\Server + client full-001\server\script\startgame"
API = "http://127.0.0.1:8765"
OUT_DIR = os.path.join(ROOT, "world", "maps")
CATALOG = os.path.join(ROOT, "data", "maps", "map_catalog.json")
MONSTERS = os.path.join(ROOT, "data", "monsters", "monsters.json")
EXPORT_TIMEOUT = 3600

sys.path.insert(0, TOOL_DIR)
import luanpc  # noqa: E402


def http(path, body=None, timeout=600):
	data = None if body is None else json.dumps(body).encode("utf-8")
	req = urllib.request.Request(API + path, data=data, method="POST" if body is not None else "GET")
	with urllib.request.urlopen(req, timeout=timeout) as r:
		return json.loads(r.read().decode("utf-8"))


def ensure_server():
	try:
		http("/api/godot/status", timeout=3)
		return None
	except OSError:
		pass
	print("Bật server tool map ...")
	proc = subprocess.Popen([sys.executable, "server.py"], cwd=TOOL_DIR, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
	for _ in range(600):
		time.sleep(1)
		try:
			http("/api/godot/status", timeout=3)
			return proc
		except OSError:
			if proc.poll() is not None:
				sys.exit("Server tool map tắt ngay khi bật — chạy thử: cd %s && python server.py" % TOOL_DIR)
	sys.exit("Server tool map không phản hồi")


def training_maps():
	"""{số map: Counter((mẫu quái, cấp) -> số con)} — chỉ vòng sinh quái server THẬT chạy (không tính vòng đã comment)."""
	out, _ = luanpc.collect(SCRIPT_DIR)
	by = collections.defaultdict(collections.Counter)
	for o in out:
		if o["kind"] == "spawn" and not o["disabled"]:
			by[o["map"]][(o["tpl"], o["level"])] += 1
	return by


def map_names():
	names = {}
	with open(os.path.join(TOOL_DIR, "vng_maps.csv"), encoding="utf-8-sig") as f:
		for r in csv.DictReader(f):
			names[int(r["id"])] = (r["name_vi"].strip(), r["type"].strip())
	return names


def export_one(tool_map, dest):
	mid = tool_map["id"]
	q = urllib.parse.quote(mid)
	http("/api/map?id=" + q)                                          ## map VNG: lần đầu mở = giải nén từ pak
	imp = http("/api/npc/lua_import", {"id": mid, "kinds": ["npc", "spawn"]})
	print("    nhập NPC/quái từ script gốc: %s" % {k: imp[k] for k in imp if isinstance(imp[k], (int, str))})
	http("/api/godot/export?mode=full&id=" + q, {})
	start = time.time()
	while True:
		time.sleep(2)
		st = http("/api/godot/status?id=" + q)
		if st["state"] in ("done", "error", "idle") and st.get("map_id") == mid:
			break
		if time.time() - start > EXPORT_TIMEOUT:
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


def main():
	ap = argparse.ArgumentParser()
	ap.add_argument("--only", type=int, nargs="*")
	ap.add_argument("--catalog-only", action="store_true")
	ap.add_argument("--force", action="store_true")
	ap.add_argument("--extra", type=int, nargs="*", default=[])
	args = ap.parse_args()

	spawns = training_maps()
	names = map_names()
	with open(MONSTERS, encoding="utf-8") as f:
		monsters = json.load(f)

	todo = (sorted(spawns) if not args.only else [m for m in args.only if m in spawns]) if not args.extra else []
	todo += args.extra
	failed = {}
	if not args.catalog_only:
		proc = ensure_server()
		try:
			tool_maps = {m.get("num"): m for m in http("/api/maps") if m.get("num")}
			for num in todo:
				dest = os.path.join(OUT_DIR, "map_%d" % num)
				if not args.force and os.path.isfile(os.path.join(dest, "map.json")):
					continue
				if num not in tool_maps:
					failed[num] = "tool map không có map số này"
					continue
				print("Map %d %s ..." % (num, names.get(num, ("?",))[0] or tool_maps[num].get("name_vi")))
				try:
					export_one(tool_maps[num], dest)
				except Exception as e:  # noqa: BLE001 — 1 map lỗi không dừng cả lô
					failed[num] = str(e)
					print("    LỖI: %s" % e)
		finally:
			if proc is not None:
				proc.terminate()

	entries = []
	for num in sorted(spawns):
		counter = spawns[num]
		levels = collections.Counter()
		mons = collections.Counter()
		mon_level = {}
		for (tpl, lv), c in counter.items():
			levels[lv] += c
			mons[tpl] += c
			mon_level[tpl] = max(mon_level.get(tpl, 0), lv)
		dest = os.path.join(OUT_DIR, "map_%d" % num)
		name, kind = names.get(num, ("", ""))
		if not name:
			try:
				with open(os.path.join(dest, "map.json"), encoding="utf-8") as f:
					name = json.load(f).get("title", "")
			except OSError:
				pass
		entries.append({
			"id": num,
			"name": name or "Map %d" % num,
			"kind": kind,
			"level": levels.most_common(1)[0][0],
			"monster_count": sum(counter.values()),
			"monsters": [{"t": t, "name": str(monsters.get(str(t), {}).get("name", "?")), "level": mon_level[t], "count": c}
						 for t, c in mons.most_common()],
			"dir": "res://world/maps/map_%d" % num if os.path.isfile(os.path.join(dest, "map.json")) else "",
		})
	os.makedirs(os.path.dirname(CATALOG), exist_ok=True)
	with open(CATALOG, "w", encoding="utf-8", newline="\n") as f:
		json.dump({"source": "script/startgame (AddNpcNew) — tools/export_training_maps.py", "maps": entries}, f, ensure_ascii=False, indent=1)
	print("Danh mục: %d map (%d đã có hình map) -> %s" % (len(entries), sum(1 for e in entries if e["dir"]), CATALOG))
	for num, err in failed.items():
		print("  map %d lỗi: %s" % (num, err))


if __name__ == "__main__":
	main()
