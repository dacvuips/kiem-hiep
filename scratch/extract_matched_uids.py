import sys, os
sys.path.insert(0, 'tools')
from vltk_pak import PakFile
from scratch.test_fast_ucl import ucl_nrv2b_fast
import spr_to_png

pak = PakFile(r'E:\game\VL\jxTP15phai_WSL\jxTP15phai_WSL\Client_jxTP_15phai\Client\data\skills.pak')

uids = [0x7a396e97, 0xb77a7cb9, 0x4f371c98]
for u in uids:
    off, sz, fl = pak.index[u]
    comp_sz = fl & 0x00FFFFFF
    pak.f.seek(off)
    comp = pak.f.read(comp_sz)
    raw = ucl_nrv2b_fast(comp, sz)
    
    spr_path = f'scratch/found_{u:08x}.spr'
    png_path = f'scratch/found_{u:08x}.png'
    with open(spr_path, 'wb') as f:
        f.write(raw)
    meta = spr_to_png.convert(spr_path, png_path)
    print(f"Extracted {u:08x}: {meta}")
