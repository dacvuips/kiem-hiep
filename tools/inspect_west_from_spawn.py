import gzip
import json
import os
import sys

sys.stdout.reconfigure(encoding="utf-8")

DEST_MAP = r"d:\game\lam-game\kiem-hiep\world\maps\map_2"

with gzip.open(os.path.join(DEST_MAP, "chunks", "4_3.json.gz"), "rt", encoding="utf-8") as f:
    regs = json.load(f)["r"]

def is_cell_free(gx, gy):
    rx = 144 + gx // 16
    ry = 110 + gy // 32
    cx = gx % 16
    cy = gy % 32
    rk = f"{rx},{ry}"
    r = regs.get(rk)
    if not r:
        return False
    runs = r.get("ob", [])
    arr = []
    for i in range(0, len(runs), 2):
        arr.extend([runs[i]] * runs[i+1])
    if len(arr) < 512:
        arr.extend([0] * (512 - len(arr)))
    val = arr[cx * 32 + cy]
    return (val >> 4) == 0

# Spawn is at (77400, 60500)
# gx = 77400 // 32 - 144 * 16 = 2418 - 2304 = 114 (Region 151, cx = 2)
# gy = 60500 // 16 - 110 * 32 = 3781 - 3520 = 261 (Region 118, cy = 5)

print(f"Spawn cell: gx=114, gy=261 -> free={is_cell_free(114, 261)}")

# Check along line going West from spawn: gx from 114 down to 96 (Region 150)
print("\nGoing West along gy=261 (cy=5 in ry=118):")
for gx in range(114, 95, -1):
    rx = 144 + gx // 16
    cx = gx % 16
    free = is_cell_free(gx, 261)
    status = "." if free else "#"
    print(f"gx={gx} (Region {rx}, cx={cx}): {status}")
