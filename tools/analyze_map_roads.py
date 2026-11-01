import os
import gzip
import json
import struct
import sys
from PIL import Image

sys.stdout.reconfigure(encoding="utf-8")

DEST_MAP = r"d:\game\lam-game\kiem-hiep\world\maps\map_2"
minimap_path = os.path.join(DEST_MAP, "minimap.jpg")
im = Image.open(minimap_path)
print(f"Minimap size: {im.size}, mode: {im.mode}")

with open(os.path.join(DEST_MAP, "map.json"), "r", encoding="utf-8") as f:
    meta = json.load(f)
print(f"Map rect: {meta.get('rect')}")
print(f"Minimap meta: {meta.get('minimap')}")

with gzip.open(os.path.join(DEST_MAP, "chunks", "4_3.json.gz"), "rt", encoding="utf-8") as f:
    cdata = json.load(f)

regs = cdata["r"]
print(f"Total regions in map_2: {len(regs)}")

# Let's count how many regions have obstacles
all_blocked = 0
all_free = 0
mixed = 0
for rk, r in regs.items():
    runs = r.get("ob", [])
    arr = []
    for i in range(0, len(runs), 2):
        arr.extend([runs[i]] * runs[i+1])
    b = sum(1 for v in arr if (v >> 4) != 0)
    if b == 512:
        all_blocked += 1
    elif b == 0:
        all_free += 1
    else:
        mixed += 1

print(f"Regions: {len(regs)} total -> all_blocked={all_blocked}, all_free={all_free}, mixed={mixed}")
