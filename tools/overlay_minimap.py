import os
import struct
import sys
from PIL import Image, ImageDraw

sys.stdout.reconfigure(encoding="utf-8")

MAP_DIR = r"D:\game\source_vo-lam-truyen-ky\anh-viet\Server + client full-001\server\maps\hoa_son_kiem"
MINIMAP_PATH = r"d:\game\lam-game\kiem-hiep\world\maps\map_2\minimap.jpg"

minimap = Image.open(MINIMAP_PATH).convert("RGBA")

# Map 2 bounds: min_rx = 144, min_ry = 110. Each region is 64x64 px on minimap.
# Let's inspect column rx = 151 (which corresponds to raw server rx = 27)
# Across ry = 113 to 118 (raw server ry = 23 to 28)
# We will create an image: 1 region wide (512 px) and 6 regions high (6 * 512 = 3072 px)

canvas = Image.new("RGBA", (512, 6 * 512), (0, 0, 0, 255))

for idx, ry_game in enumerate(range(113, 119)): # 113, 114, 115, 116, 117, 118
    ry_server = ry_game - 90 # 23 to 28
    
    # Minimap crop
    mx = (151 - 144) * 64
    my = (ry_game - 110) * 64
    crop = minimap.crop((mx, my, mx + 64, my + 64))
    crop_scaled = crop.resize((512, 512), Image.Resampling.BILINEAR)
    
    y_off = idx * 512
    canvas.paste(crop_scaled, (0, y_off))
    
    # Read server Region_C.dat obstacle
    path = os.path.join(MAP_DIR, f"v_{ry_server:03d}", f"027_Region_C.dat")
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
                draw.rectangle([cx * 32, cy * 16, (cx + 1) * 32, (cy + 1) * 16], fill=(255, 0, 0, 110), outline=(255, 80, 80, 160))
            else:
                # Green dot for walkable
                draw.point([cx * 32 + 16, cy * 16 + 8], fill=(0, 255, 0, 100))
                
    # Region label
    draw.text((10, 10), f"Region {151},{ry_game} (server 27,{ry_server})", fill=(255, 255, 0, 255))
    canvas.alpha_composite(overlay, (0, y_off))

out_path = r"d:\game\lam-game\kiem-hiep\tools\minimap_obstacle_overlay.png"
canvas.save(out_path)
print("Saved:", out_path)
