import json
import os
import sys

sys.stdout.reconfigure(encoding="utf-8")

with open("data/maps/map_catalog.json", "r", encoding="utf-8") as f:
    catalog = json.load(f)

catalog_maps = {m["id"]: m for m in catalog.get("maps", [])}

boss_list = [
    {"name": "Huyền Giác Đại Sư", "id": 740, "map_id": 320, "map_name": "Chân Núi Trường Bạch"},
    {"name": "Cổ Bách", "id": 566, "map_id": 123, "map_name": "Lão Hổ Động"},
    {"name": "Đường Bất Nhiễm", "id": 741, "map_id": 319, "map_name": "Lâm Du Quan"},
    {"name": "Bạch Doanh Doanh", "id": 742, "map_id": 224, "map_name": "Sa Mạc Địa Biểu"},
    {"name": "Lam Y Y", "id": 582, "map_id": 75, "map_name": "Xi Vưu Động"},
    {"name": "Thanh Tiếu Sư Thái", "id": 743, "map_id": 321, "map_name": "Trường Bạch Sơn Nam"},
    {"name": "Hà Linh Phiêu", "id": 568, "map_id": 322, "map_name": "Trường Bạch Sơn Bắc"},
    {"name": "Chung Linh Tú", "id": 567, "map_id": 93, "map_name": "Tiến Cúc Động"},
    {"name": "Yên Hiểu Trái", "id": 744, "map_id": 337, "map_name": "Thuyền Phong Lăng Độ"},
    {"name": "Mạnh Thương Lương", "id": 583, "map_id": 225, "map_name": "Sa Mạc Sơn Động 1"},
    {"name": "Hà Nhân Ngã", "id": 745, "map_id": 226, "map_name": "Sa Mạc Sơn Động 2"},
    {"name": "Gia Luật Tị Ly", "id": 563, "map_id": 227, "map_name": "Sa Mạc Sơn Động 3"},
    {"name": "Hoàn Nhan Tuyết Y", "id": 564, "map_id": 340, "map_name": "Mạc Cao Quật"},
    {"name": "Đoan Mộc Duệ", "id": 565, "map_id": 124, "map_name": "Hiên Viên Động"},
    {"name": "Đạo Thanh Chân Nhân", "id": 562, "map_id": 321, "map_name": "Trường Bạch Sơn Nam"},
    {"name": "Sơn Tư Nam", "id": 746, "map_id": 322, "map_name": "Trường Bạch Sơn Bắc"},
    {"name": "Tuyền Cơ Tử", "id": 747, "map_id": 340, "map_name": "Mạc Cao Quật"},
    {"name": "Diệu Như", "id": 513, "map_id": 162, "map_name": "Đại Lý Phủ"},
    {"name": "Liễu Thanh Thanh", "id": 523, "map_id": 11, "map_name": "Thành Đô"},
    {"name": "Trương Tông Chính", "id": 511, "map_id": 9, "map_name": "Trường Giang Đầu Nguồn"},
    {"name": "Độc Cô Cầu Kiếm", "id": 1038, "map_id": 489, "map_name": "Thách Thức Ải 28"}
]

print("=== CHECKING BOSS_LIST MAPS IN CATALOG & DISK ===")
for b in boss_list:
    mid = b["map_id"]
    in_cat = mid in catalog_maps
    cat_entry = catalog_maps.get(mid, {})
    cat_name = cat_entry.get("name", "N/A")
    cat_dir = cat_entry.get("dir", f"res://world/maps/map_{mid}")
    disk_path = cat_dir.replace("res://", "")
    disk_exists = os.path.exists(disk_path)
    
    status = "OK" if in_cat and disk_exists else "FAIL"
    print(f"[{status}] Boss: {b['name']:<20} | boss_id: {b['id']:<4} | map_id: {mid:<3} | Catalog: {in_cat} ({cat_name}) | Disk: {disk_exists} ({disk_path})")

print("\n=== SCANNING ALL MAPS IN world/maps/ ===")
all_map_dirs = [d for d in os.listdir("world/maps") if os.path.isdir(os.path.join("world/maps", d)) and d.startswith("map_")]
all_map_ids = sorted([int(d.replace("map_", "")) for d in all_map_dirs if d.replace("map_", "").isdigit()])
print(f"Total map dirs in world/maps: {len(all_map_dirs)}")
print(f"Map IDs on disk: {all_map_ids}")

missing_from_catalog = [mid for mid in all_map_ids if mid not in catalog_maps]
print(f"Map IDs on disk but NOT in catalog ({len(missing_from_catalog)}): {missing_from_catalog}")
for mid in missing_from_catalog:
    p = os.path.join("world", "maps", f"map_{mid}", "map.json")
    mname = "Unknown"
    if os.path.exists(p):
        try:
            with open(p, "r", encoding="utf-8") as mf:
                mdata = json.load(mf)
                mname = mdata.get("name", "Unknown")
        except:
            pass
    print(f"  map_{mid}: {mname}")
