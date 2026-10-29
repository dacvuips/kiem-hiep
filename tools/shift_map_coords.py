import gzip
import json
import os
import shutil
import subprocess
import sys

MAP_DIR = "world/maps/map_2"
DELTA_RX = 124
DELTA_RY = 90
DELTA_PX = DELTA_RX * 512 # 63488
DELTA_PY = DELTA_RY * 512 # 46080

def shift_map():
    print(f"Shift map by delta_rx={DELTA_RX}, delta_ry={DELTA_RY}, delta_px={DELTA_PX}, delta_py={DELTA_PY}")
    
    # 1. Read map.json
    map_json_path = os.path.join(MAP_DIR, "map.json")
    with open(map_json_path, "r", encoding="utf-8") as f:
        map_data = json.load(f)

    # 2. Read all chunks
    chunks_dir = os.path.join(MAP_DIR, "chunks")
    all_regions = {}
    old_chunk_files = [f for f in os.listdir(chunks_dir) if f.endswith(".json.gz")]
    for cf in old_chunk_files:
        cpath = os.path.join(chunks_dir, cf)
        with gzip.open(cpath, "rt", encoding="utf-8") as gf:
            cdata = json.load(gf)
            all_regions.update(cdata.get("r", {}))

    print(f"Read {len(all_regions)} regions from {old_chunk_files}")

    # 3. Shift regions
    shifted_regions = {}
    for rk, rdata in all_regions.items():
        rx, ry = map(int, rk.split(","))
        new_rx = rx + DELTA_RX
        new_ry = ry + DELTA_RY
        new_rk = f"{new_rx},{new_ry}"

        # Shift covers
        if "covers" in rdata:
            for cov in rdata["covers"]:
                # [img, x, y, layer, anim, sort_y]
                cov[1] += DELTA_PX
                cov[2] += DELTA_PY
                cov[5] += DELTA_PY

        # Shift objects
        if "objects" in rdata:
            for obj in rdata["objects"]:
                obj["x"] += DELTA_PX
                obj["y"] += DELTA_PY
                obj["sy"] += DELTA_PY

        # Shift npcs
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

    # Group into new chunks
    by_chunk = {}
    for rk, rdata in shifted_regions.items():
        rx, ry = map(int, rk.split(","))
        cx = rx // 32
        cy = ry // 32
        chunk_key = f"{cx}_{cy}"
        if chunk_key not in by_chunk:
            by_chunk[chunk_key] = {}
        by_chunk[chunk_key][rk] = rdata

    # Remove old chunk files
    for cf in old_chunk_files:
        os.remove(os.path.join(chunks_dir, cf))

    # Write new chunk files
    chunk_counts = {}
    for ckey, r_dict in by_chunk.items():
        chunk_counts[ckey.replace("_", ",")] = len(r_dict)
        cpath = os.path.join(chunks_dir, f"{ckey}.json.gz")
        cdata = {"size": len(r_dict), "r": r_dict}
        with gzip.open(cpath, "wt", encoding="utf-8") as gf:
            json.dump(cdata, gf, ensure_ascii=False)
        print(f"Wrote chunk {ckey}.json.gz with {len(r_dict)} regions")

    # 4. Shift spawns.json.gz
    spawns_path = os.path.join(MAP_DIR, "spawns.json.gz")
    if os.path.exists(spawns_path):
        with gzip.open(spawns_path, "rt", encoding="utf-8") as gf:
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

        with gzip.open(spawns_path, "wt", encoding="utf-8") as gf:
            json.dump(spawns, gf, ensure_ascii=False)
        print(f"Updated {len(spawns)} spawns in {spawns_path}")

    # 5. Update map.json
    all_rx = [int(k.split(",")[0]) for k in shifted_regions]
    all_ry = [int(k.split(",")[1]) for k in shifted_regions]
    min_x, max_x = min(all_rx), max(all_rx)
    min_y, max_y = min(all_ry), max(all_ry)

    map_data["rect"] = [min_x, min_y, max_x, max_y]
    map_data["min_x"] = min_x
    map_data["max_x"] = max_x
    map_data["min_y"] = min_y
    map_data["max_y"] = max_y
    map_data["chunks"] = chunk_counts
    map_data["start"] = [map_data["start"][0] + DELTA_RX, map_data["start"][1] + DELTA_RY]
    map_data["arena_center"] = [77824, 59392]

    if "minimap" in map_data:
        map_data["minimap"]["min_x"] = min_x
        map_data["minimap"]["min_y"] = min_y
        map_data["minimap"]["width"] = (max_x - min_x + 1) * 64
        map_data["minimap"]["height"] = (max_y - min_y + 1) * 64

    with open(map_json_path, "w", encoding="utf-8") as f:
        json.dump(map_data, f, ensure_ascii=False, indent=2)
    print(f"Updated map.json: rect={map_data['rect']}, start={map_data['start']}, arena_center={map_data['arena_center']}")

    # 6. Rebuild nav_graph.bin
    print("Building nav_graph.bin ...")
    subprocess.run([sys.executable, "tools/build_nav_graph.py", MAP_DIR], check=True)
    print("nav_graph.bin built successfully.")

    # 7. Update data/maps/map_catalog.json
    cat_path = "data/maps/map_catalog.json"
    with open(cat_path, "r", encoding="utf-8") as f:
        catalog = json.load(f)
    for m in catalog["maps"]:
        if m["id"] == 2:
            m["arena_center"] = [77824, 59392]
            m["start"] = map_data["start"]
            break
    with open(cat_path, "w", encoding="utf-8") as f:
        json.dump(catalog, f, ensure_ascii=False, indent=2)
    print("Updated data/maps/map_catalog.json.")

if __name__ == "__main__":
    shift_map()
