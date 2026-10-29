import json
import gzip
import os
import sys

sys.stdout.reconfigure(encoding="utf-8")

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
    {"name": "Độc Cô Cầu Kiếm", "id": 1038, "map_id": 480, "map_name": "Thách Thức Ải 28"}
]

print("=== INSPECTING MAP DATA FOR EACH BOSS ===")
for b in boss_list:
    mid = b["map_id"]
    map_dir = f"world/maps/map_{mid}"
    map_json_path = os.path.join(map_dir, "map.json")
    if not os.path.exists(map_json_path):
        print(f"FAIL: {b['name']} map {mid} has no map.json!")
        continue
    with open(map_json_path, "r", encoding="utf-8") as f:
        mdata = json.load(f)
    
    rect = mdata.get("rect", [0, 0, 1, 1])
    start = mdata.get("start", None)
    arena_center = mdata.get("arena_center", None)
    chunks = mdata.get("chunks", {})
    
    # Calculate default center as vltk_world does:
    if arena_center:
        center = arena_center
        c_src = "arena_center"
    elif start:
        center = [(start[0] + 0.5) * 512.0, (start[1] + 0.5) * 512.0]
        c_src = "start"
    else:
        center = [(rect[0] + rect[2] + 1.0) * 0.5 * 512.0, (rect[1] + rect[3] + 1.0) * 0.5 * 512.0]
        c_src = "rect"
    
    disp_coords = f"{int(center[0] / 256.0)}/{int(center[1] / 256.0)}"
    print(f"Boss: {b['name']:<20} | Map {mid:<3} | Center: ({center[0]:.1f}, {center[1]:.1f}) [Disp {disp_coords}] from {c_src:<12} | rect={rect} | num_chunks={len(chunks)}")
