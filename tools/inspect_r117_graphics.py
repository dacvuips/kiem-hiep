import os
import gzip
import json
import struct
import sys
from PIL import Image, ImageDraw

sys.stdout.reconfigure(encoding="utf-8")

DEST_MAP = r"d:\game\lam-game\kiem-hiep\world\maps\map_2"
MAP_DIR = r"D:\game\source_vo-lam-truyen-ky\anh-viet\Server + client full-001\server\maps\hoa_son_kiem"

# Load chunk 4_3.json.gz
with gzip.open(os.path.join(DEST_MAP, "chunks", "4_3.json.gz"), "rt", encoding="utf-8") as f:
    chunk_data = json.load(f)["r"]

r117 = chunk_data.get("151,117", {})

# Load atlas.json to composite ground
with open(os.path.join(DEST_MAP, "atlas", "atlas.json"), "r", encoding="utf-8") as f:
    atlas_meta = json.load(f)

# Load atlas textures
atlas_imgs = []
for p in atlas_meta.get("pages", []):
    ap = os.path.join(DEST_MAP, "atlas", p)
    if os.path.exists(ap):
        atlas_imgs.append(Image.open(ap).convert("RGBA"))
    else:
        atlas_imgs.append(None)

# 1 region is 512x512
canvas = Image.new("RGBA", (512, 512), (50, 80, 50, 255))

# Draw ground cells
# Each cell is 32x16 or 64x32?
# In VLTK atlas ground:
# "g": [atlas_idx, frame, x, y] or similar?
# Let's inspect format of "g" in r117:
print("Keys in r117:", list(r117.keys()))
if "g" in r117:
    print("g sample:", r117["g"][:5])
if "objects" in r117:
    print("objects count:", len(r117["objects"]))
    for obj in r117["objects"]:
        print("  obj:", obj)
