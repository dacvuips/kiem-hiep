import sys
from pathlib import Path

sys.stdout.reconfigure(encoding="utf-8")
sys.path.insert(0, "tools")
import mark_player_skills as mps

# Search in skills2.txt
p = Path(r"D:/game/source_vo-lam-truyen-ky/Client_VLTK/Client_VLTK/settings/skills2.txt")
txt = mps.iconv(p)
for line in txt.splitlines():
    c = line.split("\t")
    if len(c) > 2:
        name = c[0]
        # Check all words
        if any(w in name.lower() for w in ["mai", "danh", "ẩn", "tính", "tích"]):
            print(f"ID {c[2]:4s} | {name}")
