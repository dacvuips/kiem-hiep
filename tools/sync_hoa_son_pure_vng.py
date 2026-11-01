import gzip
import json
import os
import shutil
import struct
import subprocess
import sys

sys.stdout.reconfigure(encoding="utf-8", errors="replace")

SRC_EXPORT = r"D:\game\tool\editor_map\export\map_525dc16b"
DEST_MAP = r"D:\game\lam-game\kiem-hiep\world\maps\map_2"
VNG_MAP2_DIR = r"D:\game\tool\editor_map\vng_maps\2"
SERVER_MAP_DIR = r"D:\game\source_vo-lam-truyen-ky\anh-viet\Server + client full-001\server\maps\hoa_son_kiem"
GODOT_EXE = r"C:\Users\Hieu Tran\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe"

DELTA_RX = 124
DELTA_RY = 90
DELTA_PX = DELTA_RX * 512 # 63488
DELTA_PY = DELTA_RY * 512 # 46080

def rle(values):
    out = []
    for v in values:
        if out and out[-2] == v:
            out[-1] += 1
        else:
            out += [v, 1]
    return out

def get_vng_obstacle_blob(rx, ry):
    """Đọc trực tiếp 2048 bytes (512 uint32) vật cản nguyên bản VNG từ Region_C.dat"""
    p = os.path.join(VNG_MAP2_DIR, f"v_{ry}", f"{rx}_Region_C.dat")
    if not os.path.exists(p):
        return None
    with open(p, "rb") as f:
        data = f.read()
    n = struct.unpack_from("<I", data, 0)[0]
    secs = [struct.unpack_from("<II", data, 4 + 8 * i) for i in range(n)]
    base = 4 + 8 * n
    blobs = [data[base + o:base + o + l] for o, l in secs]
    if len(blobs[0]) >= 2048:
        return blobs[0][:2048]
    return b"\x00" * 2048

def get_vng_obstacle_list(rx, ry):
    blob = get_vng_obstacle_blob(rx, ry)
    if not blob:
        return [0] * 512
    return list(struct.unpack_from("<512I", blob))

def parse_region(data: bytes):
    n = struct.unpack_from("<I", data, 0)[0]
    secs = [struct.unpack_from("<II", data, 4 + 8 * i) for i in range(n)]
    base = 4 + 8 * n
    blobs = [data[base + o:base + o + l] for o, l in secs]
    while len(blobs) < 6:
        blobs.append(b"")
    return blobs

def build_region(blobs):
    n = len(blobs)
    head = struct.pack("<I", n)
    table = b""
    pos = 0
    for b in blobs:
        table += struct.pack("<II", pos if b else 0, len(b))
        pos += len(b)
    return head + table + b"".join(blobs)

