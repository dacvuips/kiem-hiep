"""Cập nhật MAP CHÍNH của game (world/main_map) từ thư mục map xuất bởi tool map.

    python tools/update_main_map.py "<đường dẫn thư mục map vừa xuất>" [--remove-old] [--import --godot "<godot console exe>"]

Việc tool làm (bạn chỉ cần xuất map ở tool map, rồi chạy lệnh trên):
  1. Kiểm tra thư mục xuất đủ file (map.json, tiles/, regions/, sprites/).
  2. ĐỒNG BỘ vào world/main_map (tên cố định, không phụ thuộc tên thư mục xuất): chỉ chép file mới/đổi, xoá file không còn trong bản xuất (cùng file .import của nó).
     File ảnh không đổi giữ nguyên nên Godot KHÔNG phải import lại cả nghìn ảnh.
  3. Giữ đúng 1 bản VltkMap.gd (class_name VltkMap) ở world/VltkMap.gd — bản trong thư mục map được lấy ra rồi xoá,
     tránh lỗi trùng class khi có nhiều thư mục map. Xoá luôn Player.gd / MapDemo.gd mẫu.
  3b. Mini map: tool map đã xuất sẵn minimap.jpg / minimap_npc.jpg + mục "minimap" trong map.json (nằm trong thư mục map, được
      đồng bộ cùng). Tool chỉ kiểm tra và tra thêm tên tiếng Việt của map từ client VNG (world/minimap/minimap.json).
  4. Trỏ scene map chính (world/vltk_world.tscn + mặc định trong vltk_world.gd) sang thư mục map mới.
  5. --remove-old: xoá các thư mục world/map_* cũ còn sót (từ cách đặt tên cũ theo mã). Không có cờ này thì chỉ liệt kê.
  6. --import: chạy Godot headless --import để nhập ảnh mới (không cần thì mở editor, Godot tự nhập khi bật lại cửa sổ).
Đóng scene vltk_world.tscn / editor trước khi chạy nếu có thể, để editor không ghi đè lại file đã sửa.
"""
import argparse
import hashlib
import json
import os
import re
import shutil
import subprocess
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
sys.stdout.reconfigure(encoding="utf-8", errors="replace")  # console Windows mặc định không in được tiếng Việt

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
WORLD = os.path.join(ROOT, "world")
MAIN_MAP = "main_map"   ## thư mục map chính CỐ ĐỊNH trong project (res://world/main_map), dù tool map đặt tên thư mục xuất là gì
DEMO_FILES = {"Player.gd", "MapDemo.gd"}
SCRIPT_FILES = {"VltkMap.gd"}
SKIP_FILES = {"manifest.json"}   ## danh sách file để tải qua mạng (base_url) — game đóng gói sẵn trong project không cần
## SortedMap (world/vltk_world.gd) dựa vào các tên này của VltkMap — bản VltkMap.gd mới phải còn đủ.
REQUIRED_IN_VLTKMAP = ["class_name VltkMap", "func _show_region", "var _objects", "var objects_root", "var focus", "func is_blocked", "var grid"]


def sha(path):
	h = hashlib.sha1()
	with open(path, "rb") as f:
		for chunk in iter(lambda: f.read(1 << 20), b""):
			h.update(chunk)
	return h.hexdigest()


def same(a, b):
	return os.path.isfile(b) and os.path.getsize(a) == os.path.getsize(b) and sha(a) == sha(b)


def list_files(base):
	out = {}
	for dp, _, fs in os.walk(base):
		for f in fs:
			p = os.path.join(dp, f)
			out[os.path.relpath(p, base).replace("\\", "/")] = p
	return out


