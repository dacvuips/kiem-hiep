import gzip
import json
import shutil
import os
from PIL import Image, ImageDraw

chunk_path = 'world/maps/map_2/chunks/4_3.json.gz'
bak_path = 'world/maps/map_2/chunks/4_3.json.gz.bak'

if not os.path.exists(bak_path):
    shutil.copyfile(chunk_path, bak_path)
    print(f'Created backup at {bak_path}')
else:
    print(f'Backup already exists at {bak_path}')

def decode_ob(runs):
    arr = bytearray()
    for i in range(0, len(runs), 2):
        val = runs[i] & 0xff
        cnt = runs[i+1]
        arr.extend([val] * cnt)
    return arr

def encode_ob(byte_arr):
    runs = []
    if not byte_arr:
        return runs
    curr_val = byte_arr[0]
    count = 1
    for b in byte_arr[1:]:
        if b == curr_val:
            count += 1
        else:
            runs.extend([curr_val, count])
            curr_val = b
            count = 1
    runs.extend([curr_val, count])
    return runs

with gzip.open(chunk_path, 'rt', encoding='utf-8') as f:
    chunk_data = json.load(f)

# Region 151,113 modifications
reg_113 = chunk_data['r']['151,113']
ob_113 = decode_ob(reg_113['ob'])

# Fix the bridge blocking cells:
# cx=0: cy=28
# cx=1: cy=27, 28, 29
# cx=2: cy=28, 29, 30
# cx=3: cy=29, 31 (cy=30 is already 0x00)
# cx=4: cy=30, 31 are already 0x00
cells_to_clear_113 = [
    (0, 28),
    (1, 27), (1, 28), (1, 29),
    (2, 28), (2, 29), (2, 30),
    (3, 29), (3, 31)
]

for cx, cy in cells_to_clear_113:
    idx = cx * 32 + cy
    old_val = ob_113[idx]
    ob_113[idx] = 0x00
    print(f'Region 151,113 cx={cx} cy={cy}: cleared from 0x{old_val:02x} to 0x00')

reg_113['ob'] = encode_ob(ob_113)

# Region 151,114 modifications (smoother transition at bridge exit)
reg_114 = chunk_data['r']['151,114']
ob_114 = decode_ob(reg_114['ob'])
cells_to_clear_114 = [
    (4, 0)
]
for cx, cy in cells_to_clear_114:
    idx = cx * 32 + cy
    old_val = ob_114[idx]
    ob_114[idx] = 0x00
    print(f'Region 151,114 cx={cx} cy={cy}: cleared from 0x{old_val:02x} to 0x00')

reg_114['ob'] = encode_ob(ob_114)

# Save back to chunk file
with gzip.open(chunk_path, 'wt', encoding='utf-8') as f:
    json.dump(chunk_data, f, separators=(',', ':'))

print('Successfully updated 4_3.json.gz!')

# Render updated bridge_with_obstacles_fixed.png
im = Image.open('tools/bridge_render.png').convert('RGBA')
overlay = Image.new('RGBA', im.size, (0, 0, 0, 0))
draw = ImageDraw.Draw(overlay)

min_x, max_x = 76600, 77800
min_y, max_y = 57800, 58600

regs = chunk_data['r']
for rx in range(149, 152):
    for ry in range(112, 115):
        rk = f'{rx},{ry}'
        if rk not in regs: continue
        ob = decode_ob(regs[rk].get('ob', []))
        if len(ob) != 512: continue
        for cx in range(16):
            for cy in range(32):
                val = ob[cx * 32 + cy]
                solid = (val >> 4) != 0
                wx = rx * 512 + cx * 32
                wy = ry * 512 + cy * 16
                px = wx - min_x
                py = wy - min_y
                if 0 <= px < im.width and 0 <= py < im.height:
                    if solid:
                        draw.rectangle([px, py, px+31, py+15], fill=(255, 0, 0, 90), outline=(255, 0, 0, 180))
                    else:
                        draw.rectangle([px, py, px+31, py+15], fill=(0, 255, 0, 50), outline=(0, 255, 0, 120))

out = Image.alpha_composite(im, overlay)
out.save('tools/bridge_with_obstacles_fixed.png')
print('Saved tools/bridge_with_obstacles_fixed.png')
