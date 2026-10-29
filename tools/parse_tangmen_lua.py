import os
import re
import sys
import subprocess
from pathlib import Path

sys.stdout.reconfigure(encoding="utf-8")

git_usr_bin = r"C:\Program Files\Git\usr\bin"
os.environ["PATH"] = git_usr_bin + os.pathsep + os.environ.get("PATH", "")

p_lua = r"D:/game/source_vo-lam-truyen-ky/anh-viet/Server + client full-001/server/script/skill/tangmen.lua"
res = subprocess.run(["iconv", "-f", "TCVN5712-1", "-t", "UTF-8", "-c", p_lua], capture_output=True)
if res.returncode != 0:
    # fallback to direct read
    with open(p_lua, "rb") as f:
        lua_text = f.read().decode("gbk", errors="replace")
else:
    lua_text = res.stdout.decode("utf-8", "replace")

# Print all skill table names and comments in tangmen.lua
blocks = re.findall(r'(\w+)\s*=\s*\{\s*--([^\n]*)\n(.*?)\n\t\},', lua_text, re.DOTALL)
print(f"Tổng số bảng skill trong tangmen.lua: {len(blocks)}")
for var, comment, body in blocks:
    # check if has skill_cost_v or addskilldamage
    costs = re.findall(r'skill_cost_v\s*=\s*\{([^\}]+)\}', body)
    dmg_lines = re.findall(r'(\w+)\s*=\s*\{\s*\[1\]\s*=\s*\{\{1,([\d\-]+)\},\{(\d+),([\d\-]+)\}\},\s*\[3\]\s*=\s*\{\{1,([\d\-]+)\},\{(\d+),([\d\-]+)\}', body)
    add_damages = re.findall(r'addskilldamage(\d+)\s*=\s*\{\s*\[1\]\s*=\s*\{\{1,(\d+)\},\{2,\d+\}\},\s*\[3\]\s*=\s*\{\{1,(\d+)\},\{20,(\d+)', body)
    
    print(f"\n=== {var} : {comment.strip()} ===")
    if costs:
        print(f"  Mana Cost: {costs[0].strip()}")
    if add_damages:
        for num, tgt, v1, v20 in add_damages:
            print(f"  Hỗ trợ Skill ID {tgt}: {v1}% -> {v20}%")
    # print some other stats
    for line in body.splitlines():
        line = line.strip()
        if any(k in line for k in ["physicsenhance_p", "toxicdamage_v", "lightingdamage_v", "colddamage_v", "firedamage_v", "seriesdamage_p", "deadlystrike_p"]):
            print(f"  {line}")
