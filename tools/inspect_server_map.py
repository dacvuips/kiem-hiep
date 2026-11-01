import os
import struct
import sys

sys.stdout.reconfigure(encoding="utf-8")

MAP_DIR = r"D:\game\source_vo-lam-truyen-ky\anh-viet\Server + client full-001\server\maps\hoa_son_kiem"

# Region 27 in v_028 is (rx=27, ry=28) -> in game shifted (+124, +90) = (151, 118)
# Region 27 in v_027 is (rx=27, ry=27) -> in game (151, 117)
# Region 27 in v_026 is (rx=27, ry=26) -> in game (151, 116)

def read_region(rx, ry):
    path = os.path.join(MAP_DIR, f"v_{ry:03d}", f"{rx:03d}_Region_C.dat")
    if not os.path.exists(path):
        print(f"File not found: {path}")
        return None
    with open(path, "rb") as f:
        data = f.read()
    n_secs = struct.unpack_from("<I", data, 0)[0]
    secs = [struct.unpack_from("<II", data, 4 + 8 * i) for i in range(n_secs)]
    base = 4 + 8 * n_secs
    blobs = [data[base + o:base + o + l] for o, l in secs]
    
    # Sec 0 is obstacle
    ob_blob = blobs[0]
    ob = list(struct.unpack(f"<{len(ob_blob)//4}I", ob_blob[:2048]))
    return ob

for ry in [28, 27, 26, 25, 24, 23]:
    ob = read_region(27, ry)
    if ob:
        blocked = sum(1 for v in ob if (v >> 4) != 0)
        print(f"Server map rx=27, ry={ry} (game 151, {ry+90}): blocked={blocked}/512")
        # Print grid 16 cols x 32 rows
        print("   " + "".join(f"{x%10}" for x in range(16)))
        for cy in range(0, 32, 2): # print every 2nd row to keep compact
            row = "".join("#" if (ob[cx * 32 + cy] >> 4) != 0 else "." for cx in range(16))
            print(f"{cy:02d} {row}")
