import gzip
import json
import os
import sys

sys.stdout.reconfigure(encoding="utf-8")

DEST_MAP = r"d:\game\lam-game\kiem-hiep\world\maps\map_2"

with gzip.open(os.path.join(DEST_MAP, "chunks", "4_3.json.gz"), "rt", encoding="utf-8") as f:
    regs = json.load(f)["r"]

def inspect_region(rx, ry):
    rk = f"{rx},{ry}"
    r = regs.get(rk)
    if not r:
        print(f"Region {rk}: NOT FOUND")
        return
    runs = r.get("ob", [])
    arr = []
    for i in range(0, len(runs), 2):
        arr.extend([runs[i]] * runs[i+1])
    if len(arr) < 512:
        arr.extend([0] * (512 - len(arr)))
    
    blocked = sum(1 for v in arr if (v >> 4) != 0)
    print(f"\n=== Region {rk} (blocked={blocked}/512) ===")
    print("   " + "".join(f"{x%10}" for x in range(16)))
    for cy in range(32):
        row = "".join("#" if (arr[cx * 32 + cy] >> 4) != 0 else "." for cx in range(16))
        # only print row if it has obstacles or every 4 rows
        print(f"{cy:02d} {row}")

# Check key problem regions
problem_regions = [
    (152, 113), # Bridge middle
    (152, 114), # Bridge east landing
    (153, 114), # East of bridge (huge red block)
    (150, 113), # NW approach to bridge
    (146, 116), # West forest path
    (145, 115), # West forest path
    (154, 113), # NE cliff path
    (155, 116), # SE mountain path
    (155, 117), # SE mountain path
]

for rx, ry in problem_regions:
    inspect_region(rx, ry)
