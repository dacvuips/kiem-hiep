import os
import re
import sys
import subprocess
from pathlib import Path

os.environ["PATH"] = r"C:\Program Files\Git\usr\bin;" + os.environ.get("PATH", "")
sys.stdout.reconfigure(encoding="utf-8")

MISSLES_TXT = Path(r"D:/game/source_vo-lam-truyen-ky/anh-viet/Server + client full-001/server/settings/Missles.txt")

def iconv(path: Path) -> str:
    return subprocess.run(["iconv", "-f", "TCVN5712-1", "-t", "UTF-8", "-c", str(path)],
                          capture_output=True, check=True).stdout.decode("utf-8", "replace")

lines = iconv(MISSLES_TXT).split("\n")
header = [h.strip() for h in lines[0].split("\t")]

for line in lines[1:]:
    p = [x.strip() for x in line.split("\t")]
    if len(p) <= 0 or not p[0].isdigit():
        continue
    mid = int(p[0])
    if mid in [6, 7, 8, 9, 10, 12, 111, 146, 147, 148, 188, 326, 354]:
        print(f"\n=== MISSLE {mid}: {p[1]} ===")
        for i, val in enumerate(p):
            if val and val != "0" and val != "-1":
                col_name = header[i] if i < len(header) else f"col_{i}"
                print(f"  {col_name}: {val}")
