import os
import gzip
import json
import struct
import sys
from PIL import Image, ImageDraw

sys.stdout.reconfigure(encoding="utf-8")

DEST_MAP = r"d:\game\lam-game\kiem-hiep\world\maps\map_2"
minimap_path = os.path.join(DEST_MAP, "minimap.jpg")
minimap = Image.open(minimap_path).convert("RGBA")

# minimap is 832 x 576.
# min_x = 144, min_y = 110.
# 13 regions wide (144..156), 9 regions high (110..118).
# Scale up 4x: 3328 x 2304. Each region is 256 x 256 px.
SCALE = 4
W = minimap.width * SCALE # 3328
H = minimap.height * SCALE # 2304
canvas = minimap.resize((W, H), Image.Resampling.BILINEAR)

with gzip.open(os.path.join(DEST_MAP, "chunks", "4_3.json.gz"), "rt", encoding="utf-8") as f:
    regs = json.load(f)["r"]

overlay = Image.new("RGBA", (W, H), (0, 0, 0, 0))
draw = ImageDraw.Draw(overlay)

# Cell dimensions at this scale:
# Region is 256 x 256. 16 cols x 32 rows -> cell is 16 x 8 px!
CW = 256 // 16 # 16 px
CH = 256 // 32 # 8 px

for rk, r in regs.items():
    rx, ry = map(int, rk.split(","))
    reg_x = (rx - 144) * 256
    reg_y = (ry - 110) * 256
    
    # Region boundary
    draw.rectangle([reg_x, reg_y, reg_x + 256, reg_y + 256], outline=(80, 80, 80, 100))
    
    ob_runs = r.get("ob", [])
    arr = []
    for i in range(0, len(ob_runs), 2):
        arr.extend([ob_runs[i]] * ob_runs[i+1])
    if len(arr) < 512:
        arr.extend([0] * (512 - len(arr)))
        
    for cx in range(16):
        for cy in range(32):
            val = arr[cx * 32 + cy]
            if (val >> 4) != 0:
                x0 = reg_x + cx * CW
                y0 = reg_y + cy * CH
                draw.rectangle([x0, y0, x0 + CW, y0 + CH], fill=(255, 0, 0, 120))

# Also draw NPCs (cyan dots) and Start (green circle)
with open(os.path.join(DEST_MAP, "map.json"), "r", encoding="utf-8") as f:
    m_meta = json.load(f)

# Spawn point
arena_center = m_meta.get("arena_center", [77400, 60500])
# convert arena_center (map pixels) to minimap pixels * SCALE:
# map pixel x in [144*512 .. 157*512] -> relative to 144*512:
sc_x = (arena_center[0] - 144 * 512) / 512.0 * 256
sc_y = (arena_center[1] - 110 * 512) / 512.0 * 256
draw.ellipse([sc_x - 10, sc_y - 10, sc_x + 10, sc_y + 10], fill=(0, 255, 0, 255), outline=(255, 255, 255, 255), width=2)
draw.text((sc_x + 12, sc_y - 6), "SPAWN", fill=(0, 255, 0, 255))

result = Image.alpha_composite(canvas, overlay)
out_file = r"d:\game\lam-game\kiem-hiep\tools\full_map_obstacle_overlay.png"
result.save(out_file)
print("Saved full map obstacle overlay to:", out_file)
