import os
import gzip
import json
import struct
import sys
from PIL import Image

sys.stdout.reconfigure(encoding="utf-8")

DEST_MAP = r"d:\game\lam-game\kiem-hiep\world\maps\map_2"

with gzip.open(os.path.join(DEST_MAP, "chunks", "4_3.json.gz"), "rt", encoding="utf-8") as f:
    regs = json.load(f)["r"]

def get_cell(rx, ry, cx, cy):
    rk = f"{rx},{ry}"
    r = regs.get(rk)
    if not r:
        return 0xff
    runs = r.get("ob", [])
    arr = []
    for i in range(0, len(runs), 2):
        arr.extend([runs[i]] * runs[i+1])
    if len(arr) < 512:
        arr.extend([0] * (512 - len(arr)))
    return arr[cx * 32 + cy]

print("=== KIỂM TRA TỪNG ĐOẠN ĐƯỜNG TRÊN BẢN ĐỒ ===")

# Tuyến 2: Đầu cầu phía Đông (152,114 -> 153,114)
print("\n--- 1. Tuyến qua cầu và đầu cầu phía Đông ---")
for cx in range(0, 16):
    for cy in range(6, 14):
        val = get_cell(153, 114, cx, cy)
        if (val >> 4) != 0:
            print(f"  [153,114] cx={cx}, cy={cy}: BLOCKED (val=0x{val:02x})")

# Tuyến 4: Từ đầu cầu 153,114 xuống thác nước 154,114
print("\n--- 2. Tuyến đầu cầu xuống thác nước (153,114 & 154,114) ---")
for cx in range(0, 8):
    for cy in range(16, 26):
        val = get_cell(153, 114, cx, cy)
        if (val >> 4) != 0:
            print(f"  [153,114] cx={cx}, cy={cy}: BLOCKED (val=0x{val:02x})")

for cx in range(0, 10):
    for cy in range(6, 16):
        val = get_cell(154, 114, cx, cy)
        if (val >> 4) != 0:
            print(f"  [154,114] cx={cx}, cy={cy}: BLOCKED (val=0x{val:02x})")

# Tuyến 3: Từ đầu cầu 153,114 lên mỏm đá Đông Bắc (154,113 & 155,113)
print("\n--- 3. Tuyến mỏm đá Đông Bắc (154,113 & 155,113) ---")
for cx in range(6, 16):
    for cy in range(25, 30):
        val = get_cell(154, 113, cx, cy)
        if (val >> 4) != 0:
            print(f"  [154,113] cx={cx}, cy={cy}: BLOCKED (val=0x{val:02x})")
for cx in range(0, 8):
    for cy in range(25, 30):
        val = get_cell(155, 113, cx, cy)
        if (val >> 4) != 0:
            print(f"  [155,113] cx={cx}, cy={cy}: BLOCKED (val=0x{val:02x})")

# Tuyến 5: Tuyến sườn núi Đông Nam (155,116 & 155,117)
print("\n--- 4. Tuyến sườn núi Đông Nam (155,116 & 155,117) ---")
for cx in range(0, 6):
    for cy in range(10, 25):
        val = get_cell(155, 116, cx, cy)
        if (val >> 4) != 0:
            print(f"  [155,116] cx={cx}, cy={cy}: BLOCKED (val=0x{val:02x})")
for cx in range(0, 6):
    for cy in range(0, 20):
        val = get_cell(155, 117, cx, cy)
        if (val >> 4) != 0:
            print(f"  [155,117] cx={cx}, cy={cy}: BLOCKED (val=0x{val:02x})")

# Tuyến 6: Tuyến đường rừng phía Tây (146,116 & 145,115)
print("\n--- 5. Tuyến đường rừng phía Tây (146,116 & 145,115) ---")
for cx in range(4, 12):
    for cy in range(0, 10):
        val = get_cell(146, 116, cx, cy)
        if (val >> 4) != 0:
            print(f"  [146,116] cx={cx}, cy={cy}: BLOCKED (val=0x{val:02x})")
for cx in range(8, 16):
    for cy in range(4, 15):
        val = get_cell(145, 115, cx, cy)
        if (val >> 4) != 0:
            print(f"  [145,115] cx={cx}, cy={cy}: BLOCKED (val=0x{val:02x})")

# Tuyến 8: Tuyến Tây Bắc sang đầu cầu (150,113)
print("\n--- 6. Tuyến Tây Bắc sang cầu (150,113) ---")
for cx in range(4, 10):
    for cy in range(0, 12):
        val = get_cell(150, 113, cx, cy)
        if (val >> 4) != 0:
            print(f"  [150,113] cx={cx}, cy={cy}: BLOCKED (val=0x{val:02x})")
