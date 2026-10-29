import os
import re
import sys
from pathlib import Path

sys.stdout.reconfigure(encoding="utf-8")

p_vng = Path(r"D:/game/source_vo-lam-truyen-ky/anh-viet/Server + client full-001/server/script/skill/tianwang.lua")
p_15 = Path(r"E:/jx15_src/script/skill/tianwang.lua")

print("VNG exists:", p_vng.exists())
print("15 phai exists:", p_15.exists())

def check_file(p, enc):
    text = p.read_bytes().decode(enc, "replace")
    for skill_name in ["pofeng_zhan", "yangguan_sandie", "xingyun_jue", "tianwang_zhanyi", "jinzhong_zhao", "daoxutian"]:
        m = re.search(rf"({skill_name}\s*=\s*\{{.*?\n\t\}},)", text, re.DOTALL)
        if m:
            print(f"=== {skill_name} in {p.name} ===")
            for line in m.group(1).splitlines():
                if any(k in line for k in ["addskilldamage", "allres", "lifemax", "deadlystrike", "attackspeed", "physicsres"]):
                    print(" ", line.strip())

if p_vng.exists():
    print("\n--- CHECKING VNG SOURCE ---")
    check_file(p_vng, "cp1258")

if p_15.exists():
    print("\n--- CHECKING JX15 SOURCE ---")
    check_file(p_15, "gbk")