def validate(src):
	if not os.path.exists(os.path.join(src, "map.json")):
		sys.exit("Thư mục xuất thiếu 'map.json' — chọn đúng thư mục map_xxxxxxxx do tool map xuất ra.")
	with open(os.path.join(src, "map.json"), encoding="utf-8") as f:
		data = json.load(f)
	## Nền có 2 kiểu: "tiles" (ảnh ghép sẵn tiles/X_Y.webp) hoặc "atlas" (atlas/atlas_N.png + danh sách ô trong regions/*.json, nhẹ hơn nhiều).
	need = ["regions", "sprites"] + (["atlas"] if data.get("ground_mode") == "atlas" else ["tiles"])
	for name in need:
		if not os.path.exists(os.path.join(src, name)):
			sys.exit("Thư mục xuất thiếu '%s' — chọn đúng thư mục map_xxxxxxxx do tool map xuất ra." % name)
	for key in ("regions", "obstacle", "traps", "tile_ext", "tile_px", "min_x", "max_x", "min_y", "max_y"):
		if key not in data:
			sys.exit("map.json thiếu trường '%s' — bản xuất quá cũ, hãy xuất lại bằng tool map mới." % key)
	print("  Kiểu nền: %s" % data.get("ground_mode", "tiles"))
	return data


def sync_folder(src, dest):
	src_files = {k: v for k, v in list_files(src).items() if os.path.basename(k) not in DEMO_FILES | SCRIPT_FILES | SKIP_FILES}
	copied = unchanged = removed = 0
	os.makedirs(dest, exist_ok=True)
	for rel, path in src_files.items():
		target = os.path.join(dest, *rel.split("/"))
		if same(path, target):
			unchanged += 1
			continue
		os.makedirs(os.path.dirname(target), exist_ok=True)
		shutil.copy2(path, target)
		copied += 1
		## Ảnh đổi nội dung -> bỏ .import cũ để Godot nhập lại đúng.
		if os.path.isfile(target + ".import"):
			os.remove(target + ".import")
	for rel, path in list_files(dest).items():
		if rel.endswith((".import", ".uid")) or os.path.basename(rel) in DEMO_FILES | SCRIPT_FILES:
			continue
		if os.path.basename(rel) in SKIP_FILES and rel not in src_files:
			os.remove(path)
			continue
		if rel not in src_files:
			os.remove(path)
			for extra in (path + ".import", path + ".uid"):
				if os.path.isfile(extra):
					os.remove(extra)
			removed += 1
	return copied, unchanged, removed


def install_vltk_map_script(src, dest):
	"""Đưa VltkMap.gd về world/VltkMap.gd (1 bản duy nhất), xoá bản trong thư mục map + file mẫu."""
	candidates = [os.path.join(src, "VltkMap.gd"), os.path.join(dest, "VltkMap.gd")]
	new_script = next((c for c in candidates if os.path.isfile(c)), None)
	target = os.path.join(WORLD, "VltkMap.gd")
	if new_script is not None:
		text = open(new_script, encoding="utf-8").read()
		missing = [r for r in REQUIRED_IN_VLTKMAP if r not in text]
		if missing:
			sys.exit("VltkMap.gd mới không còn %s — world/vltk_world.gd (SortedMap) cần được cập nhật theo bản này trước khi dùng." % missing)
		if not os.path.isfile(target) or open(target, encoding="utf-8").read() != text:
			shutil.copyfile(new_script, target)
			print("  VltkMap.gd: cập nhật world/VltkMap.gd")
	for folder in (src, dest):
		for name in DEMO_FILES | SCRIPT_FILES:
			for p in (os.path.join(folder, name), os.path.join(folder, name + ".uid")):
				if os.path.isfile(p) and os.path.abspath(folder) != os.path.abspath(WORLD):
					## Không xoá file trong thư mục xuất gốc của người dùng, chỉ xoá bản trong project.
					if os.path.abspath(folder).startswith(os.path.abspath(ROOT)):
						os.remove(p)


def point_world_to(map_name):
	path = "res://world/%s" % map_name
	tscn = os.path.join(WORLD, "vltk_world.tscn")
	text = open(tscn, encoding="utf-8").read()
	new = re.sub(r'map_dir = "[^"]*"', 'map_dir = "%s"' % path, text)
	if new != text:
		open(tscn, "w", encoding="utf-8", newline="\n").write(new)
	gd = os.path.join(WORLD, "vltk_world.gd")
	text = open(gd, encoding="utf-8").read()
	new = re.sub(r'(@export_dir var map_dir: String = )"[^"]*"', r'\1"%s"' % path, text)
	if new != text:
		open(gd, "w", encoding="utf-8", newline="\n").write(new)
	print("  Map chính -> %s" % path)


