import os
import gzip
import json
import struct
import sys
from PIL import Image, ImageDraw

sys.stdout.reconfigure(encoding="utf-8")

DEST_MAP = r"d:\game\lam-game\kiem-hiep\world\maps\map_2"

# Let's inspect the atlas tiles for region 151,117
with gzip.open(os.path.join(DEST_MAP, "chunks", "4_3.json.gz"), "rt", encoding="utf-8") as f:
    chunk_data = json.load(f)["r"]

r117 = chunk_data.get("151,117", {})
with open(os.path.join(DEST_MAP, "atlas", "atlas.json"), "r", encoding="utf-8") as f:
    atlas_meta = json.load(f)

# Load atlas pages
pages = [Image.open(os.path.join(DEST_MAP, "atlas", p)).convert("RGBA") for p in atlas_meta["pages"]]

# Create region canvas 512x512
region_img = Image.new("RGBA", (512, 512), (0, 0, 0, 0))

# Decode ground: "g": [run_length, tile_id, ...] or list of cells?
# In VLTK export exporter.py:
# let's check how "g" is structured in exporter.py
print("r117 g length:", len(r117.get("g", [])))
print("r117 g first 20:", r117.get("g", [])[:20])
