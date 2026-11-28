import os, struct

p = r'D:\game\source_vo-lam-truyen-ky\anh-viet\MiTom_Pak_SPR_v1.1.7\Unpacked_Resources'

results = []
for root, dirs, files in os.walk(p):
    # Skip character models/animations
    dirs[:] = [d for d in dirs if d.lower() not in ['man', 'woman', 'beast', 'horse', 'weapon', 'head', 'body']]
    if 'npcres' in root.lower() and ('man' in root.lower() or 'woman' in root.lower() or 'beast' in root.lower()):
        continue
    for f in files:
        if f.endswith('.spr'):
            full = os.path.join(root, f)
            try:
                with open(full, 'rb') as fp:
                    hdr = fp.read(32)
                if hdr[:4] == b"SPR\0":
                    w, h, cx, cy, frames, colors, dirs_cnt, interval = struct.unpack_from("<8H", hdr, 4)
                    rel = os.path.relpath(full, p)
                    results.append((rel, w, h, cx, cy, frames, dirs_cnt, interval))
            except Exception:
                pass

print(f"Scanned {len(results)} valid non-character SPR files.")
filtered = [r for r in results if 60 <= r[1] <= 120 and 25 <= r[2] <= 60 and r[6] == 1]
print(f"Filtered {len(filtered)} SPR files matching candidate dimensions:")
for r in filtered:
    print(f"  {r[0]}: w={r[1]}, h={r[2]}, center=({r[3]},{r[4]}), frames={r[5]}, dirs={r[6]}, interval={r[7]}")
