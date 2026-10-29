import sys
from pathlib import Path

sys.stdout.reconfigure(encoding="utf-8")
sys.path.insert(0, "tools")
import mark_player_skills as mps

p = Path(r"D:/game/source_vo-lam-truyen-ky/Client_VLTK/Client_VLTK/settings/missles2.txt")
txt = mps.iconv(p)
lines = txt.splitlines()
header = lines[0].split("\t")

for line in lines[1:]:
    c = line.split("\t")
    if len(c) > 0 and c[0].isdigit():
        mid = int(c[0])
        if 535 <= mid <= 550:
            d = {header[i]: c[i] if i < len(c) else "" for i in range(len(header))}
            print(f"ID {d.get('MissleId'):4s} | {d.get('MissleName'):25s} | Move: {d.get('MoveKind'):2s} | Spd: {d.get('Speed'):2s} | DmgR: {d.get('DmgRange'):2s}")
            print(f"    Anim1 (wait): {d.get('AnimFile1')}")
            print(f"    Anim2 (fly) : {d.get('AnimFile2')}")
            print(f"    Anim3 (hit) : {d.get('AnimFile3')}")
            print(f"    Anim4 (van) : {d.get('AnimFile4')}")
