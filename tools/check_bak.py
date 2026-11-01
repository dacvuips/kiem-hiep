import gzip
import json
import os
import sys

sys.stdout.reconfigure(encoding="utf-8")

DEST_MAP = r"d:\game\lam-game\kiem-hiep\world\maps\map_2"
bak_path = os.path.join(DEST_MAP, "chunks", "4_3.json.gz.bak")

if os.path.exists(bak_path):
    with gzip.open(bak_path, "rt", encoding="utf-8") as f:
        bak_data = json.load(f)["r"]
    print(f"Loaded bak regions: {len(bak_data)}")
    
    # Check regions: 146,116, 153,114, 150,113, etc.
    for rk in ["146,116", "145,115", "153,114", "150,113", "151,113", "151,117"]:
        r_bak = bak_data.get(rk)
        if r_bak:
            runs = r_bak.get("ob", [])
            arr = []
            for i in range(0, len(runs), 2):
                arr.extend([runs[i]] * runs[i+1])
            b = sum(1 for v in arr if (v >> 4) != 0)
            print(f"Region {rk} in BAK: blocked={b}/512")
else:
    print("No .bak found")
