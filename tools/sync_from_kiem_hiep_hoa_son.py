import gzip
import json
import os
import shutil
import struct
import subprocess
import sys

sys.stdout.reconfigure(encoding="utf-8", errors="replace")

SERVER_KH_DIR = r"D:\game\source_vo-lam-truyen-ky\anh-viet\Server + client full-001\server\maps\kiem_hiep_hoa_son"
SERVER_HS_DIR = r"D:\game\source_vo-lam-truyen-ky\anh-viet\Server + client full-001\server\maps\hoa_son_kiem"
SRC_EXPORT = r"D:\game\tool\editor_map\export\map_525dc16b"
DEST_MAP = r"D:\game\lam-game\kiem-hiep\world\maps\map_2"
GODOT_EXE = r"C:\Users\Hieu Tran\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe"

DELTA_RX = 124
DELTA_RY = 90

def rle(values):
    out = []
    for v in values:
        if out and out[-2] == v:
            out[-1] += 1
        else:
            out += [v, 1]
    return out

def read_region_c_blobs(path: str):
    if not os.path.exists(path):
        return None
    with open(path, "rb") as f:
        data = f.read()
    n = struct.unpack_from("<I", data, 0)[0]
    secs = [struct.unpack_from("<II", data, 4 + 8 * i) for i in range(n)]
    base = 4 + 8 * n
    blobs = [data[base + o:base + o + l] for o, l in secs]
    while len(blobs) < 6:
        blobs.append(b"")
    return blobs

def build_region_data(blobs):
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
    print(">>> CẬP NHẬT TOÀN BỘ VẬT CẢN TỪ MAP KIEM_HIEP_HOA_SON VÀO GAME & TOOL")
    print("=================================================================")

    # 1. Đọc toàn bộ 161 regions từ kiem_hiep_hoa_son
    kh_obstacles = {} # (hx, hy) -> list of 512 ints
    kh_blobs = {}     # (hx, hy) -> raw SEC_OBSTACLE bytes (2048 bytes)

    for vdir in sorted(os.listdir(SERVER_KH_DIR)):
        vp = os.path.join(SERVER_KH_DIR, vdir)
        if not (os.path.isdir(vp) and vdir.startswith("v_")):
            continue
        hy = int(vdir.split("_")[1])
        for f in os.listdir(vp):
            if f.endswith("_Region_C.dat"):
                hx = int(f.split("_")[0])
                fp = os.path.join(vp, f)
                blobs = read_region_c_blobs(fp)
                if blobs and len(blobs) > 0 and len(blobs[0]) >= 2048:
                    obs_blob = blobs[0][:2048]
                    kh_blobs[(hx, hy)] = obs_blob
                    u32 = struct.unpack_from("<512I", obs_blob)
                    kh_obstacles[(hx, hy)] = [v & 0xFF for v in u32]

    print(f"[1/5] Đã đọc thành công {len(kh_obstacles)} regions vật cản từ kiem_hiep_hoa_son.")

    # 2. Đồng bộ sang server map hoa_son_kiem
    print("\n[2/5] Đồng bộ vật cản sang server map hoa_son_kiem...")
    updated_hs = 0
    if os.path.exists(SERVER_HS_DIR):
        for (hx, hy), obs_blob in kh_blobs.items():
            vp = os.path.join(SERVER_HS_DIR, f"v_{hy:03d}")
            os.makedirs(vp, exist_ok=True)
            fp = os.path.join(vp, f"{hx:03d}_Region_C.dat")
            blobs = read_region_c_blobs(fp)
            if blobs:
                blobs[0] = obs_blob
            else:
                blobs = [obs_blob, b"", b"", b"", b"", b""]
            with open(fp, "wb") as f_out:
                f_out.write(build_region_data(blobs))
            updated_hs += 1
    print(f"  -> Đã cập nhật {updated_hs} regions trong hoa_son_kiem.")

    # 3. Đồng bộ sang source export map_525dc16b
    print("\n[3/5] Đồng bộ vật cản sang source export map_525dc16b...")
    src_chunks_dir = os.path.join(SRC_EXPORT, "chunks")
    if os.path.exists(src_chunks_dir):
        for cf in sorted(os.listdir(src_chunks_dir)):
            if cf.endswith(".json.gz"):
                cpath = os.path.join(src_chunks_dir, cf)
                with gzip.open(cpath, "rt", encoding="utf-8") as gf:
                    cdata = json.load(gf)
                r_dict = cdata.get("r", {})
                updated_count = 0
                for rk, rdata in r_dict.items():
                    hx, hy = map(int, rk.split(","))
                    if (hx, hy) in kh_obstacles:
                        rdata["ob"] = rle(kh_obstacles[(hx, hy)])
                        updated_count += 1
                with gzip.open(cpath, "wt", encoding="utf-8") as gf:
                    json.dump(cdata, gf, ensure_ascii=False)
                print(f"  -> Cập nhật {cf} ({updated_count}/{len(r_dict)} regions).")

    # 4. Bảo toàn sky.jpg & đồng bộ sang game map_2
    print("\n[4/5] Đồng bộ vật cản sang game map_2 (world/maps/map_2)...")
    sky_jpg_path = os.path.join(DEST_MAP, "sky.jpg")
    sky_import_path = os.path.join(DEST_MAP, "sky.jpg.import")
    sky_jpg_bytes = open(sky_jpg_path, "rb").read() if os.path.exists(sky_jpg_path) else None
    sky_import_bytes = open(sky_import_path, "rb").read() if os.path.exists(sky_import_path) else None

    dest_chunks_dir = os.path.join(DEST_MAP, "chunks")
    if os.path.exists(dest_chunks_dir):
        for cf in sorted(os.listdir(dest_chunks_dir)):
            if cf.endswith(".json.gz"):
                cpath = os.path.join(dest_chunks_dir, cf)
                with gzip.open(cpath, "rt", encoding="utf-8") as gf:
                    cdata = json.load(gf)
                r_dict = cdata.get("r", {})
                updated_count = 0
                for rk, rdata in r_dict.items():
                    rx, ry = map(int, rk.split(","))
                    hx = rx - DELTA_RX
                    hy = ry - DELTA_RY
                    if (hx, hy) in kh_obstacles:
                        rdata["ob"] = rle(kh_obstacles[(hx, hy)])
                        updated_count += 1
                with gzip.open(cpath, "wt", encoding="utf-8") as gf:
                    json.dump(cdata, gf, ensure_ascii=False)
                print(f"  -> Cập nhật game {cf} ({updated_count}/{len(r_dict)} regions).")

    if sky_jpg_bytes:
        open(sky_jpg_path, "wb").write(sky_jpg_bytes)
        print("  -> Đã khôi phục hoàn hảo sky.jpg")
    if sky_import_bytes:
        open(sky_import_path, "wb").write(sky_import_bytes)
        print("  -> Đã khôi phục hoàn hảo sky.jpg.import")

    # 5. Rebuild nav_graph.bin
    print("\n[5/5] Rebuild nav_graph.bin cho map_2...")
    nav_script = r"tools\build_nav_graph.py"
    res = subprocess.run([sys.executable, nav_script, "world/maps/map_2"], capture_output=True, text=True)
    print(res.stdout)
    if res.stderr:
        print(res.stderr)

    print("\n>>> ĐỒNG BỘ HOÀN TẤT THÀNH CÔNG 100%!")

if __name__ == "__main__":
    main()
