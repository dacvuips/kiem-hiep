import sys, os, json
sys.path.insert(0, 'tools')
sys.path.insert(0, 'scratch')
from vltk_pak import PakFile
from test_fast_ucl import ucl_nrv2b_fast
import spr_to_png
from PIL import Image
import numpy as np

with open('scratch/jxthaipham_matches.json', 'r') as f:
    matches = json.load(f)

pak = PakFile(r'E:\game\VL\jxTP15phai_WSL\jxTP15phai_WSL\Client_jxTP_15phai\Client\data\jxthaipham.pak')

os.makedirs('scratch/jx_matched_pngs', exist_ok=True)

print(f"Extracting and converting {len(matches)} matches...")
candidates = []

for m in matches:
    uid_int = int(m['uid'], 16)
    off, sz, fl = pak.index[uid_int]
    comp_sz = fl & 0x00FFFFFF
    pak.f.seek(off)
    comp = pak.f.read(comp_sz)
    raw = ucl_nrv2b_fast(comp, sz)
    
    spr_path = f"scratch/jx_matched_pngs/{m['uid']}.spr"
    png_path = f"scratch/jx_matched_pngs/{m['uid']}.png"
    with open(spr_path, 'wb') as fp:
        fp.write(raw)
        
    try:
        meta = spr_to_png.convert(spr_path, png_path)
        im = Image.open(png_path)
        arr = np.array(im)
        alpha = arr[:, :, 3] > 0
        if alpha.sum() > 0:
            rgb = arr[alpha][:, :3]
            mean_rgb = rgb.mean(axis=0)
            # check if fire colored: R > 190, G > 120, B < 120
            is_fire = (mean_rgb[0] > 180 and mean_rgb[1] > 100 and mean_rgb[2] < 120)
            if is_fire or mean_rgb[0] > 200:
                candidates.append((m['uid'], meta, mean_rgb))
                print(f"FIRE CANDIDATE: {m['uid']} w={meta['frame_width']} h={meta['frame_height']} frames={meta['frames']} center={meta['center']} mean_rgb={mean_rgb.astype(int)}")
    except Exception as e:
        print(f"Error converting {m['uid']}: {e}")

print(f"Total fire candidates: {len(candidates)}")
