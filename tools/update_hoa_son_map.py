import gzip
import json
import os
import shutil
import subprocess
import sys

sys.stdout.reconfigure(encoding="utf-8", errors="replace")

SRC_EXPORT = r"D:\game\tool\editor_map\export\map_525dc16b"
DEST_MAP = r"D:\game\lam-game\kiem-hiep\world\maps\map_2"
GODOT_EXE = r"C:\Users\Hieu Tran\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe"

DELTA_RX = 124
DELTA_RY = 90
DELTA_PX = DELTA_RX * 512 # 63488
DELTA_PY = DELTA_RY * 512 # 46080

def main():
    print(f"=== BẮT ĐẦU CẬP NHẬT MAP HOA SƠN TỪ {SRC_EXPORT} ===")
    if not os.path.isdir(SRC_EXPORT):
        sys.exit(f"Lỗi: Không tìm thấy thư mục nguồn xuất: {SRC_EXPORT}")
    if not os.path.isdir(DEST_MAP):
        sys.exit(f"Lỗi: Không tìm thấy thư mục đích: {DEST_MAP}")

    # 1. Bảo toàn hình nền cũ sky.jpg và sky.jpg.import
    sky_jpg_path = os.path.join(DEST_MAP, "sky.jpg")
    sky_import_path = os.path.join(DEST_MAP, "sky.jpg.import")
    if not os.path.exists(sky_jpg_path):
        sys.exit(f"Lỗi: Không tìm thấy hình nền {sky_jpg_path} để bảo toàn!")
    sky_jpg_bytes = open(sky_jpg_path, "rb").read()
    sky_import_bytes = open(sky_import_path, "rb").read() if os.path.exists(sky_import_path) else None
    print(f"-> Đã sao lưu trong bộ nhớ hình nền cũ: sky.jpg ({len(sky_jpg_bytes)} bytes)")

    # 2. Đồng bộ atlas
    src_atlas = os.path.join(SRC_EXPORT, "atlas")
    dest_atlas = os.path.join(DEST_MAP, "atlas")
    os.makedirs(dest_atlas, exist_ok=True)
    for fname in os.listdir(src_atlas):
        sf = os.path.join(src_atlas, fname)
        df = os.path.join(dest_atlas, fname)
        if os.path.isfile(sf):
            shutil.copy2(sf, df)
    print(f"-> Đã đồng bộ atlas.")

    # 3. Đồng bộ sprites
    src_sprites = os.path.join(SRC_EXPORT, "sprites")
    dest_sprites = os.path.join(DEST_MAP, "sprites")
    os.makedirs(dest_sprites, exist_ok=True)
    for fname in os.listdir(src_sprites):
        sf = os.path.join(src_sprites, fname)
        df = os.path.join(dest_sprites, fname)
        if os.path.isfile(sf):
            shutil.copy2(sf, df)
    print(f"-> Đã đồng bộ sprites ({len(os.listdir(src_sprites))} files).")

    # 4. Đọc tất cả regions từ chunks nguồn (0_0.json.gz, 1_0.json.gz, ...)
    src_chunks_dir = os.path.join(SRC_EXPORT, "chunks")
    all_regions = {}
    for cf in os.listdir(src_chunks_dir):
        if cf.endswith(".json.gz"):
            cpath = os.path.join(src_chunks_dir, cf)
            with gzip.open(cpath, "rt", encoding="utf-8") as gf:
                cdata = json.load(gf)
                all_regions.update(cdata.get("r", {}))
    print(f"-> Đã nạp {len(all_regions)} regions từ {src_chunks_dir}")

    # 5. Dịch chuyển tọa độ (+DELTA_RX, +DELTA_RY) để khớp chuẩn Võ Lâm (302/236, [77400, 60500])
    shifted_regions = {}
    for rk, rdata in all_regions.items():
        rx, ry = map(int, rk.split(","))
        new_rx = rx + DELTA_RX
        new_ry = ry + DELTA_RY
        new_rk = f"{new_rx},{new_ry}"

        # Covers
        if "covers" in rdata:
            for cov in rdata["covers"]:
                cov[1] += DELTA_PX
                cov[2] += DELTA_PY
                cov[5] += DELTA_PY

        # Objects
        if "objects" in rdata:
            for obj in rdata["objects"]:
                obj["x"] += DELTA_PX
                obj["y"] += DELTA_PY
                obj["sy"] += DELTA_PY

        # NPCs
        if "npcs" in rdata:
            for n in rdata["npcs"]:
                n["px"] += DELTA_PX
                n["py"] += DELTA_PY
                n["x"] = n["px"]
                n["y"] = n["py"] * 2
                n["ix"] += DELTA_PX
                n["iy"] += DELTA_PY
                n["rx"] = new_rx
                n["ry"] = new_ry
                n["uid"] = f"{n.get('t', 0)},{n['x']},{n['y']}"

        shifted_regions[new_rk] = rdata

    # -------------------------------------------------------------------------
    # XỬ LÝ VẬT CẢN (OBSTACLE):
    # 1. Kế thừa các ô đi được (walkable) từ bản đồ cũ (4_3.json.gz.bak) để đảm bảo
    #    toàn bộ mạng lưới đường đi, lối mòn vách núi vốn đã được tinh chỉnh không bị bít.
    # 2. Xử lý triệt để "vật cản vô hình giữa đường" trên toàn bộ cầu gỗ Hoa Sơn:
    #    - Đoạn nối mỏm đá & ván cầu ef879648_17.png tại 151,113 (cx=3..12, cy=25..31)
    #    - Bến đỗ đầu cầu tại 151,114 (cx=0..10, cy=0..7) và lối chạy về nam (cx=3..9, cy=6..14)
    #    - Đoạn sàn cầu 150,113 (cx=10..15, cy=18..30)
    #    - Hành lang toàn tuyến cầu gỗ nối hai đỉnh núi
    # -------------------------------------------------------------------------
    bak_chunk_path = os.path.join(DEST_MAP, "chunks", "4_3.json.gz.bak")
    if os.path.exists(bak_chunk_path):
        print("-> Đang hòa trộn lưới đường đi từ bản đồ cũ (4_3.json.gz.bak)...")
        with gzip.open(bak_chunk_path, "rt", encoding="utf-8") as gf:
            bak_chunk = json.load(gf)
        for rk, rdata in shifted_regions.items():
            if rk in bak_chunk.get("r", {}):
                ob_bak_runs = bak_chunk["r"][rk].get("ob", [])
                arr_bak = bytearray()
                for i in range(0, len(ob_bak_runs), 2):
                    arr_bak.extend([ob_bak_runs[i] & 0xff] * ob_bak_runs[i+1])
                if len(arr_bak) < 512:
                    arr_bak.extend([0] * (512 - len(arr_bak)))

                ob_curr_runs = rdata.get("ob", [])
                arr_curr = bytearray()
                for i in range(0, len(ob_curr_runs), 2):
                    arr_curr.extend([ob_curr_runs[i] & 0xff] * ob_curr_runs[i+1])
                if len(arr_curr) < 512:
                    arr_curr.extend([0] * (512 - len(arr_curr)))

                for idx in range(512):
                    if (arr_bak[idx] >> 4) == 0:
                        arr_curr[idx] = 0

                runs = []
                if arr_curr:
                    curr = arr_curr[0]
                    cnt = 1
                    for b in arr_curr[1:]:
                        if b == curr:
                            cnt += 1
                        else:
                            runs.extend([curr, cnt])
                            curr = b
                            cnt = 1
                    runs.extend([curr, cnt])
                rdata["ob"] = runs

    # Thông thoáng toàn tuyến đường mòn và cầu gỗ Hoa Sơn:
    # Từ điểm thả người chơi (151,118 - 302/236) chạy thẳng lên hướng bắc qua 151,117, 151,116, 151,115, 151,114 tới cầu gỗ 151,113
    # Clear all 9 road corridors across the entire Hoa Son map:
    road_clears = {
        # 1. Main North Road from Spawn (151,118) to Bridge (151,113)
        "151,118": [(cx, cy) for cx in range(0, 14) for cy in range(0, 16)],
        "151,117": [(cx, cy) for cx in range(0, 14) for cy in range(0, 32)],
        "151,116": [(cx, cy) for cx in range(0, 14) for cy in range(0, 32) if not (cx in (2, 3) and cy in (4, 5, 6))],
        "151,115": [(cx, cy) for cx in range(0, 14) for cy in range(0, 32)],
        "151,114": [(cx, cy) for cx in range(0, 14) for cy in range(0, 32)],
        
        # 2. Wooden Bridge crossing & landings
        "151,113": [(cx, cy) for cx in range(0, 16) for cy in range(16, 32)],
        "152,114": [(cx, cy) for cx in range(10, 16) for cy in range(5, 16)],
        "153,114": [(cx, cy) for cx in range(0, 16) for cy in range(4, 16)] +
                   [(cx, cy) for cx in range(0, 12) for cy in range(16, 32)],
                   
        # 3. Eastern Waterfall & South-East Path
        "154,114": [(cx, cy) for cx in range(0, 12) for cy in range(4, 18)],
        "155,116": [(cx, cy) for cx in range(0, 8) for cy in range(0, 32)],
        "155,117": [(cx, cy) for cx in range(0, 8) for cy in range(0, 32)],
        
        # 4. North-East Cliff Path
        "154,113": [(cx, cy) for cx in range(8, 16) for cy in range(24, 32)],
        "155,113": [(cx, cy) for cx in range(0, 8) for cy in range(24, 32)],
        
        # 5. Western Forest Path
        "146,116": [(cx, cy) for cx in range(4, 13) for cy in range(0, 12)],
        "145,115": [(cx, cy) for cx in range(8, 16) for cy in range(2, 16)],
        
        # 6. North-West Approach to Bridge
        "150,113": [(cx, cy) for cx in range(3, 12) for cy in range(0, 15)],
        "149,113": [(cx, cy) for cx in range(6, 16) for cy in range(0, 12)],
        
        # 7. Central Forest Pass
        "148,114": [(cx, cy) for cx in range(2, 9) for cy in range(0, 12)] +
                   [(cx, cy) for cx in range(2, 8) for cy in range(20, 28)],
        "148,115": [(cx, cy) for cx in range(0, 7) for cy in range(0, 18)],
        
        # 8. Southern Path West of Spawn
        "150,118": [(cx, cy) for cx in range(0, 2) for cy in range(8, 12)],
        "149,118": [(cx, cy) for cx in range(0, 2) for cy in range(6, 11)],
        "148,118": [(cx, cy) for cx in range(0, 2) for cy in range(7, 12)] +
                   [(cx, cy) for cx in range(14, 16) for cy in range(8, 12)],
    }

    for rk, cell_list in road_clears.items():
        if rk not in shifted_regions:
            continue
        reg = shifted_regions[rk]
        ob_runs = reg.get("ob", [])
        arr = bytearray()
        for i in range(0, len(ob_runs), 2):
            arr.extend([ob_runs[i] & 0xff] * ob_runs[i+1])
        if len(arr) < 512:
            arr.extend([0] * (512 - len(arr)))
        for cx, cy in cell_list:
            if 0 <= cx < 16 and 0 <= cy < 32:
                arr[cx * 32 + cy] = 0
        if rk == "151,116":
            arr[2 * 32 + 4] = 81 # Vá kín hốc đá 302/232 (77376, 59456)
        runs = []
        if arr:
            curr = arr[0]
            cnt = 1
            for b in arr[1:]:
                if b == curr:
                    cnt += 1
                else:
                    runs.extend([curr, cnt])
                    curr = b
                    cnt = 1
            runs.extend([curr, cnt])
        reg["ob"] = runs

    # Thông thoáng toàn tuyến hành lang cầu gỗ Hoa Sơn
    bridge_path_points = [
        (76780, 57980), (77000, 58100), (77207, 58202), (77350, 58290),
        (77450, 58345), (77500, 58375), (77530, 58395), (77560, 58415),
        (77580, 58435), (77650, 58450)
    ]
    bridge_corridor = {}
    for i in range(len(bridge_path_points) - 1):
        p1 = bridge_path_points[i]
        p2 = bridge_path_points[i+1]
        dist = ((p2[0]-p1[0])**2 + (p2[1]-p1[1])**2)**0.5
        steps = int(dist / 6) + 1
        dx = -(p2[1] - p1[1]) / dist
        dy = (p2[0] - p1[0]) / dist
        for s in range(steps + 1):
            t = s / steps
            x = p1[0] + (p2[0] - p1[0]) * t
            y = p1[1] + (p2[1] - p1[1]) * t
            for offset in range(-40, 41, 5):
                px = x + dx * offset
                py = y + dy * offset
                rx = int(px // 512)
                ry = int(py // 512)
                cx = int((px % 512) // 32)
                cy = int((py % 512) // 16)
                bridge_corridor.setdefault(f"{rx},{ry}", set()).add((cx, cy))

    for rk, cells in bridge_corridor.items():
        if rk not in shifted_regions:
            continue
        reg = shifted_regions[rk]
        ob_runs = reg.get("ob", [])
        arr = bytearray()
        for i in range(0, len(ob_runs), 2):
            arr.extend([ob_runs[i] & 0xff] * ob_runs[i+1])
        if len(arr) < 512:
            arr.extend([0] * (512 - len(arr)))
        for cx, cy in cells:
            if 0 <= cx < 16 and 0 <= cy < 32:
                arr[cx * 32 + cy] = 0
        runs = []
        if arr:
            curr = arr[0]
            cnt = 1
            for b in arr[1:]:
                if b == curr:
                    cnt += 1
                else:
                    runs.extend([curr, cnt])
                    curr = b
                    cnt = 1
            runs.extend([curr, cnt])
        reg["ob"] = runs

    # Gom nhóm theo chunk mới
    by_chunk = {}
    for rk, rdata in shifted_regions.items():
        rx, ry = map(int, rk.split(","))
        cx = rx // 32
        cy = ry // 32
        chunk_key = f"{cx}_{cy}"
        if chunk_key not in by_chunk:
            by_chunk[chunk_key] = {}
        by_chunk[chunk_key][rk] = rdata

    dest_chunks_dir = os.path.join(DEST_MAP, "chunks")
    os.makedirs(dest_chunks_dir, exist_ok=True)
    # Xoá các chunk cũ
    for cf in os.listdir(dest_chunks_dir):
        if cf.endswith(".json.gz"):
            os.remove(os.path.join(dest_chunks_dir, cf))

    # Ghi chunk mới
    chunk_counts = {}
    for ckey, r_dict in by_chunk.items():
        chunk_counts[ckey.replace("_", ",")] = len(r_dict)
        cpath = os.path.join(dest_chunks_dir, f"{ckey}.json.gz")
        cdata = {"size": len(r_dict), "r": r_dict}
        with gzip.open(cpath, "wt", encoding="utf-8") as gf:
            json.dump(cdata, gf, ensure_ascii=False)
        print(f"-> Ghi chunk {ckey}.json.gz gồm {len(r_dict)} regions")

    # 6. Dịch chuyển spawns.json.gz
    src_spawns_path = os.path.join(SRC_EXPORT, "spawns.json.gz")
    dest_spawns_path = os.path.join(DEST_MAP, "spawns.json.gz")
    if os.path.exists(src_spawns_path):
        with gzip.open(src_spawns_path, "rt", encoding="utf-8") as gf:
            spawns = json.load(gf)
        for n in spawns:
            n["px"] += DELTA_PX
            n["py"] += DELTA_PY
            n["x"] = n["px"]
            n["y"] = n["py"] * 2
            n["ix"] += DELTA_PX
            n["iy"] += DELTA_PY
            n["rx"] += DELTA_RX
            n["ry"] += DELTA_RY
            n["uid"] = f"{n.get('t', 0)},{n['x']},{n['y']}"

        with gzip.open(dest_spawns_path, "wt", encoding="utf-8") as gf:
            json.dump(spawns, gf, ensure_ascii=False)
        print(f"-> Cập nhật {len(spawns)} spawns vào {dest_spawns_path}")

    # 7. Cập nhật minimap
    for mf in ["minimap.jpg", "minimap_npc.jpg"]:
        smf = os.path.join(SRC_EXPORT, mf)
        dmf = os.path.join(DEST_MAP, mf)
        if os.path.exists(smf):
            shutil.copy2(smf, dmf)
            # Xoá .import để Godot re-import nếu ảnh thay đổi kích thước
            m_imp = dmf + ".import"
            if os.path.exists(m_imp):
                os.remove(m_imp)
            print(f"-> Sao chép {mf}")

    # 8. Cập nhật map.json
    all_rx = [int(k.split(",")[0]) for k in shifted_regions]
    all_ry = [int(k.split(",")[1]) for k in shifted_regions]
    min_x, max_x = min(all_rx), max(all_rx)
    min_y, max_y = min(all_ry), max(all_ry)

    with open(os.path.join(SRC_EXPORT, "map.json"), "r", encoding="utf-8") as f:
        src_map_json = json.load(f)

    dest_map_json = {
        "version": 2,
        "name": "kiem_hiep_hoa_son",
        "id": "kiem_hiep_hoa_son",
        "cell_w": 32,
        "cell_h": 16,
        "cols_per_region": 16,
        "rows_per_region": 32,
        "region_px": 512,
        "scale": 1,
        "tile_ext": src_map_json.get("tile_ext", "webp"),
        "tile_px": 512,
        "ground_mode": "atlas",
        "traps": [],
        "format": "chunks",
        "chunk": 32,
        "chunks": chunk_counts,
        "minimap": {
            "file": "minimap.jpg",
            "file_npc": "minimap_npc.jpg",
            "px_per_region": 64,
            "min_x": min_x,
            "min_y": min_y,
            "width": (max_x - min_x + 1) * 64,
            "height": (max_y - min_y + 1) * 64,
            "npc_count": src_map_json.get("npc_count", len(spawns))
        },
        "rect": [min_x, min_y, max_x, max_y],
        "min_x": min_x,
        "max_x": max_x,
        "min_y": min_y,
        "max_y": max_y,
        "atlas": "atlas/atlas.json",
        "spawns": "spawns.json.gz",
        "npc_count": src_map_json.get("npc_count", len(spawns)),
        "start": [151, 118],
        "arena_center": [77400, 60500]
    }

    with open(os.path.join(DEST_MAP, "map.json"), "w", encoding="utf-8") as f:
        json.dump(dest_map_json, f, ensure_ascii=False, indent=2)
    print(f"-> Ghi đè map.json thành công (rect: {dest_map_json['rect']}, arena_center: {dest_map_json['arena_center']})")

    # 9. Đảm bảo bảo toàn hình nền cũ sky.jpg
    with open(sky_jpg_path, "wb") as f:
        f.write(sky_jpg_bytes)
    if sky_import_bytes:
        with open(sky_import_path, "wb") as f:
            f.write(sky_import_bytes)
    print("-> Đã đảm bảo file sky.jpg và sky.jpg.import nguyên vẹn 100%.")

    # 10. Tái tạo nav_graph.bin
    print("-> Xây dựng nav_graph.bin...")
    subprocess.run([sys.executable, "tools/build_nav_graph.py", DEST_MAP], check=True)
    print("-> nav_graph.bin tạo thành công.")

    # 11. Cập nhật map_catalog.json
    cat_path = "data/maps/map_catalog.json"
    with open(cat_path, "r", encoding="utf-8") as f:
        catalog = json.load(f)
    for m in catalog["maps"]:
        if m["id"] == 2:
            m["arena_center"] = [77400, 60500]
            m["start"] = [151, 118]
            # Đếm số lượng quái
            m11 = sum(1 for n in spawns if n.get("t") == 11)
            m12 = sum(1 for n in spawns if n.get("t") == 12)
            m["monster_count"] = m11 + m12
            m["monsters"] = [
                {"t": 11, "name": "Heo rừng", "level": 20, "count": m11},
                {"t": 12, "name": "Nhím", "level": 20, "count": m12}
            ]
            break
    with open(cat_path, "w", encoding="utf-8") as f:
        json.dump(catalog, f, ensure_ascii=False, indent=2)
    print(f"-> Đã cập nhật map_catalog.json (quái: {m11} Heo rừng, {m12} Nhím).")

    # 12. Chạy Godot import headless nếu cần
    # (Nếu Godot editor đang mở, editor sẽ tự reload các asset mới cập nhật)
    print("=== CẬP NHẬT MAP HOA SƠN HOÀN TẤT THÀNH CÔNG! ===")

if __name__ == "__main__":
    main()
