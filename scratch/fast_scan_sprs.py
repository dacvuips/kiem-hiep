import sys, os, struct
sys.path.insert(0, 'tools')
from vltk_pak import PakFile

candidates_paks = [
    'skills.pak',
    'jxthaipham.pak',
    'updatejx16.pak',
    'updatejx15.pak',
    'updatejx14.pak',
    'updatejx13.pak',
    'updatejx12.pak',
    'updatejx11.pak',
    'updatejx10.pak',
    'updatejx09.pak',
    'updatejx08.pak',
    'updatejx07_jxf06.pak',
    'updatejx06.pak',
    'updatejx05.pak',
    'updatejx04.pak',
    'updatejx03.pak',
    'updatejx02.pak',
    'updatejx01.pak',
    'update.pak',
    'slistcache.pak',
    'spr.pak',
]

pak_dir = r'E:\game\VL\jxTP15phai_WSL\jxTP15phai_WSL\Client_jxTP_15phai\Client\data'

results = []
for p in candidates_paks:
    full = os.path.join(pak_dir, p)
    if not os.path.exists(full):
        continue
    try:
        pak = PakFile(full)
    except Exception:
        continue
        
    for uid, (offset, size, flag) in pak.index.items():
        comp_method = (flag >> 24) & 0xFF
        # Only check frame-compressed SPR or uncompressed
        if comp_method in (0x10, 0x00):
            try:
                pak.f.seek(offset)
                hdr = pak.f.read(32)
                if hdr[:4] == b"SPR\0":
                    w, h, cx, cy, frames, colors, dirs, interval = struct.unpack_from("<8H", hdr, 4)
                    if 60 <= w <= 110 and 25 <= h <= 55 and dirs == 1 and 4 <= frames <= 30:
                        results.append((p, uid, w, h, frames, dirs, interval, size, flag, offset))
            except Exception:
                pass

print(f"Total matching SPRs across all paks: {len(results)}")
for r in results:
    print(f"Pak: {r[0]}, uid: 0x{r[1]:08x}, w={r[2]}, h={r[3]}, frames={r[4]}, dirs={r[5]}, interval={r[6]}, offset={r[9]}")