def main():
    print("=================================================================")
    print(">>> CẬP NHẬT MAP HOA SƠN CHUẨN XÁC 100% TỪ VNG SANG SOURCE & GAME")
    print("=================================================================")

    # 1. Bảo toàn hình nền cũ sky.jpg và sky.jpg.import ở map game
    sky_jpg_path = os.path.join(DEST_MAP, "sky.jpg")
    sky_import_path = os.path.join(DEST_MAP, "sky.jpg.import")
    sky_jpg_bytes = None
    sky_import_bytes = None
    if os.path.exists(sky_jpg_path):
        sky_jpg_bytes = open(sky_jpg_path, "rb").read()
        print(f"-> Đã sao lưu trong bộ nhớ: sky.jpg ({len(sky_jpg_bytes)} bytes)")
    if os.path.exists(sky_import_path):
        sky_import_bytes = open(sky_import_path, "rb").read()
        print(f"-> Đã sao lưu trong bộ nhớ: sky.jpg.import ({len(sky_import_bytes)} bytes)")

    # 2. Cập nhật vật cản trong server map hoa_son_kiem
    print("\n[1/5] Cập nhật vật cản chính xác VNG vào server maps hoa_son_kiem...")
    updated_server_regions = 0
    if os.path.exists(SERVER_MAP_DIR):
        for hy in range(20, 29):
            ry = hy + DELTA_RY
            vdir = os.path.join(SERVER_MAP_DIR, f"v_{hy:03d}")
            if not os.path.isdir(vdir):
                continue
            for hx in range(20, 33):
                rx = hx + DELTA_RX
                reg_file = os.path.join(vdir, f"{hx:03d}_Region_C.dat")
                if not os.path.exists(reg_file):
                    continue
                vng_blob = get_vng_obstacle_blob(rx, ry)
                if not vng_blob:
                    continue
                with open(reg_file, "rb") as f:
                    blobs = parse_region(f.read())
                blobs[0] = vng_blob # Thay thế section 0 SEC_OBSTACLE bằng vật cản gốc VNG
                with open(reg_file, "wb") as f:
                    f.write(build_region(blobs))
                updated_server_regions += 1
    print(f"  -> Đã cập nhật vật cản VNG cho {updated_server_regions} regions trong server maps.")

    # 3. Cập nhật vật cản trong source map_525dc16b (chunks 0_0.json.gz, 1_0.json.gz)
    print("\n[2/5] Cập nhật vật cản chính xác VNG vào source export map_525dc16b...")
    src_chunks_dir = os.path.join(SRC_EXPORT, "chunks")
    src_regions = {}
    for cf in sorted(os.listdir(src_chunks_dir)):
        if cf.endswith(".json.gz"):
            cpath = os.path.join(src_chunks_dir, cf)
            with gzip.open(cpath, "rt", encoding="utf-8") as gf:
                cdata = json.load(gf)
            r_dict = cdata.get("r", {})
            for rk, rdata in r_dict.items():
                hx, hy = map(int, rk.split(","))
                rx = hx + DELTA_RX
                ry = hy + DELTA_RY
                vng_obs = get_vng_obstacle_list(rx, ry)
                # Đặt lại ob theo chuẩn VNG
                rdata["ob"] = rle([v & 0xff for v in vng_obs])
                src_regions[rk] = rdata
            with gzip.open(cpath, "wt", encoding="utf-8") as gf:
                json.dump(cdata, gf, ensure_ascii=False)
            print(f"  -> Cập nhật {cf} ({len(r_dict)} regions) với vật cản chuẩn VNG.")

    # 4. Đồng bộ atlas & sprites sang world/maps/map_2
    print("\n[3/5] Đồng bộ atlas & sprites sang game map_2...")
    src_atlas = os.path.join(SRC_EXPORT, "atlas")
    dest_atlas = os.path.join(DEST_MAP, "atlas")
    os.makedirs(dest_atlas, exist_ok=True)
    for fname in os.listdir(src_atlas):
        shutil.copy2(os.path.join(src_atlas, fname), os.path.join(dest_atlas, fname))

    src_sprites = os.path.join(SRC_EXPORT, "sprites")
    dest_sprites = os.path.join(DEST_MAP, "sprites")
    os.makedirs(dest_sprites, exist_ok=True)
    for fname in os.listdir(src_sprites):
        shutil.copy2(os.path.join(src_sprites, fname), os.path.join(dest_sprites, fname))
    print(f"  -> Đã đồng bộ {len(os.listdir(src_sprites))} sprites và atlas.")

    # 5. Dịch chuyển tọa độ (+DELTA_RX, +DELTA_RY) cho game map_2
    print("\n[4/5] Dịch chuyển tọa độ và ghi chunk 4_3.json.gz cho map_2...")
    dest_regions = {}
    for rk, rdata in src_regions.items():
        hx, hy = map(int, rk.split(","))
        rx = hx + DELTA_RX
        ry = hy + DELTA_RY
        dest_rk = f"{rx},{ry}"

        # Deep copy
        dr = json.loads(json.dumps(rdata))

        # Covers
        if "covers" in dr:
            for cov in dr["covers"]:
                cov[1] += DELTA_PX
                cov[2] += DELTA_PY
                cov[5] += DELTA_PY

        # Objects
        if "objects" in dr:
            for obj in dr["objects"]:
                obj["x"] += DELTA_PX
                obj["y"] += DELTA_PY
                obj["sy"] += DELTA_PY

        # NPCs
        if "npcs" in dr:
            for n in dr["npcs"]:
                n["px"] += DELTA_PX
                n["py"] += DELTA_PY
                n["x"] = n["px"]
                n["y"] = n["py"] * 2
                n["ix"] += DELTA_PX
                n["iy"] += DELTA_PY
                n["rx"] = rx
                n["ry"] = ry
                n["uid"] = f"{n.get('t', 0)},{n['x']},{n['y']}"

        # Đảm bảo ob là dữ liệu VNG 100%
        vng_obs = get_vng_obstacle_list(rx, ry)
        dr["ob"] = rle([v & 0xff for v in vng_obs])

        dest_regions[dest_rk] = dr

    dest_chunks_dir = os.path.join(DEST_MAP, "chunks")
    os.makedirs(dest_chunks_dir, exist_ok=True)
    chunk_path = os.path.join(dest_chunks_dir, "4_3.json.gz")
    with gzip.open(chunk_path, "wt", encoding="utf-8") as gf:
        json.dump({"size": len(dest_regions), "r": dest_regions}, gf, ensure_ascii=False)
    print(f"  -> Ghi thành công {chunk_path} gồm {len(dest_regions)} regions.")

    # 6. Đồng bộ minimap, spawns, metadata
    print("\n[5/5] Cập nhật minimap, spawns và metadata...")
    # Minimap
    shutil.copy2(os.path.join(SRC_EXPORT, "minimap.jpg"), os.path.join(DEST_MAP, "minimap.jpg"))
    shutil.copy2(os.path.join(SRC_EXPORT, "minimap_npc.jpg"), os.path.join(DEST_MAP, "minimap_npc.jpg"))

    # Spawns (quái + npc)
    src_spawns_p = os.path.join(SRC_EXPORT, "spawns.json.gz")
    if os.path.exists(src_spawns_p):
        with gzip.open(src_spawns_p, "rt", encoding="utf-8") as gf:
            spawns = json.load(gf)
        for s in spawns:
            s["px"] += DELTA_PX
            s["py"] += DELTA_PY
            s["x"] = s["px"]
            s["y"] = s["py"] * 2
        with gzip.open(os.path.join(DEST_MAP, "spawns.json.gz"), "wt", encoding="utf-8") as gf:
            json.dump(spawns, gf, ensure_ascii=False)
        print(f"  -> Đã cập nhật spawns.json.gz ({len(spawns)} NPCs/Quái).")

    # map.json
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
        "tile_ext": "webp",
        "tile_px": 512,
        "ground_mode": "atlas",
        "traps": [],
        "format": "chunks",
        "chunk": 32,
        "chunks": {
            "4,3": len(dest_regions)
        },
        "minimap": {
            "file": "minimap.jpg",
            "file_npc": "minimap_npc.jpg",
            "px_per_region": 64,
            "min_x": 144,
            "min_y": 110,
            "width": 832,
            "height": 576,
            "npc_count": len(spawns)
        },
        "rect": [144, 110, 156, 118],
        "min_x": 144,
        "max_x": 156,
        "min_y": 110,
        "max_y": 118,
        "atlas": "atlas/atlas.json",
        "spawns": "spawns.json.gz",
        "npc_count": len(spawns),
        "start": [151, 118],
        "arena_center": [77400, 60500]
    }
    with open(os.path.join(DEST_MAP, "map.json"), "w", encoding="utf-8") as f:
        json.dump(dest_map_json, f, indent=2, ensure_ascii=False)
    print("  -> Đã ghi map.json đầy đủ thông tin minimap, rect, npc_count.")

    # Khôi phục sky.jpg và sky.jpg.import
    if sky_jpg_bytes:
        with open(sky_jpg_path, "wb") as f:
            f.write(sky_jpg_bytes)
        print("  -> Đã khôi phục hoàn chỉnh sky.jpg gốc.")
    if sky_import_bytes:
        with open(sky_import_path, "wb") as f:
            f.write(sky_import_bytes)
        print("  -> Đã khôi phục hoàn chỉnh sky.jpg.import gốc.")

    # Rebuild nav_graph.bin
    print("\n-> Xây dựng lại nav_graph.bin...")
    subprocess.run([sys.executable, "tools/build_nav_graph.py", DEST_MAP], check=True)

    # Cập nhật map_catalog.json
    cat_path = r"d:\game\lam-game\kiem-hiep\data\maps\map_catalog.json"
    if os.path.exists(cat_path):
        with open(cat_path, "r", encoding="utf-8") as f:
            cat = json.load(f)
        for m in cat.get("maps", []):
            if int(m.get("id", 0)) == 2:
                m["name"] = "Hoa Sơn"
                m["folder"] = "res://world/maps/map_2"
                m["arena_center"] = [77400, 60500]
                m["monster_summary"] = "62 Heo rừng, 63 Nhím"
                m["npc_count"] = len(spawns)
        with open(cat_path, "w", encoding="utf-8") as f:
            json.dump(cat, f, indent=2, ensure_ascii=False)
        print("  -> Đã cập nhật map_catalog.json thành công.")

    print("\n=================================================================")
    print(">>> HOÀN TẤT ĐỒNG BỘ MAP HOA SƠN CHUẨN XÁC 100% VNG!")
    print("=================================================================")

if __name__ == "__main__":
    main()
