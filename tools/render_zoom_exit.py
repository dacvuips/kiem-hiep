import gzip, json, os
from PIL import Image, ImageDraw

with gzip.open('world/maps/map_2/chunks/4_3.json.gz', 'rt', encoding='utf-8') as f:
    chunk_data = json.load(f)

regs = chunk_data['r']
def decode_ob(runs):
    arr = bytearray()
    for i in range(0, len(runs), 2):
        arr.extend([runs[i] & 0xff] * runs[i+1])
    return arr

ob113 = decode_ob(regs['151,113']['ob'])
ob114 = decode_ob(regs['151,114']['ob'])

# World X: 77200 to 77800
# World Y: 58150 to 58550
min_x, max_x = 77200, 77800
min_y, max_y = 58150, 58550
W, H = max_x - min_x, max_y - min_y

canvas = Image.new('RGBA', (W, H), (100, 150, 240, 255))

# Sky
sky_p = 'world/maps/map_2/sky.jpg'
if os.path.exists(sky_p):
    sky = Image.open(sky_p).convert('RGBA')
    for sx in range(0, W, sky.width):
        for sy in range(0, H, sky.height):
            canvas.paste(sky, (sx, sy))

# Covers
covers = []
for rk in ['150,113', '151,113', '152,113', '150,114', '151,114', '152,114']:
    if rk not in regs: continue
    for c in regs[rk].get('covers', []):
        covers.append(c)

covers.sort(key=lambda c: int(c[3]) * 1000000000000 + (int(c[4]) + 1000) * 1000000000 + int(c[5]))
for c in covers:
    sp_path = os.path.join('world/maps/map_2', c[0])
    if os.path.exists(sp_path):
        sp = Image.open(sp_path).convert('RGBA')
        cx, cy = c[1] - min_x, c[2] - min_y
        canvas.alpha_composite(sp, (int(cx), int(cy)))

# Objects
objs = []
for rk in ['150,113', '151,113', '152,113', '150,114', '151,114', '152,114']:
    if rk not in regs: continue
    for o in regs[rk].get('objects', []):
        objs.append(o)

objs.sort(key=lambda o: o.get('sy', o.get('y', 0)))
for o in objs:
    sp_path = os.path.join('world/maps/map_2', o['img'])
    if os.path.exists(sp_path):
        sp = Image.open(sp_path).convert('RGBA')
        ox, oy = o['x'] - min_x, o['y'] - min_y
        canvas.alpha_composite(sp, (int(ox), int(oy)))

# Overlay grid
overlay = Image.new('RGBA', canvas.size, (0, 0, 0, 0))
draw = ImageDraw.Draw(overlay)

for wx in range(min_x, max_x, 32):
    for wy in range(min_y, max_y, 16):
        cell_x = wx // 32
        cell_y = wy // 16
        rx = cell_x // 16
        cx = cell_x % 16
        ry = cell_y // 32
        cy = cell_y % 32
        
        if rx != 151: continue
        val = ob113[cx * 32 + cy] if ry == 113 else ob114[cx * 32 + cy] if ry == 114 else 0
        solid = (val >> 4) != 0
        
        px = wx - min_x
        py = wy - min_y
        color = (255, 0, 0, 110) if solid else (0, 255, 0, 50)
        draw.rectangle([px, py, px+31, py+15], fill=color, outline=(255, 255, 255, 60))
        draw.text((px+2, py+1), f'{cx},{cy}', fill=(255, 255, 255, 230))

res = Image.alpha_composite(canvas, overlay)
res.save('tools/bridge_exit_grid.png')
print('Saved tools/bridge_exit_grid.png successfully!')