def check_minimap(data, dest):
	"""Mini map nằm NGAY trong thư mục map (map.json["minimap"]: file, px_per_region, min_x, min_y...) — tool map xuất sẵn.
	Chỉ còn lấy thêm TÊN tiếng Việt của map từ client VNG (best-effort) để hiện trên khung mini map."""
	info = data.get("minimap")
	if not info:
		print("  Mini map: map.json KHÔNG có mục 'minimap' — xuất lại map bằng tool map mới (bản có mini map).")
		return
	for key in ("file", "file_npc"):
		if key in info and not os.path.isfile(os.path.join(dest, info[key])):
			print("  Mini map: thiếu file %s trong thư mục map" % info[key])
	print("  Mini map: %s (%dx%d, %d px/vùng, %d NPC)" % (info.get("file"), info.get("width", 0), info.get("height", 0), info.get("px_per_region", 0), info.get("npc_count", 0)))
	## Ảnh mini map cũ lấy từ client (map trước) đã lỗi thời -> xoá.
	old = os.path.join(WORLD, "minimap", "minimap.jpg")
	for p in (old, old + ".import"):
		if os.path.isfile(p):
			os.remove(p)
	try:
		import import_vltk_minimap
		title = import_vltk_minimap.write_title(dest)
		print("  Tên map trên khung mini map: %s" % (title or "(không tra được trong client — hiện 'Bản đồ')"))
	except Exception as e:  # noqa: BLE001 — thiếu client/iconv không được làm hỏng bước cập nhật map
		print("  Tên map: bỏ qua (%s)" % e)


def main():
	ap = argparse.ArgumentParser()
	ap.add_argument("export_dir")
	ap.add_argument("--remove-old", action="store_true")
	ap.add_argument("--import", dest="do_import", action="store_true")
	ap.add_argument("--godot", default="")
	args = ap.parse_args()

	src = os.path.abspath(args.export_dir)
	data = validate(src)
	dest = os.path.join(WORLD, MAIN_MAP)
	print("Map chính <- %s: %d vùng, %d ô trap, %d NPC" % (os.path.basename(os.path.normpath(src)), len(data["regions"]), len(data["traps"]), len(data.get("npcs", []))))

	if os.path.abspath(src) == os.path.abspath(dest):
		print("  (thư mục xuất chính là world/%s — chỉ chỉnh lại script/đường dẫn)" % MAIN_MAP)
	else:
		copied, unchanged, removed = sync_folder(src, dest)
		print("  Đồng bộ: chép %d, giữ nguyên %d, xoá %d" % (copied, unchanged, removed))
	install_vltk_map_script(src, dest)
	point_world_to(MAIN_MAP)
	check_minimap(data, dest)

	olds = [d for d in os.listdir(WORLD) if re.fullmatch(r"map_[0-9a-fA-F]+", d)
			and os.path.isfile(os.path.join(WORLD, d, "map.json"))]
	for d in olds:
		if args.remove_old:
			shutil.rmtree(os.path.join(WORLD, d))
			print("  Đã xoá thư mục map cũ world/%s" % d)
		else:
			print("  CÒN thư mục map cũ world/%s (không dùng nữa; thêm --remove-old để xoá)" % d)

	if args.do_import:
		godot = args.godot or os.environ.get("GODOT", "")
		if not godot or not os.path.isfile(godot):
			sys.exit("Cần --godot \"<đường dẫn Godot_..._console.exe>\" để chạy --import.")
		print("  Đang nhập ảnh vào Godot (có thể mất vài phút nếu nhiều ảnh mới)...")
		subprocess.run([godot, "--headless", "--path", ROOT, "--import"], check=False, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
	else:
		print("  Xong. Mở/chuyển lại cửa sổ Godot để nó nhập ảnh mới (hoặc chạy lại với --import --godot ...).")


if __name__ == "__main__":
	main()
