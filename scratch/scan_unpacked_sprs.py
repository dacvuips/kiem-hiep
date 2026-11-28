import os, struct

p = r'D:\game\source_vo-lam-truyen-ky\anh-viet\MiTom_Pak_SPR_v1.1.7\Unpacked_Resources'

results = []
for root, dirs, files in os.walk(p):
    for f in files:
        if f.endswith('.spr'):
            full = os.path.join(root, f)
            try:
                with open(full, 'rb') as fp:
                    hdr = fp.read(32)
                if hdr[:4] == b"SPR\0":
                    w, h, cx, cy, frames, colors, dirs, interval = struct.unpack_from("<8H", hdr, 4)
                    rel = os.path.relpath(full, p)
                    results.append((rel, w, h, cx, cy, frames, dirs, interval))
            except Exception:
                pass

print(f"Scanned {len(results)} valid SPR files.")
# Filter files where width is 60..120, height is 25..60, dirs == 1
filtered = [r for r in results if 60 <= r[1] <= 120 and 25 <= r[2] <= 60 and r[5] == 1]
print(f"Filtered {len(filtered)} SPR files matching candidate dimensions:")
for r in filtered:
    print(f"  {r[0]}: w={r[1]}, h={r[2]}, center=({r[3]},{r[4]}), frames={r[5]}, dirs={r[6]}, interval={r[7]}")
