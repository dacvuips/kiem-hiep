import sys, os
sys.path.insert(0, 'tools')
sys.path.insert(0, 'scratch')
from vltk_pak import PakFile
from test_fast_ucl import ucl_nrv2b_fast
import spr_to_png
from PIL import Image
import numpy as np

pak = PakFile(r'E:\game\VL\jxTP15phai_WSL\jxTP15phai_WSL\Client_jxTP_15phai\Client\data\jxthaipham.pak')

uid = 0x125521b0
off, sz, fl = pak.index[uid]
comp_sz = fl & 0x00FFFFFF
pak.f.seek(off)
comp = pak.f.read(comp_sz)
raw = ucl_nrv2b_fast(comp, sz)

spr_path = f'scratch/found_{uid:08x}.spr'
png_path = f'scratch/found_{uid:08x}.png'
with open(spr_path, 'wb') as f:
    f.write(raw)
meta = spr_to_png.convert(spr_path, png_path)
print(f"Extracted {uid:08x}: {meta}")

im = Image.open(png_path)
print("Image size:", im.size)
arr = np.array(im)
alpha = arr[:, :, 3] > 0
rgb = arr[alpha][:, :3]
print("Mean RGB:", rgb.mean(axis=0), "Min RGB:", rgb.min(axis=0), "Max RGB:", rgb.max(axis=0))
