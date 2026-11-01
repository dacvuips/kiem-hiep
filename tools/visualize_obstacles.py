import os
import gzip
import json
import struct
import sys
from PIL import Image, ImageDraw, ImageFont

sys.stdout.reconfigure(encoding="utf-8")

MAP_DIR = r"D:\game\source_vo-lam-truyen-ky\anh-viet\Server + client full-001\server\maps\hoa_son_kiem"
EXPORT_DIR = r"D:\game\tool\editor_map\export\map_525dc16b"

def get_region_ob(rx, ry):
    path = os.path.join(MAP_DIR, f"v_{ry:03d}", f"{rx:03d}_Region_C.dat")
    with open(path, "rb") as f:
        data = f.read()
    n_secs = struct.unpack_from("<I", data, 0)[0]
    secs = [struct.unpack_from("<II", data, 4 + 8 * i) for i in range(n_secs)]
    base = 4 + 8 * n_secs
    blobs = [data[base + o:base + o + l] for o, l in secs]
    ob_blob = blobs[0]
    return list(struct.unpack(f"<{len(ob_blob)//4}I", ob_blob[:2048]))

# Let's inspect regions 27,28 and 27,27 and 27,26
# Load export chunk 0_0.json.gz to get object positions
with gzip.open(os.path.join(EXPORT_DIR, "chunks", "0_0.json.gz"), "rt", encoding="utf-8") as f:
    chunk_r = json.load(f)["r"]

# Create an image covering 2 regions high: 27,26 (top), 27,27 (mid), 27,28 (bottom)
# Width = 512, Height = 512 * 3 = 1536
img = Image.new("RGBA", (512, 1536), (30, 30, 30, 255))
draw = ImageDraw.Draw(img)

# Draw ground / sprites if available in export
# For now, let's paste objects
for reg_idx, ry in enumerate([26, 27, 28]):
    rk = f"27,{ry}"
    r_data = chunk_r.get(rk, {})
    reg_y_offset = reg_idx * 512
    
    # Draw grid
    for cx in range(16):
        draw.line([(cx * 32, reg_y_offset), (cx * 32, reg_y_offset + 512)], fill=(60, 60, 60, 100))
    for cy in range(32):
        draw.line([(0, reg_y_offset + cy * 16), (512, reg_y_offset + cy * 16)], fill=(60, 60, 60, 100))
        
    # Draw objects
    for obj in r_data.get("objects", []):
        spr_path = os.path.join(EXPORT_DIR, obj["img"].replace("/", os.sep))
        if os.path.exists(spr_path):
            spr_img = Image.open(spr_path).convert("RGBA")
            ox = int(obj["x"] - 27 * 512)
            oy = int(obj["y"] - ry * 512) + reg_y_offset
            img.paste(spr_img, (ox, oy), spr_img)

    # Draw obstacles in red
    ob = get_region_ob(27, ry)
    for cx in range(16):
        for cy in range(32):
            val = ob[cx * 32 + cy]
            if (val >> 4) != 0:
                rect = [cx * 32, reg_y_offset + cy * 16, (cx + 1) * 32, reg_y_offset + (cy + 1) * 16]
                draw.rectangle(rect, fill=(255, 0, 0, 100), outline=(255, 50, 50, 180))

# Draw player path from spawn: spawn at 27,28 (cx=2, cy=5 -> x=2*32+16=80, y=512*2+5*16+8=1112)
spawn_pt = (80, 512 * 2 + 5 * 16 + 8)
draw.ellipse([spawn_pt[0]-8, spawn_pt[1]-8, spawn_pt[0]+8, spawn_pt[1]+8], fill=(0, 255, 0, 255), outline=(255, 255, 255, 255))

out_path = r"d:\game\lam-game\kiem-hiep\tools\obstacle_visualization.png"
img.save(out_path)
print(f"Saved visualization to: {out_path}")
