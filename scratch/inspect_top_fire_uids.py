from PIL import Image
import numpy as np

top_uids = [
    '0xa2bd4697',
    '0xce71520c',
    '0xd35df504',
    '0x07223e91',
    '0x7aaead51',
    '0xabe3119c',
    '0xd99633d1',
]

for uid in top_uids:
    png_path = f"scratch/jx_matched_pngs/{uid}.png"
    im = Image.open(png_path)
    meta_json = png_path.replace('.png', '.json')
    import json
    with open(meta_json, 'r') as fp:
        meta = json.load(fp)
    fw, fh = meta['frame_width'], meta['frame_height']
    f0 = im.crop((0, 0, fw, fh))
    f0.save(f"scratch/jx_matched_pngs/preview_{uid}.png")
    
    print(f"=== {uid} (fw={fw}, fh={fh}, frames={meta['frames']}, center={meta['center']}) ===")
    # Print small ascii
    small = f0.resize((35, int(35 * fh / fw)))
    for y in range(small.height):
        line = ''
        for x in range(small.width):
            r, g, b, a = small.getpixel((x, y))
            if a > 40:
                line += '#' if r > 220 and g > 150 else '*'
            else:
                line += ' '
        print(line)
