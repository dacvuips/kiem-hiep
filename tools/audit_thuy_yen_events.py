import os
import re
import sys
import subprocess
from pathlib import Path

os.environ["PATH"] = r"C:\Program Files\Git\usr\bin;" + os.environ.get("PATH", "")
sys.stdout.reconfigure(encoding="utf-8")

SKILLS_TXT = Path(r"D:/game/source_vo-lam-truyen-ky/anh-viet/Server + client full-001/server/settings/Skills.txt")

def iconv(path: Path) -> str:
    return subprocess.run(["iconv", "-f", "TCVN5712-1", "-t", "UTF-8", "-c", str(path)],
                          capture_output=True, check=True).stdout.decode("utf-8", "replace")

lines = iconv(SKILLS_TXT).split("\n")
header = [h.strip() for h in lines[0].split("\t")]

cols_to_print = ["SkillId", "SkillName", "SkillStyle", "ChildSkillId", "ChildSkillNum",
                 "StartEvent", "StartSkillId", "FlyEvent", "FlySkillId", "CollideEvent",
                 "CollidSkillId", "VanishedEvent", "VanishedSkillId", "Param1", "Param2"]

indices = {c: header.index(c) for c in cols_to_print if c in header}

thuy_yen_all = [86, 95, 96, 97, 99, 100, 102, 105, 108, 109, 111, 113, 114, 269, 336, 337, 338, 382, 713, 1063, 1064, 1225, 1235]

print("=== CÁC EVENT & HIỆU ỨNG TRONG SKILLS.TXT GỐC ===")
for line in lines[1:]:
    p = line.split("\t")
    if len(p) <= indices["SkillId"] or not p[indices["SkillId"]].strip().isdigit():
        continue
    sid = int(p[indices["SkillId"]].strip())
    if sid in thuy_yen_all:
        row = {c: p[indices[c]].strip() if len(p) > indices[c] else "" for c in indices}
        print(f"ID {sid:4d} | Name: {row.get('SkillName',''):22s} | Style: {row.get('SkillStyle'):2s} | Child: {row.get('ChildSkillId'):4s} x {row.get('ChildSkillNum'):2s} | P1: {row.get('Param1'):3s} | P2: {row.get('Param2'):3s}")
        print(f"       Start: Evt={row.get('StartEvent')} Id={row.get('StartSkillId')} | Fly: Evt={row.get('FlyEvent')} Id={row.get('FlySkillId')} | Collide: Evt={row.get('CollideEvent')} Id={row.get('CollidSkillId')} | Vanish: Evt={row.get('VanishedEvent')} Id={row.get('VanishedSkillId')}")
