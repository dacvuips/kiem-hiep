import gzip
import json
import os
import sys

sys.stdout.reconfigure(encoding="utf-8")

DEST_MAP = r"d:\game\lam-game\kiem-hiep\world\maps\map_2"

with gzip.open(os.path.join(DEST_MAP, "chunks", "4_3.json.gz"), "rt", encoding="utf-8") as f:
    regs = json.load(f)["r"]

def get_cell(rx, ry, cx, cy):
    rk = f"{rx},{ry}"
    r = regs.get(rk)
    if not r:
        return 0xff
    runs = r.get("ob", [])
    arr = []
    for i in range(0, len(runs), 2):
        arr.extend([runs[i]] * runs[i+1])
    if len(arr) < 512:
        arr.extend([0] * (512 - len(arr)))
    return arr[cx * 32 + cy]

more_regions = [
    (149, 118),
    (150, 118),
    (148, 118),
    (148, 117),
    (148, 115),
    (148, 114),
    (147, 113),
    (148, 113),
    (149, 113),
    (152, 113),
    (152, 114),
]

for rx, ry in more_regions:
    rk = f"{rx},{ry}"
    r = regs.get(rk)
    if not r:
        continue
    runs = r.get("ob", [])
    arr = []
    for i in range(0, len(runs), 2):
        arr.extend([runs[i]] * runs[i+1])
    if len(arr) < 512:
        arr.extend([0] * (512 - len(arr)))
    blocked = sum(1 for v in arr if (v >> 4) != 0)
    print(f"Region {rk}: blocked={blocked}/512")
    if blocked > 0:
        # print non-empty rows
        for cy in range(32):
            row = "".join("#" if (arr[cx * 32 + cy] >> 4) != 0 else "." for cx in range(16))
            if "#" in row:
                print(f"  cy={cy:02d} {row}")
