import os
import struct
import sys

sys.stdout.reconfigure(encoding="utf-8")

MAP_DIR = r"D:\game\source_vo-lam-truyen-ky\anh-viet\Server + client full-001\server\maps\hoa_son_kiem"

path = os.path.join(MAP_DIR, "v_023", "027_Region_C.dat")
with open(path, "rb") as f:
    data = f.read()
n_secs = struct.unpack_from("<I", data, 0)[0]
secs = [struct.unpack_from("<II", data, 4 + 8 * i) for i in range(n_secs)]
base = 4 + 8 * n_secs
blobs = [data[base + o:base + o + l] for o, l in secs]
ob = list(struct.unpack(f"<{len(blobs[0])//4}I", blobs[0][:2048]))

print("Obstacle breakdown in 27,23:")
distinct_vals = set(ob)
for v in sorted(distinct_vals):
    count = ob.count(v)
    shape = v >> 4
    kind = v & 15
    print(f"  val=0x{v:02X} (shape={shape}, kind={kind}): count={count}")
