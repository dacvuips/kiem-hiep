import sys, os, struct, time
sys.path.insert(0, 'tools')
from vltk_pak import PakFile
from test_fast_ucl import ucl_nrv2b_fast

def scan_pak(pak_path):
    pak = PakFile(pak_path)
    print(f"Scanning {os.path.basename(pak_path)} ({len(pak.index)} files)...")
    t0 = time.time()
    matches = []
    
    for uid, (off, sz, fl) in pak.index.items():
        # Only check files of size < 1MB that could be an SPR
        if sz < 100 or sz > 1500000:
            continue
        m = (fl >> 24) & 0xFF
        comp_sz = fl & 0x00FFFFFF
        if comp_sz == 0:
            comp_sz = sz
            
        try:
            pak.f.seek(off)
            if m == 0x00:
                raw_head = pak.f.read(32)
            elif m in (0x01, 0x20):
                comp_data = pak.f.read(comp_sz)
                # Quick decompress just enough? We decompress full:
                raw = ucl_nrv2b_fast(comp_data, sz)
                raw_head = raw[:32]
            elif m == 0x10:
                raw_head = pak.f.read(32)
            else:
                continue
                
            if raw_head[:4] == b"SPR\0":
                w, h, cx, cy, frames, colors, dirs, interval = struct.unpack_from("<8H", raw_head, 4)
                # Target fire dimensions: width 55..110, height 25..65, dirs 1
                if 55 <= w <= 110 and 25 <= h <= 65 and dirs == 1 and 4 <= frames <= 40:
                    matches.append({
                        "pak": os.path.basename(pak_path),
                        "uid": f"0x{uid:08x}",
                        "w": w, "h": h, "cx": cx, "cy": cy,
                        "frames": frames, "dirs": dirs, "interval": interval,
                        "size": sz
                    })
        except Exception:
            pass
            
    print(f"Done in {time.time() - t0:.2f}s, found {len(matches)} matches.")
    return matches

pak_dir = r'E:\game\VL\jxTP15phai_WSL\jxTP15phai_WSL\Client_jxTP_15phai\Client\data'

all_matches = []
for p in ['skills.pak', 'jxthaipham.pak']:
    full = os.path.join(pak_dir, p)
    if os.path.exists(full):
        all_matches.extend(scan_pak(full))

print("=== ALL MATCHES ===")
for m in all_matches:
    print(m)

# Save list
import json
with open('scratch/pak_spr_matches.json', 'w') as f:
    json.dump(all_matches, f, indent=2)
