import os
import struct
import sys
from PIL import Image, ImageDraw, ImageFont

sys.stdout.reconfigure(encoding="utf-8")

MAP_DIR = r"D:\game\source_vo-lam-truyen-ky\anh-viet\Server + client full-001\server\maps\hoa_son_kiem"
MINIMAP_PATH = r"d:\game\lam-game\kiem-hiep\world\maps\map_2\minimap.jpg"

minimap = Image.open(MINIMAP_PATH).convert("RGBA")

# Zoom in on region 151,113 (server 27,23)
mx = (151 - 144) * 64
my = (113 - 110) * 64
crop = minimap.crop((mx, my, mx + 64, my + 64)).resize((1024, 1024), Image.Resampling.NEAREST)

path = os.path.join(MAP_DIR, "v_023", "027_Region_C.dat")
with open(path, "rb") as f:
    data = f.read()
n_secs = struct.unpack_from("<I", data, 0)[0]
secs = [struct.unpack_from("<II", data, 4 + 8 * i) for i in range(n_secs)]
base = 4 + 8 * n_secs
blobs = [data[base + o:base + o + l] for o, l in secs]
ob = list(struct.unpack(f"<{len(blobs[0])//4}I", blobs[0][:2048]))

overlay = Image.new("RGBA", (1024, 1024), (0, 0, 0, 0))
draw = ImageDraw.Draw(overlay)

# Each cell is 64 px wide x 32 px high at 1024x1024
for cx in range(16):
    for cy in range(32):
        val = ob[cx * 32 + cy]
        x0, y0 = cx * 64, cy * 32
        x1, y1 = (cx + 1) * 64, (cy + 1) * 32
        
        draw.rectangle([x0, y0, x1, y1], outline=(100, 100, 100, 80))
        if (val >> 4) != 0:
            draw.rectangle([x0, y0, x1, y1], fill=(255, 0, 0, 140), outline=(255, 0, 0, 200))
        else:
            draw.rectangle([x0, y0, x1, y1], fill=(0, 255, 0, 50))
            
crop.alpha_composite(overlay)
crop.save(r"d:\game\lam-game\kiem-hiep\tools\bridge_zoom.png")
print("Saved bridge_zoom.png")
