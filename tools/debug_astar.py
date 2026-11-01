import gzip
import json
import os
import sys

sys.stdout.reconfigure(encoding="utf-8")

DEST_MAP = r"d:\game\lam-game\kiem-hiep\world\maps\map_2"

with gzip.open(os.path.join(DEST_MAP, "chunks", "4_3.json.gz"), "rt", encoding="utf-8") as f:
    regs = json.load(f)["r"]

COLS = 13 * 16 # 208
ROWS = 9 * 32  # 288

grid = [[False for _ in range(ROWS)] for _ in range(COLS)]
for rk, r in regs.items():
    rx, ry = map(int, rk.split(","))
    if not (144 <= rx <= 156 and 110 <= ry <= 118):
        continue
    base_x = (rx - 144) * 16
    base_y = (ry - 110) * 32
    runs = r.get("ob", [])
    arr = []
    for i in range(0, len(runs), 2):
        arr.extend([runs[i]] * runs[i+1])
    if len(arr) < 512:
        arr.extend([0] * (512 - len(arr)))
    for cx in range(16):
        for cy in range(32):
            if (arr[cx * 32 + cy] >> 4) == 0:
                grid[base_x + cx][base_y + cy] = True

# In test_all_routes.py:
# cell_of_world was:
# int(wx / 32) - 144 * 16
# int(wy / 16) - 110 * 32
c1 = (int(77400 / 32) - 144 * 16, int(60500 / 16) - 110 * 32)
c2 = (int(76900 / 32) - 144 * 16, int(60500 / 16) - 110 * 32)
print("c1:", c1, "grid[c1]:", grid[c1[0]][c1[1]])
print("c2:", c2, "grid[c2]:", grid[c2[0]][c2[1]])
