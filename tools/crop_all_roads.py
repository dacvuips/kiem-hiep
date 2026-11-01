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

# minimap is 832 x 576. 13 regions wide (144..156), 9 regions high (110..118).
# Each region is 64x64 on minimap.
# Let's scale by 8x (each region 512x512) for crops!
SCALE = 8
W = minimap.width * SCALE # 6656
H = minimap.height * SCALE # 4608

with gzip.open(os.path.join(DEST_MAP, "chunks", "4_3.json.gz"), "rt", encoding="utf-8") as f:
    regs = json.load(f)["r"]

# We will generate focused crop images for each road section:
sections = {
    "sec1_south_fork": (147, 117, 152, 118),      # Spawn and road going West
    "sec2_north_to_bridge": (150, 113, 152, 118), # Spawn straight to bridge
    "sec3_bridge_and_east": (150, 112, 154, 115), # Bridge crossing & eastern landing
    "sec4_northeast_cliff": (152, 112, 156, 114), # Northeast cliff path
    "sec5_southeast_waterfall": (153, 114, 156, 118), # Southeast waterfall & path
    "sec6_northwest_meadow": (146, 111, 151, 115), # Northwest meadow & central path
    "sec7_far_west_path": (144, 113, 147, 118),    # Far west path
}

os.makedirs(r"d:\game\lam-game\kiem-hiep\tools\road_crops", exist_ok=True)

for sec_name, (rx0, ry0, rx1, ry1) in sections.items():
    # Region pixel size: 512x512
    crop_w = (rx1 - rx0 + 1) * 512
    crop_h = (ry1 - ry0 + 1) * 512
    
    # Minimap bounds:
    mx0 = (rx0 - 144) * 64
    my0 = (ry0 - 110) * 64
    mx1 = (rx1 - 144 + 1) * 64
    my1 = (ry1 - 110 + 1) * 64
    
    crop_bg = minimap.crop((mx0, my0, mx1, my1)).resize((crop_w, crop_h), Image.Resampling.BILINEAR)
    overlay = Image.new("RGBA", (crop_w, crop_h), (0, 0, 0, 0))
    draw = ImageDraw.Draw(overlay)
    
    # Draw obstacles
    for rx in range(rx0, rx1 + 1):
        for ry in range(ry0, ry1 + 1):
            rk = f"{rx},{ry}"
            r = regs.get(rk)
            if not r:
                continue
            reg_px = (rx - rx0) * 512
            reg_py = (ry - ry0) * 512
            
            # Region box & label
            draw.rectangle([reg_px, reg_py, reg_px + 512, reg_py + 512], outline=(100, 100, 100, 120))
            draw.text((reg_px + 10, reg_py + 10), f"Region {rx},{ry}", fill=(255, 255, 0, 200))
            
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
                        x = reg_px + cx * 32
                        y = reg_py + cy * 16
                        draw.rectangle([x, y, x + 32, y + 16], fill=(255, 0, 0, 120), outline=(255, 60, 60, 180))

    final_crop = Image.alpha_composite(crop_bg, overlay)
    out_p = os.path.join(r"d:\game\lam-game\kiem-hiep\tools\road_crops", f"{sec_name}.png")
    final_crop.save(out_p)
    print(f"Saved {sec_name} -> {out_p}")
