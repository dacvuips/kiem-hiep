import sys, os, struct
sys.path.insert(0, 'tools')
from vltk_pak import PakFile, TYPE_NONE, TYPE_UCL, TYPE_UPL_NEW, TYPE_FRAME, ucl_nrv2b_decompress

def scan_pak_for_spr(pak_path, target_w_range=(60, 100), target_h_range=(30, 60)):
    print(f"Scanning {os.path.basename(pak_path)}...")
    pak = PakFile(pak_path)
    matches = []
    
    for uid, (offset, size, flag) in pak.index.items():
        comp_method = (flag >> 24) & 0xFF
        comp_size = flag & 0x00FFFFFF
        if comp_size == 0:
            comp_size = size
            
        # We only care about SPR files, which start with b'SPR\0'
        # Let's read first few bytes or decompress
        try:
            pak.f.seek(offset)
            if comp_method == TYPE_NONE:
                raw_head = pak.f.read(32)
            elif comp_method in (TYPE_UCL, TYPE_UPL_NEW):
                # Only read if size looks like a small/medium SPR (e.g. < 500KB)
                if size > 1000000:
                    continue
                comp_data = pak.f.read(comp_size)
                # decompress
                raw = ucl_nrv2b_decompress(comp_data, size)
                raw_head = raw[:32]
            elif comp_method == TYPE_FRAME:
                # Frame-compressed SPR: header is uncompressed at offset!
                raw_head = pak.f.read(32)
            else:
                continue
                
            if raw_head[:4] == b"SPR\0":
                w, h, cx, cy, frames, colors, dirs, interval = struct.unpack_from("<8H", raw_head, 4)
                if target_w_range[0] <= w <= target_w_range[1] and target_h_range[0] <= h <= target_h_range[1]:
                    matches.append((uid, w, h, frames, dirs, interval, size, flag))
        except Exception:
            pass
            
    return matches

candidates_paks = [
    'skills.pak',
    'jxthaipham.pak',
    'updatejx16.pak',
    'updatejx15.pak',
    'updatejx14.pak',
    'slistcache.pak',
]

pak_dir = r'E:\game\VL\jxTP15phai_WSL\jxTP15phai_WSL\Client_jxTP_15phai\Client\data'
for p in candidates_paks:
    full = os.path.join(pak_dir, p)
    if os.path.exists(full):
        res = scan_pak_for_spr(full)
        print(f"--> Found {len(res)} matching SPRs in {p}:")
        for m in res:
            print(f"    uid=0x{m[0]:08x}: w={m[1]}, h={m[2]}, frames={m[3]}, dirs={m[4]}, interval={m[5]}, size={m[6]}")
