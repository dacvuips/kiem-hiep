import os
import gzip
import json
import struct
import sys
from PIL import Image, ImageDraw

sys.stdout.reconfigure(encoding="utf-8")

DEST_MAP = r"d:\game\lam-game\kiem-hiep\world\maps\map_2"

with gzip.open(os.path.join(DEST_MAP, "chunks", "4_3.json.gz"), "rt", encoding="utf-8") as f:
    chunk_data = json.load(f)["r"]

r117 = chunk_data.get("151,117", {})
with open(os.path.join(DEST_MAP, "atlas", "atlas.json"), "r", encoding="utf-8") as f:
    atlas_meta = json.load(f)

# Load atlas pages
pages = [Image.open(os.path.join(DEST_MAP, "atlas", p)).convert("RGBA") for p in atlas_meta["pages"]]
items = atlas_meta["items"]

# Calculate padding like in VltkMap.gd
pad = [0, 0, 0, 0]
for it in items:
    pad[0] = max(pad[0], -int(it[5]))
    pad[1] = max(pad[1], -int(it[6]))
    pad[2] = max(pad[2], int(it[5]) + int(it[3]) - 64)
    pad[3] = max(pad[3], int(it[6]) + int(it[4]) - 64)
bake_pad = [min(max(0, p), 128) for p in pad]

canvas_w = 512 + bake_pad[0] + bake_pad[2]
canvas_h = 512 + bake_pad[1] + bake_pad[3]
ground_canvas = Image.new("RGBA", (canvas_w, canvas_h), (0, 0, 0, 0))

cells = r117.get("g", [])
i = 0
while i + 2 < len(cells):
    cx = int(cells[i])
    cy = int(cells[i+1])
    item_id = int(cells[i+2])
    it = items[item_id]
    src_page = pages[int(it[0])]
    src_rect = (int(it[1]), int(it[2]), int(it[1]) + int(it[3]), int(it[2]) + int(it[4]))
    tile_crop = src_page.crop(src_rect)
    dest_pos = (cx * 32 + int(it[5]) + bake_pad[0], cy * 32 + int(it[6]) + bake_pad[1])
    ground_canvas.paste(tile_crop, dest_pos, tile_crop)
    i += 3

# Crop to the 512x512 region
region_img = ground_canvas.crop((bake_pad[0], bake_pad[1], bake_pad[0] + 512, bake_pad[1] + 512))

# Now paste objects
rx = 151
ry = 117
for obj in r117.get("objects", []):
    spr_path = os.path.join(DEST_MAP, obj["img"].replace("/", os.sep))
    if os.path.exists(spr_path):
        spr = Image.open(spr_path).convert("RGBA")
        ox = int(obj["x"] - rx * 512)
        oy = int(obj["y"] - ry * 512)
        region_img.paste(spr, (ox, oy), spr)

# Now overlay obstacles from raw server map
MAP_DIR = r"D:\game\source_vo-lam-truyen-ky\anh-viet\Server + client full-001\server\maps\hoa_son_kiem"
path = os.path.join(MAP_DIR, "v_027", "027_Region_C.dat")
with open(path, "rb") as f:
    data = f.read()
n_secs = struct.unpack_from("<I", data, 0)[0]
secs = [struct.unpack_from("<II", data, 4 + 8 * i) for i in range(n_secs)]
base = 4 + 8 * n_secs
blobs = [data[base + o:base + o + l] for o, l in secs]
ob = list(struct.unpack(f"<{len(blobs[0])//4}I", blobs[0][:2048]))

overlay = Image.new("RGBA", (512, 512), (0, 0, 0, 0))
draw = ImageDraw.Draw(overlay)
for cx in range(16):
    for cy in range(32):
        val = ob[cx * 32 + cy]
        if (val >> 4) != 0:
            draw.rectangle([cx * 32, cy * 16, (cx + 1) * 32, (cy + 1) * 16], fill=(255, 0, 0, 130), outline=(255, 50, 50, 200))

combined = Image.alpha_composite(region_img, overlay)
out_file = r"d:\game\lam-game\kiem-hiep\tools\actual_graphics_with_obs.png"
combined.save(out_file)
print("Saved:", out_file)
