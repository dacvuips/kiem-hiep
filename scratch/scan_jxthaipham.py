import sys, os, struct, time
sys.path.insert(0, 'tools')
sys.path.insert(0, 'scratch')
from vltk_pak import PakFile
from test_fast_ucl import ucl_nrv2b_fast
import json

pak = PakFile(r'E:\game\VL\jxTP15phai_WSL\jxTP15phai_WSL\Client_jxTP_15phai\Client\data\jxthaipham.pak')
cands = [(uid, off, sz, fl) for uid, (off, sz, fl) in pak.index.items() if 15000 <= sz <= 250000]

print(f"Scanning {len(cands)} candidate files in jxthaipham.pak...", flush=True)
t0 = time.time()
matches = []

for idx, (uid, off, sz, fl) in enumerate(cands):
    if (idx + 1) % 500 == 0:
        print(f"Progress: {idx+1}/{len(cands)} in {time.time()-t0:.1f}s (found {len(matches)})", flush=True)
    m = (fl >> 24) & 0xFF
    comp_sz = fl & 0x00FFFFFF
    pak.f.seek(off)
    try:
        if m in (0, 0x10):
            raw = pak.f.read(32)
        elif m in (1, 0x20):
            comp = pak.f.read(comp_sz)
            raw = ucl_nrv2b_fast(comp, sz)[:32]
        else:
            continue
        if raw[:4] == b"SPR\0":
            w, h, cx, cy, frames, colors, dirs, interval = struct.unpack_from("<8H", raw, 4)
            # Filter for fire candidates: w in 55..120, h in 25..65, dirs == 1
            if 50 <= w <= 120 and 25 <= h <= 65 and dirs == 1 and 4 <= frames <= 40:
                matches.append({
                    "uid": f"0x{uid:08x}",
                    "w": w, "h": h, "cx": cx, "cy": cy,
                    "frames": frames, "dirs": dirs, "interval": interval,
                    "sz": sz
                })
                print(f"  FOUND: 0x{uid:08x} w={w} h={h} frames={frames} cx={cx} cy={cy}", flush=True)
    except Exception:
        pass

print(f"DONE in {time.time()-t0:.1f}s! Total matches: {len(matches)}", flush=True)
with open('scratch/jxthaipham_matches.json', 'w') as f:
    json.dump(matches, f, indent=2)
