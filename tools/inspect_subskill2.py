import sys
from pathlib import Path
sys.stdout.reconfigure(encoding="utf-8")
lines = Path("systems/sect/data/vo_dang.tres").read_text(encoding="utf-8").splitlines()
for i, l in enumerate(lines):
    if 'id = "vo_dang_thai_cuc_kiem_y"' in l or 'id = "vo_dang_huyen_nhat_vo_tuong"' in l:
        print(f"--- line {i+1} ---")
        for j in range(max(0, i-2), min(len(lines), i+20)):
            print(f"{j+1}: {lines[j]}")
