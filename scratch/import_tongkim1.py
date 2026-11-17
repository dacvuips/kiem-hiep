import os
import sys
import shutil
import gzip
import json
import re
from PIL import Image
from collections import Counter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = r"D:\game\tool\editor_map\export\map_03862c05"
DEST = os.path.join(ROOT, "world", "maps", "map_tongkim1")
SHARED_SPRITES = os.path.join(ROOT, "world", "maps", "shared_sprites")
CATALOG_PATH = os.path.join(ROOT, "data", "maps", "map_catalog.json")

print("=== BẮT ĐẦU CẬP NHẬT MAP TONGKIM1 VÀO SOURCE ===")
print("Source:", SRC)
print("Dest:", DEST)

os.makedirs(DEST, exist_ok=True)

# 1. Copy atlas
print("\n1. Đang copy atlas...")
src_atlas = os.path.join(SRC, "atlas")
dst_atlas = os.path.join(DEST, "atlas")
if os.path.exists(dst_atlas):
    shutil.rmtree(dst_atlas)
shutil.copytree(src_atlas, dst_atlas)
print(f"  -> Đã copy {len(os.listdir(dst_atlas))} file atlas.")

# 2. Copy chunks
print("\n2. Đang copy chunks (228 chunks địa hình & quái)...")
src_chunks = os.path.join(SRC, "chunks")
dst_chunks = os.path.join(DEST, "chunks")
if os.path.exists(dst_chunks):
    shutil.rmtree(dst_chunks)
shutil.copytree(src_chunks, dst_chunks)
print(f"  -> Đã copy {len(os.listdir(dst_chunks))} chunks.")

# 3. Copy spawns.json.gz
print("\n3. Đang copy spawns.json.gz (toàn bộ 20.722 quái & NPC)...")
shutil.copy2(os.path.join(SRC, "spawns.json.gz"), os.path.join(DEST, "spawns.json.gz"))

# 4. Copy map.json & README.txt
print("\n4. Đang copy map.json và README...")
shutil.copy2(os.path.join(SRC, "map.json"), os.path.join(DEST, "map.json"))
if os.path.exists(os.path.join(SRC, "README.txt")):
    shutil.copy2(os.path.join(SRC, "README.txt"), os.path.join(DEST, "README.txt"))

# 5. Copy & shrink minimap
print("\n5. Đang tối ưu hoá minimap để vừa bộ nhớ Godot (<= 4096px)...")
shutil.copy2(os.path.join(SRC, "minimap.jpg"), os.path.join(DEST, "minimap.jpg"))
if os.path.exists(os.path.join(SRC, "minimap_npc.jpg")):
    shutil.copy2(os.path.join(SRC, "minimap_npc.jpg"), os.path.join(DEST, "minimap_npc.jpg"))

with open(os.path.join(DEST, "map.json"), encoding="utf-8") as f:
    map_data = json.load(f)

info = map_data.get("minimap", {})
old_ppr = int(info.get("px_per_region", 28))
side = max(int(info.get("width", 16212)), int(info.get("height", 9856)))
MINIMAP_MAX_SIDE = 4096

if side > MINIMAP_MAX_SIDE:
    ppr = max(1, old_ppr * MINIMAP_MAX_SIDE // side)
    Image.MAX_IMAGE_PIXELS = None
    for key in ("file", "file_npc"):
        fname = info.get(key, "")
        p = os.path.join(DEST, fname)
        if os.path.exists(p):
            with Image.open(p) as im:
                new_w = im.width * ppr // old_ppr
                new_h = im.height * ppr // old_ppr
                small = im.convert("RGB").resize((new_w, new_h), Image.LANCZOS)
                small.save(p, quality=90, optimize=True)
                new_size = (new_w, new_h)
            print(f"  -> Đã thu nhỏ {fname}: {new_size[0]}x{new_size[1]} (px_per_region: {ppr})")

    info["px_per_region"] = ppr
    info["width"] = new_size[0]
    info["height"] = new_size[1]
    map_data["minimap"] = info

with open(os.path.join(DEST, "map.json"), "w", encoding="utf-8") as f:
    json.dump(map_data, f, ensure_ascii=False, indent=2)

# 6. Copy missing sprites vào shared_sprites
print("\n6. Đang kiểm tra và copy sprite vào world/maps/shared_sprites/...")
src_sprites = os.path.join(SRC, "sprites")
os.makedirs(SHARED_SPRITES, exist_ok=True)
shared_set = set(os.listdir(SHARED_SPRITES))
new_copied = 0
for sf in os.listdir(src_sprites):
    if sf not in shared_set:
        shutil.copy2(os.path.join(src_sprites, sf), os.path.join(SHARED_SPRITES, sf))
        new_copied += 1
print(f"  -> Đã copy {new_copied} sprite mới vào shared_sprites (tổng cộng {len(os.listdir(SHARED_SPRITES))} sprite dùng chung).")

# 7. Xây dựng nav_graph.bin
print("\n7. Đang tạo đồ thị tìm đường nav_graph.bin...")
build_nav_py = os.path.join(ROOT, "tools", "build_nav_graph.py")
os.system(f'python "{build_nav_py}" "{DEST}"')

# 8. Cập nhật data/maps/map_catalog.json
print("\n8. Đang đăng ký map vào danh mục data/maps/map_catalog.json...")
spawns_data = json.load(gzip.open(os.path.join(DEST, "spawns.json.gz")))
monsters_all = [x for x in spawns_data if x.get("role") == "monster"]
print(f"  -> Tổng số quái: {len(monsters_all)}")

# Tổng hợp các loại quái phổ biến
monster_counts = Counter()
for m in monsters_all:
    t = int(m.get("t", 0))
    name = str(m.get("name_vi", m.get("name", "Quái vật")))
    lv = int(m.get("lv", 1))
    monster_counts[(t, name, lv)] += 1

monsters_summary = []
for (t, name, lv), count in monster_counts.most_common(20):
    monsters_summary.append({
        "t": t,
        "name": name,
        "level": lv,
        "count": count
    })

catalog_entry = {
    "id": 44,
    "name": "Chiến Trường Tống Kim (Đại Bản Đồ)",
    "kind": "Battlefield",
    "level": 90,
    "monster_count": len(monsters_all),
    "monsters": monsters_summary,
    "dir": "res://world/maps/map_tongkim1",
    "folder": "res://world/maps/map_tongkim1",
    "drop_diadochi_rate": 0.05,
    "drop_matchi_rate": 0.02,
    "drop_matdo_rate": 0.005
}

with open(CATALOG_PATH, "r", encoding="utf-8") as f:
    catalog = json.load(f)

# Cập nhật hoặc thêm mới entry 44
existing_idx = -1
for i, m in enumerate(catalog.get("maps", [])):
    if m.get("id") == 44 or m.get("dir") == "res://world/maps/map_tongkim1":
        existing_idx = i
        break

if existing_idx >= 0:
    catalog["maps"][existing_idx] = catalog_entry
    print("  -> Đã cập nhật entry 44 trong map_catalog.json")
else:
    catalog["maps"].append(catalog_entry)
    print("  -> Đã thêm mới entry 44 vào map_catalog.json")

with open(CATALOG_PATH, "w", encoding="utf-8") as f:
    json.dump(catalog, f, ensure_ascii=False, indent=2)

print("\n=== HOÀN TẤT THÀNH CÔNG! ===")
